import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createServer, type Server } from "node:http";
import { AddressInfo } from "node:net";
import { WebSocket } from "ws";
import { attachCallSocket } from "../src/ws/callSocket.js";
import { StubSttProvider } from "../src/stt/StubSttProvider.js";
import { StubEmotionAnalyzer } from "../src/analysis/StubEmotionAnalyzer.js";
import type { ServerMessage } from "../src/contract.js";
import type { AppConfig } from "../src/config.js";

let server: Server;
let port: number;

const testConfig = {
  analysisMinIntervalMs: 0,
} as AppConfig;

beforeAll(async () => {
  const providers = {
    stt: new StubSttProvider(),
    analyzer: new StubEmotionAnalyzer(),
  };
  server = createServer();
  attachCallSocket(server, providers, testConfig);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  port = (server.address() as AddressInfo).port;
});

afterAll(async () => {
  await new Promise<void>((resolve) => server.close(() => resolve()));
});

function collectCall(): Promise<ServerMessage[]> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/call`);
    const messages: ServerMessage[] = [];
    const timeout = setTimeout(() => reject(new Error("ws test timed out")), 5000);

    ws.on("open", () => {
      ws.send(
        JSON.stringify({
          type: "start",
          sampleRate: 16000,
          encoding: "linear16",
          mode: "live",
        }),
      );
      // Feed enough synthetic audio to flush the whole stub script.
      const frame = Buffer.alloc(48000);
      for (let i = 0; i < 12; i++) ws.send(frame);
      setTimeout(() => ws.send(JSON.stringify({ type: "stop" })), 50);
    });

    ws.on("message", (data) => messages.push(JSON.parse(data.toString())));
    ws.on("close", () => {
      clearTimeout(timeout);
      resolve(messages);
    });
    ws.on("error", reject);
  });
}

describe("/call websocket contract", () => {
  it("emits the expected ordered event stream for a full call", async () => {
    const messages = await collectCall();
    const types = messages.map((m) => m.type);

    // Lifecycle bookends.
    expect(messages[0]).toEqual({ type: "status", state: "connected" });
    expect(types).toContain("transcript");
    expect(types).toContain("emotion");
    expect(types).toContain("report");

    // analyzing precedes the report, stopped is last status.
    expect(types.indexOf("report")).toBeGreaterThan(
      types.indexOf("transcript"),
    );
    const statuses = messages
      .filter((m): m is Extract<ServerMessage, { type: "status" }> => m.type === "status")
      .map((m) => m.state);
    expect(statuses).toContain("listening");
    expect(statuses).toContain("analyzing");
    expect(statuses[statuses.length - 1]).toBe("stopped");

    // The report is well-formed.
    const report = messages.find(
      (m): m is Extract<ServerMessage, { type: "report" }> => m.type === "report",
    );
    expect(report?.report.sections.length).toBeGreaterThan(0);
  });
});
