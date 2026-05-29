import type { Server } from "node:http";
import { WebSocketServer, WebSocket } from "ws";
import type { ServerMessage } from "../contract.js";
import { parseClientMessage } from "../contract.js";
import type { Providers } from "../providers.js";
import { CallSession } from "../pipeline/CallSession.js";
import type { AppConfig } from "../config.js";

/**
 * Attach the `/call` WebSocket endpoint. Binary frames are audio; text frames
 * are JSON control messages. Each connection gets its own {@link CallSession}.
 */
export function attachCallSocket(
  server: Server,
  providers: Providers,
  config: AppConfig,
): WebSocketServer {
  const wss = new WebSocketServer({ server, path: "/call" });

  wss.on("connection", (ws: WebSocket) => {
    const send = (msg: ServerMessage) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
    };

    const session = new CallSession({
      providers,
      analysisMinIntervalMs: config.analysisMinIntervalMs,
      emit: send,
    });

    send({ type: "status", state: "connected" });

    ws.on("message", (data: Buffer, isBinary: boolean) => {
      if (isBinary) {
        session.handleAudio(data);
        return;
      }
      const msg = parseClientMessage(data.toString());
      if (!msg) {
        send({ type: "error", code: "bad_message", message: "Unrecognized message" });
        return;
      }
      switch (msg.type) {
        case "start":
          void session.start(msg);
          break;
        case "swapSpeakers":
          session.swapSpeakers();
          break;
        case "stop":
          void session.stop().finally(() => {
            if (ws.readyState === WebSocket.OPEN) ws.close();
          });
          break;
      }
    });

    ws.on("close", () => session.abort());
    ws.on("error", () => session.abort());
  });

  return wss;
}
