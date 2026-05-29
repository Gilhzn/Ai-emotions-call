import "dotenv/config";
import { z } from "zod";

/**
 * Environment configuration, validated once at startup. Secrets live ONLY here
 * (sourced from the backend `.env`); they are never sent to the Flutter app.
 */
const EnvSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8080),
  DEEPGRAM_API_KEY: z.string().default(""),
  ANTHROPIC_API_KEY: z.string().default(""),
  CLAUDE_REALTIME_MODEL: z.string().default("claude-sonnet-4-6"),
  CLAUDE_REPORT_MODEL: z.string().default("claude-opus-4-8"),
  ANALYSIS_MIN_INTERVAL_MS: z.coerce.number().int().nonnegative().default(2500),
  USE_STUB_PROVIDERS: z
    .string()
    .default("false")
    .transform((v) => v.toLowerCase() === "true"),
});

const parsed = EnvSchema.parse(process.env);

/**
 * When stubs are explicitly requested, OR when real keys are missing, fall back
 * to deterministic in-process providers so the server still boots and the file
 * path / tests work without network access.
 */
const missingRealKeys = !parsed.DEEPGRAM_API_KEY || !parsed.ANTHROPIC_API_KEY;
const useStubs = parsed.USE_STUB_PROVIDERS || missingRealKeys;

export const config = {
  port: parsed.PORT,
  deepgramApiKey: parsed.DEEPGRAM_API_KEY,
  anthropicApiKey: parsed.ANTHROPIC_API_KEY,
  realtimeModel: parsed.CLAUDE_REALTIME_MODEL,
  reportModel: parsed.CLAUDE_REPORT_MODEL,
  analysisMinIntervalMs: parsed.ANALYSIS_MIN_INTERVAL_MS,
  useStubs,
  stubReason: parsed.USE_STUB_PROVIDERS
    ? "USE_STUB_PROVIDERS=true"
    : missingRealKeys
      ? "missing DEEPGRAM_API_KEY/ANTHROPIC_API_KEY"
      : null,
} as const;

export type AppConfig = typeof config;
