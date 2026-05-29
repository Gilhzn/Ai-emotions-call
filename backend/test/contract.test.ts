import { describe, expect, it } from "vitest";
import { isClientMessage, parseClientMessage } from "../src/contract.js";

describe("client message contract", () => {
  it("accepts valid control messages", () => {
    expect(parseClientMessage('{"type":"start","sampleRate":16000,"encoding":"linear16","mode":"live"}'))
      .toMatchObject({ type: "start", mode: "live" });
    expect(parseClientMessage('{"type":"stop"}')).toEqual({ type: "stop" });
    expect(parseClientMessage('{"type":"swapSpeakers"}')).toEqual({ type: "swapSpeakers" });
  });

  it("rejects malformed or unknown messages", () => {
    expect(parseClientMessage("not json")).toBeNull();
    expect(parseClientMessage('{"type":"explode"}')).toBeNull();
    expect(parseClientMessage("[]")).toBeNull();
    expect(isClientMessage(null)).toBe(false);
    expect(isClientMessage({ type: 42 })).toBe(false);
  });
});
