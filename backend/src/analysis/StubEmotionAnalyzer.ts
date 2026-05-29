import {
  EMOTION_KEYS,
  type EmotionScores,
  type PostCallReport,
  type Speaker,
  type TimelinePoint,
} from "../contract.js";
import type { Utterance } from "../stt/SttProvider.js";
import type {
  AnalysisInsight,
  EmotionAnalyzer,
  SpeakerEmotion,
  WindowAnalysis,
} from "./EmotionAnalyzer.js";
import { emptyReport } from "./reportDefaults.js";

/**
 * Deterministic, network-free analyzer used when real keys are absent / in CI.
 * It applies simple keyword heuristics so the pipeline, timeline, and report are
 * all exercised with believable (but not real) numbers.
 */

const POSITIVE = ["great", "yeah", "sure", "works", "willing", "good", "thanks", "okay"];
const HESITATION = ["not sure", "hesitate", "maybe", "think about", "right now", "busy"];
const PRICE = ["price", "expensive", "high", "cost", "budget", "afford"];
const ANGER = ["no", "never", "ridiculous", "waste", "stop"];

function countHits(text: string, words: string[]): number {
  const lower = text.toLowerCase();
  return words.reduce((n, w) => (lower.includes(w) ? n + 1 : n), 0);
}

function zeroScores(): EmotionScores {
  return EMOTION_KEYS.reduce((acc, k) => {
    acc[k] = 0;
    return acc;
  }, {} as EmotionScores);
}

const clamp = (n: number) => Math.max(0, Math.min(100, Math.round(n)));

function scoreUtterance(text: string, speaker: Speaker): SpeakerEmotion {
  const pos = countHits(text, POSITIVE);
  const hes = countHits(text, HESITATION);
  const price = countHits(text, PRICE);
  const anger = countHits(text, ANGER);
  const isQuestion = text.includes("?");

  const scores = zeroScores();
  scores.positive = clamp(20 + pos * 25);
  scores.stressed = clamp(10 + hes * 25 + price * 15);
  scores.suspicious = clamp(price * 30 + hes * 15);
  scores.angry = clamp(anger * 25);
  scores.aggressive = clamp(anger * 20);
  scores.disappointed = clamp(hes * 10);
  scores.neutral = clamp(60 - pos * 15 - hes * 10 - price * 10);

  // Sellers (A) asking questions read as more dominant/leading.
  const dominance = clamp((speaker === "A" ? 55 : 40) + (isQuestion ? 15 : 0) - hes * 10);
  const trust = clamp(45 + pos * 12 - price * 12 - anger * 15);
  const stress = scores.stressed;

  let intent = "engaging";
  if (price > 0) intent = "raising price objection";
  else if (hes > 0) intent = "hesitating";
  else if (pos > 0) intent = "showing interest";
  else if (isQuestion && speaker === "A") intent = "probing for needs";

  return { speaker, scores, trust, dominance, stress, intent };
}

function deriveInsights(window: Utterance[]): AnalysisInsight[] {
  const last = window[window.length - 1];
  if (!last) return [];
  const insights: AnalysisInsight[] = [];
  if (countHits(last.text, PRICE) > 0) {
    insights.push({ severity: "warn", text: "Price objection — lead with ROI" });
  }
  if (countHits(last.text, HESITATION) > 0) {
    insights.push({ severity: "warn", text: "Customer is hesitating — ask an open question" });
  }
  if (countHits(last.text, ANGER) > 0) {
    insights.push({ severity: "critical", text: "Tension rising — lower your tone" });
  }
  if (countHits(last.text, POSITIVE) > 0 && last.speaker === "B") {
    insights.push({ severity: "info", text: "Customer responding well — move toward next step" });
  }
  return insights;
}

export class StubEmotionAnalyzer implements EmotionAnalyzer {
  async analyzeWindow(
    window: Utterance[],
    _elapsedSec: number,
  ): Promise<WindowAnalysis> {
    // Use the most recent utterance per speaker in the window.
    const latestBySpeaker = new Map<Speaker, Utterance>();
    for (const u of window) latestBySpeaker.set(u.speaker, u);
    const emotions: SpeakerEmotion[] = [...latestBySpeaker.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([speaker, u]) => scoreUtterance(u.text, speaker));
    return { emotions, insights: deriveInsights(window) };
  }

  async buildReport(
    utterances: Utterance[],
    timeline: TimelinePoint[],
  ): Promise<PostCallReport> {
    if (utterances.length === 0) return emptyReport();

    const customerLines = utterances.filter((u) => u.speaker === "B");
    const posHits = customerLines.reduce((n, u) => n + countHits(u.text, POSITIVE), 0);
    const priceHits = utterances.reduce((n, u) => n + countHits(u.text, PRICE), 0);
    const hesHits = utterances.reduce((n, u) => n + countHits(u.text, HESITATION), 0);

    const customerEmotion = clamp(45 + posHits * 8 - hesHits * 6);
    const trustLevel = clamp(50 + posHits * 6 - priceHits * 8);
    const conversionProbability = clamp(40 + posHits * 10 - priceHits * 6 - hesHits * 4);
    const sellerScore = clamp(55 + posHits * 5 - hesHits * 3);

    const total = utterances.length;
    const sliceSummary = (from: number, to: number, fallback: string) => {
      const part = utterances.slice(from, to);
      const price = part.reduce((n, u) => n + countHits(u.text, PRICE), 0);
      const pos = part.reduce((n, u) => n + countHits(u.text, POSITIVE), 0);
      if (price > 0) return "Price objection surfaced";
      if (pos > 0) return "Positive momentum";
      return fallback;
    };

    const sections: PostCallReport["sections"] = [
      { name: "opening", summary: sliceSummary(0, Math.ceil(total / 3), "Rapport building"), energy: "medium" },
      { name: "middle", summary: sliceSummary(Math.ceil(total / 3), Math.ceil((2 * total) / 3), "Discovery"), energy: priceHits > 0 ? "high" : "medium" },
      { name: "close", summary: sliceSummary(Math.ceil((2 * total) / 3), total, "Wrap-up"), energy: posHits > 0 ? "high" : "low" },
    ];

    return {
      summary: `Call covered ${total} exchanges. ${
        priceHits > 0 ? "A price objection came up but " : ""
      }${posHits > 0 ? "the customer warmed up by the end." : "the customer stayed reserved."} Conversion looks ${
        conversionProbability >= 60 ? "promising" : "uncertain"
      }.`,
      scores: { sellerScore, customerEmotion, trustLevel, conversionProbability },
      sections,
      events: buildStubEvents(utterances),
      timeline: timeline.length > 0 ? timeline : [],
    };
  }
}

function buildStubEvents(utterances: Utterance[]): PostCallReport["events"] {
  const events: PostCallReport["events"] = [];
  for (const u of utterances) {
    if (countHits(u.text, ANGER) > 0) {
      events.push({ type: "aggressive_reaction", t: u.tStart, note: `${u.speaker} pushed back` });
    }
    if (countHits(u.text, POSITIVE) > 1) {
      events.push({ type: "excitement_spike", t: u.tStart, note: `${u.speaker} showed enthusiasm` });
    }
  }
  return events;
}
