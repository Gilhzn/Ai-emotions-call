import type Anthropic from "@anthropic-ai/sdk";
import { EMOTION_KEYS } from "../contract.js";

/**
 * Prompt + tool-schema definitions for the Claude analyzer. We force a single
 * tool call so Claude always returns well-typed JSON instead of prose. The
 * system prompt is static (cacheable) and frames the model as a sales
 * conversation-intelligence engine: Speaker A = sales rep, Speaker B = customer.
 */

export const REALTIME_SYSTEM_PROMPT = `You are EmotionCall AI, a real-time conversation-intelligence engine for sales calls.

You receive a rolling window of the most recent transcript. Speaker A is the SALES REP/seller. Speaker B is the CUSTOMER/prospect.

Analyze the emotional and tactical state of EACH speaker who has spoken in the window. Focus on the sales dimensions that matter: purchase intent, objections (especially price), hesitation, trust, who is leading vs defending, and momentum toward or away from a close.

Scoring rules:
- Every emotion score and the trust/dominance/stress dimensions are integers 0-100.
- "dominance" = how much this speaker is leading/controlling the conversation.
- "trust" = how much trust this speaker is currently showing toward the other side.
- "stress" = audible/textual tension or pressure for this speaker.
- "intent" = a 2-5 word label of what the speaker is trying to do right now (e.g. "raising price objection", "evaluating fit", "moving to close").

Insights are SHORT, actionable coaching notes addressed to the sales rep (Speaker A), e.g. "Customer losing interest", "Price objection — lead with ROI", "Other side is defensive, slow down". Emit 0-3 insights; only emit an insight when it is genuinely useful. Use severity "critical" for risks that could lose the deal, "warn" for caution, "info" otherwise.

Always call the report_state tool. Never reply with prose.`;

export const REALTIME_TOOL: Anthropic.Tool = {
  name: "report_state",
  description:
    "Report the current per-speaker emotional/tactical state and any coaching insights.",
  input_schema: {
    type: "object",
    properties: {
      emotions: {
        type: "array",
        description: "One entry per speaker who has spoken in the window.",
        items: {
          type: "object",
          properties: {
            speaker: { type: "string", enum: ["A", "B"] },
            scores: {
              type: "object",
              properties: Object.fromEntries(
                EMOTION_KEYS.map((k) => [
                  k,
                  { type: "integer", minimum: 0, maximum: 100 },
                ]),
              ),
              required: [...EMOTION_KEYS],
            },
            trust: { type: "integer", minimum: 0, maximum: 100 },
            dominance: { type: "integer", minimum: 0, maximum: 100 },
            stress: { type: "integer", minimum: 0, maximum: 100 },
            intent: { type: "string" },
          },
          required: ["speaker", "scores", "trust", "dominance", "stress", "intent"],
        },
      },
      insights: {
        type: "array",
        items: {
          type: "object",
          properties: {
            severity: { type: "string", enum: ["info", "warn", "critical"] },
            text: { type: "string" },
          },
          required: ["severity", "text"],
        },
      },
    },
    required: ["emotions", "insights"],
  },
};

export const REPORT_SYSTEM_PROMPT = `You are EmotionCall AI's post-call analyst for sales conversations. Speaker A is the SALES REP/seller, Speaker B is the CUSTOMER.

You receive the full timestamped transcript plus a sampled timeline of trust/stress/dominance readings. Produce a concise, honest post-call report:
- summary: 2-4 sentences on how the call went and the likely outcome.
- scores: sellerScore (rep performance), customerEmotion (net customer positivity), trustLevel (mutual trust), conversionProbability (likelihood the deal closes). All integers 0-100.
- sections: break the call into "opening", "middle", "close" (use the parts that exist). Each has a one-line summary and an energy of low/medium/high.
- events: notable moments — interruptions, silences, aggressive reactions, excitement spikes — each with an approximate timestamp (seconds) and a short note.
- timeline: 6-12 sampled points across the call with trust/stress/dominance (0-100) and the dominant emotion at that point.

Always call the build_report tool. Never reply with prose.`;

export const REPORT_TOOL: Anthropic.Tool = {
  name: "build_report",
  description: "Return the structured post-call report.",
  input_schema: {
    type: "object",
    properties: {
      summary: { type: "string" },
      scores: {
        type: "object",
        properties: {
          sellerScore: { type: "integer", minimum: 0, maximum: 100 },
          customerEmotion: { type: "integer", minimum: 0, maximum: 100 },
          trustLevel: { type: "integer", minimum: 0, maximum: 100 },
          conversionProbability: { type: "integer", minimum: 0, maximum: 100 },
        },
        required: [
          "sellerScore",
          "customerEmotion",
          "trustLevel",
          "conversionProbability",
        ],
      },
      sections: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            summary: { type: "string" },
            energy: { type: "string", enum: ["low", "medium", "high"] },
          },
          required: ["name", "summary", "energy"],
        },
      },
      events: {
        type: "array",
        items: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: [
                "interruption",
                "silence",
                "aggressive_reaction",
                "excitement_spike",
              ],
            },
            t: { type: "number" },
            note: { type: "string" },
          },
          required: ["type", "t", "note"],
        },
      },
      timeline: {
        type: "array",
        items: {
          type: "object",
          properties: {
            t: { type: "number" },
            trust: { type: "integer", minimum: 0, maximum: 100 },
            stress: { type: "integer", minimum: 0, maximum: 100 },
            dominance: { type: "integer", minimum: 0, maximum: 100 },
            emotionDominant: { type: "string", enum: [...EMOTION_KEYS] },
          },
          required: ["t", "trust", "stress", "dominance", "emotionDominant"],
        },
      },
    },
    required: ["summary", "scores", "sections", "events", "timeline"],
  },
};

/** Render a rolling window of utterances into the user-message text. */
export function renderWindow(
  window: { speaker: string; text: string }[],
  elapsedSec: number,
): string {
  const lines = window.map((u) => `${u.speaker}: ${u.text}`).join("\n");
  return `Elapsed: ${Math.round(elapsedSec)}s\n\nRecent transcript:\n${lines}`;
}

/** Render the full transcript + sampled timeline for the report prompt. */
export function renderReportInput(
  utterances: { speaker: string; text: string; tStart: number }[],
  timeline: { t: number; trust: number; stress: number; dominance: number }[],
): string {
  const transcript = utterances
    .map((u) => `[${Math.round(u.tStart)}s] ${u.speaker}: ${u.text}`)
    .join("\n");
  const tl = timeline
    .map(
      (p) =>
        `${Math.round(p.t)}s trust=${p.trust} stress=${p.stress} dominance=${p.dominance}`,
    )
    .join("\n");
  return `Full transcript:\n${transcript}\n\nSampled timeline:\n${tl || "(none)"}`;
}
