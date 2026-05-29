/**
 * EmotionCall AI — canonical WebSocket message contract.
 *
 * This file is the single source of truth for the realtime protocol between the
 * Flutter app and the backend proxy. The Dart models in `app/lib/core/models/`
 * are hand-mirrored from these types, and the language-neutral description lives
 * in `docs/websocket-contract.md`. Keep all three in sync.
 *
 * Transport: one WebSocket connection per call at `/call`.
 *   - Audio is sent as BINARY frames (PCM16 little-endian, mono, 16 kHz, ~100 ms).
 *   - Every control/data message is a JSON text frame matching the types below.
 */

export type Speaker = "A" | "B";

/** The discrete emotions we surface per speaker, each scored 0..100. */
export interface EmotionScores {
  positive: number;
  angry: number;
  stressed: number;
  neutral: number;
  disappointed: number;
  suspicious: number;
  aggressive: number;
}

export const EMOTION_KEYS: (keyof EmotionScores)[] = [
  "positive",
  "angry",
  "stressed",
  "neutral",
  "disappointed",
  "suspicious",
  "aggressive",
];

export type InsightSeverity = "info" | "warn" | "critical";

// ---------------------------------------------------------------------------
// Client -> Server
// ---------------------------------------------------------------------------

export interface StartMessage {
  type: "start";
  /** Audio sample rate of the binary frames. v1 expects 16000. */
  sampleRate: number;
  /** Encoding of the binary frames. v1 expects "linear16". */
  encoding: "linear16";
  /** "live" = mic streaming session, "file" = streamed file playback. */
  mode: "live" | "file";
}

export interface StopMessage {
  type: "stop";
}

/** Flip which Deepgram diarization channel maps to Speaker A vs B. */
export interface SwapSpeakersMessage {
  type: "swapSpeakers";
}

export type ClientMessage = StartMessage | StopMessage | SwapSpeakersMessage;

// ---------------------------------------------------------------------------
// Server -> Client
// ---------------------------------------------------------------------------

export type SessionState =
  | "connected"
  | "listening"
  | "analyzing"
  | "stopped";

export interface StatusMessage {
  type: "status";
  state: SessionState;
}

export interface TranscriptMessage {
  type: "transcript";
  speaker: Speaker;
  text: string;
  /** false = interim (may change), true = finalized utterance. */
  isFinal: boolean;
  /** Seconds from call start. */
  tStart: number;
  tEnd: number;
}

export interface EmotionMessage {
  type: "emotion";
  speaker: Speaker;
  /** Seconds from call start. */
  t: number;
  scores: EmotionScores;
  /** 0..100 derived dimensions. */
  trust: number;
  dominance: number;
  stress: number;
  /** Short free-text intent label, e.g. "evaluating price". */
  intent: string;
}

export interface InsightMessage {
  type: "insight";
  t: number;
  severity: InsightSeverity;
  text: string;
}

export interface ErrorMessage {
  type: "error";
  code: string;
  message: string;
}

export interface ReportMessage {
  type: "report";
  report: PostCallReport;
}

export type ServerMessage =
  | StatusMessage
  | TranscriptMessage
  | EmotionMessage
  | InsightMessage
  | ErrorMessage
  | ReportMessage;

// ---------------------------------------------------------------------------
// Post-call report
// ---------------------------------------------------------------------------

export interface ReportScores {
  /** How well the seller/rep (Speaker A) performed, 0..100. */
  sellerScore: number;
  /** Net customer (Speaker B) emotional positivity, 0..100. */
  customerEmotion: number;
  /** Mutual trust level, 0..100. */
  trustLevel: number;
  /** Likelihood the deal closes, 0..100. */
  conversionProbability: number;
}

export interface ReportSection {
  /** e.g. "opening", "middle", "close". */
  name: string;
  summary: string;
  /** Qualitative energy of this section. */
  energy: "low" | "medium" | "high";
}

export type CallEventType =
  | "interruption"
  | "silence"
  | "aggressive_reaction"
  | "excitement_spike";

export interface CallEvent {
  type: CallEventType;
  /** Seconds from call start. */
  t: number;
  note: string;
}

export interface TimelinePoint {
  /** Seconds from call start. */
  t: number;
  trust: number;
  stress: number;
  dominance: number;
  /** Dominant emotion at this point. */
  emotionDominant: keyof EmotionScores;
}

export interface PostCallReport {
  summary: string;
  scores: ReportScores;
  sections: ReportSection[];
  events: CallEvent[];
  timeline: TimelinePoint[];
}

// ---------------------------------------------------------------------------
// Runtime type guards (used by the WS layer + contract tests)
// ---------------------------------------------------------------------------

export function isClientMessage(value: unknown): value is ClientMessage {
  if (typeof value !== "object" || value === null) return false;
  const t = (value as { type?: unknown }).type;
  return t === "start" || t === "stop" || t === "swapSpeakers";
}

export function parseClientMessage(raw: string): ClientMessage | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  return isClientMessage(parsed) ? parsed : null;
}
