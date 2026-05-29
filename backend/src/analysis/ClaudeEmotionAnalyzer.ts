import Anthropic from "@anthropic-ai/sdk";
import {
  EMOTION_KEYS,
  type EmotionScores,
  type InsightSeverity,
  type PostCallReport,
  type Speaker,
  type TimelinePoint,
} from "../contract.js";
import type { Utterance } from "../stt/SttProvider.js";
import {
  REALTIME_SYSTEM_PROMPT,
  REALTIME_TOOL,
  REPORT_SYSTEM_PROMPT,
  REPORT_TOOL,
  renderReportInput,
  renderWindow,
} from "./prompts.js";
import type {
  EmotionAnalyzer,
  SpeakerEmotion,
  WindowAnalysis,
} from "./EmotionAnalyzer.js";
import { emptyReport } from "./reportDefaults.js";

const clamp = (n: unknown): number =>
  Math.max(0, Math.min(100, Math.round(typeof n === "number" ? n : 0)));

function sanitizeScores(raw: any): EmotionScores {
  const out = {} as EmotionScores;
  for (const k of EMOTION_KEYS) out[k] = clamp(raw?.[k]);
  return out;
}

/** Emotion analysis + post-call report backed by Claude with forced tool use. */
export class ClaudeEmotionAnalyzer implements EmotionAnalyzer {
  private client: Anthropic;

  constructor(
    apiKey: string,
    private realtimeModel: string,
    private reportModel: string,
  ) {
    this.client = new Anthropic({ apiKey });
  }

  async analyzeWindow(
    window: Utterance[],
    elapsedSec: number,
  ): Promise<WindowAnalysis> {
    const response = await this.client.messages.create({
      model: this.realtimeModel,
      max_tokens: 1024,
      // Static system prompt + tool schema are cached across calls to cut cost.
      system: [
        {
          type: "text",
          text: REALTIME_SYSTEM_PROMPT,
          cache_control: { type: "ephemeral" },
        },
      ],
      tools: [{ ...REALTIME_TOOL, cache_control: { type: "ephemeral" } } as any],
      tool_choice: { type: "tool", name: REALTIME_TOOL.name },
      messages: [{ role: "user", content: renderWindow(window, elapsedSec) }],
    });

    const input = extractToolInput(response, REALTIME_TOOL.name);
    return sanitizeWindow(input);
  }

  async buildReport(
    utterances: Utterance[],
    timeline: TimelinePoint[],
  ): Promise<PostCallReport> {
    if (utterances.length === 0) return emptyReport();
    const response = await this.client.messages.create({
      model: this.reportModel,
      max_tokens: 2048,
      system: [
        {
          type: "text",
          text: REPORT_SYSTEM_PROMPT,
          cache_control: { type: "ephemeral" },
        },
      ],
      tools: [REPORT_TOOL],
      tool_choice: { type: "tool", name: REPORT_TOOL.name },
      messages: [
        { role: "user", content: renderReportInput(utterances, timeline) },
      ],
    });
    const input = extractToolInput(response, REPORT_TOOL.name);
    return sanitizeReport(input);
  }
}

function extractToolInput(response: Anthropic.Message, toolName: string): any {
  for (const block of response.content) {
    if (block.type === "tool_use" && block.name === toolName) {
      return block.input;
    }
  }
  return {};
}

function sanitizeWindow(input: any): WindowAnalysis {
  const emotions: SpeakerEmotion[] = Array.isArray(input?.emotions)
    ? input.emotions.map((e: any): SpeakerEmotion => ({
        speaker: (e?.speaker === "B" ? "B" : "A") as Speaker,
        scores: sanitizeScores(e?.scores),
        trust: clamp(e?.trust),
        dominance: clamp(e?.dominance),
        stress: clamp(e?.stress),
        intent: typeof e?.intent === "string" ? e.intent : "",
      }))
    : [];
  const insights = Array.isArray(input?.insights)
    ? input.insights
        .filter((i: any) => typeof i?.text === "string" && i.text.trim())
        .map((i: any) => ({
          severity: normalizeSeverity(i?.severity),
          text: i.text as string,
        }))
    : [];
  return { emotions, insights };
}

function normalizeSeverity(s: unknown): InsightSeverity {
  return s === "critical" || s === "warn" ? s : "info";
}

function sanitizeReport(input: any): PostCallReport {
  const base = emptyReport();
  return {
    summary: typeof input?.summary === "string" ? input.summary : base.summary,
    scores: {
      sellerScore: clamp(input?.scores?.sellerScore),
      customerEmotion: clamp(input?.scores?.customerEmotion),
      trustLevel: clamp(input?.scores?.trustLevel),
      conversionProbability: clamp(input?.scores?.conversionProbability),
    },
    sections: Array.isArray(input?.sections)
      ? input.sections.map((s: any) => ({
          name: String(s?.name ?? ""),
          summary: String(s?.summary ?? ""),
          energy:
            s?.energy === "low" || s?.energy === "high" ? s.energy : "medium",
        }))
      : [],
    events: Array.isArray(input?.events)
      ? input.events.map((e: any) => ({
          type: normalizeEventType(e?.type),
          t: typeof e?.t === "number" ? e.t : 0,
          note: String(e?.note ?? ""),
        }))
      : [],
    timeline: Array.isArray(input?.timeline)
      ? input.timeline.map((p: any) => ({
          t: typeof p?.t === "number" ? p.t : 0,
          trust: clamp(p?.trust),
          stress: clamp(p?.stress),
          dominance: clamp(p?.dominance),
          emotionDominant: EMOTION_KEYS.includes(p?.emotionDominant)
            ? p.emotionDominant
            : "neutral",
        }))
      : [],
  };
}

function normalizeEventType(t: unknown): PostCallReport["events"][number]["type"] {
  const allowed = [
    "interruption",
    "silence",
    "aggressive_reaction",
    "excitement_spike",
  ] as const;
  return (allowed as readonly string[]).includes(t as string)
    ? (t as any)
    : "interruption";
}
