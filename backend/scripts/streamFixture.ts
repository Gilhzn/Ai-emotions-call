/**
 * Dev helper: stream a local audio file (or synthetic silence) to a running
 * backend's /call WebSocket as ~100 ms PCM16 frames, printing every server
 * message. Useful to exercise the live path without a device.
 *
 *   npm run simulate -- [path/to/audio.raw] [ws://localhost:8080/call]
 *
 * With stub providers the file content is ignored (the stub emits a scripted
 * conversation), so you can run it with no arguments.
 */
import { readFileSync } from "node:fs";
import { WebSocket } from "ws";

const filePath = process.argv[2];
const url = process.argv[3] ?? "ws://localhost:8080/call";

// 16 kHz * 2 bytes * 0.1 s = 3200 bytes per 100 ms frame.
const FRAME_BYTES = 3200;
const audio = filePath
  ? readFileSync(filePath)
  : Buffer.alloc(FRAME_BYTES * 200); // ~20 s of silence to drive the stub

const ws = new WebSocket(url);

ws.on("open", async () => {
  ws.send(
    JSON.stringify({ type: "start", sampleRate: 16000, encoding: "linear16", mode: "file" }),
  );
  for (let off = 0; off < audio.length; off += FRAME_BYTES) {
    ws.send(audio.subarray(off, off + FRAME_BYTES));
    await new Promise((r) => setTimeout(r, 100));
  }
  ws.send(JSON.stringify({ type: "stop" }));
});

ws.on("message", (data) => console.log(data.toString()));
ws.on("close", () => process.exit(0));
ws.on("error", (err) => {
  console.error("WebSocket error:", err);
  process.exit(1);
});
