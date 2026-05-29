import type { AppConfig } from "./config.js";
import type { SttProvider } from "./stt/SttProvider.js";
import type { EmotionAnalyzer } from "./analysis/EmotionAnalyzer.js";
import { StubSttProvider } from "./stt/StubSttProvider.js";
import { StubEmotionAnalyzer } from "./analysis/StubEmotionAnalyzer.js";
import { DeepgramProvider } from "./stt/DeepgramProvider.js";
import { ClaudeEmotionAnalyzer } from "./analysis/ClaudeEmotionAnalyzer.js";

export interface Providers {
  stt: SttProvider;
  analyzer: EmotionAnalyzer;
}

/**
 * Build the STT + analysis providers. Falls back to deterministic stubs when
 * `config.useStubs` is set (no keys / CI / explicit opt-in).
 */
export function createProviders(config: AppConfig): Providers {
  if (config.useStubs) {
    return { stt: new StubSttProvider(), analyzer: new StubEmotionAnalyzer() };
  }
  return {
    stt: new DeepgramProvider(config.deepgramApiKey),
    analyzer: new ClaudeEmotionAnalyzer(
      config.anthropicApiKey,
      config.realtimeModel,
      config.reportModel,
    ),
  };
}
