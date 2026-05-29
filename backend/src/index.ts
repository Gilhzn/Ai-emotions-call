import { createServer } from "node:http";
import { config } from "./config.js";
import { createProviders } from "./providers.js";
import { createApp } from "./http/server.js";
import { attachCallSocket } from "./ws/callSocket.js";

const providers = createProviders(config);
const app = createApp(providers);
const server = createServer(app);
attachCallSocket(server, providers, config);

server.listen(config.port, () => {
  const mode = config.useStubs
    ? `STUB providers (${config.stubReason})`
    : "REAL providers (Deepgram + Claude)";
  // eslint-disable-next-line no-console
  console.log(
    `EmotionCall AI backend listening on :${config.port} — ${mode}\n` +
      `  WebSocket: ws://localhost:${config.port}/call\n` +
      `  File API:  POST http://localhost:${config.port}/analyze-file`,
  );
});
