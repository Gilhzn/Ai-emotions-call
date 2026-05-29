import {
  EMOTION_KEYS,
  type EmotionMessage,
  type EmotionScores,
  type InsightMessage,
  type PostCallReport,
  type Speaker,
  type TimelinePoint,
  type TranscriptMessage,
} from "../contract.js";
import type { Providers } from "../providers.js";
import type { SpeakerEmotion } from "../analysis/EmotionAnalyzer.js";

const WINDOW_SIZE = 8;

export interface FileAnalysisResult {
  transcript: TranscriptMessage[];
  emotionFrames: EmotionMessage[];
  insights: InsightMessage[];
  report: PostCallReport;
}

/**
 * Batch counterpart to {@link CallSession}: transcribe a complete file, run the
 * same windowed emotion analysis over the utterances, and build the report.
 * This drives the `/analyze-file` endpoint and is the primary CI integration
 * test path (no device, no live socket required).
 */
export async function analyzeFile(
  providers: Providers,
  audio: Buffer,
  mimeType: string,
): Promise<FileAnalysisResult> {
  const utterances = await providers.stt.transcribeFile(audio, mimeType);

  const transcript: TranscriptMessage[] = utterances.map((u) => ({
    type: "transcript",
    speaker: u.speaker,
    text: u.text,
    isFinal: true,
    tStart: u.tStart,
    tEnd: u.tEnd,
  }));

  const emotionFrames: EmotionMessage[] = [];
  const insights: InsightMessage[] = [];
  const timeline: TimelinePoint[] = [];

  for (let i = 0; i < utterances.length; i++) {
    const window = utterances.slice(Math.max(0, i - WINDOW_SIZE + 1), i + 1);
    const t = utterances[i]!.tEnd;
    const { emotions, insights: ins } =
      await providers.analyzer.analyzeWindow(window, t);

    for (const e of emotions) {
      emotionFrames.push({
        type: "emotion",
        speaker: e.speaker,
        t,
        scores: e.scores,
        trust: e.trust,
        dominance: e.dominance,
        stress: e.stress,
        intent: e.intent,
      });
    }
    for (const ix of ins) {
      insights.push({ type: "insight", t, severity: ix.severity, text: ix.text });
    }
    const point = aggregateTimelinePoint(emotions, t);
    if (point) timeline.push(point);
  }

  const report = await providers.analyzer.buildReport(utterances, timeline);
  return { transcript, emotionFrames, insights, report };
}

function aggregateTimelinePoint(
  emotions: SpeakerEmotion[],
  t: number,
): TimelinePoint | null {
  if (emotions.length === 0) return null;
  const avg = (sel: (e: SpeakerEmotion) => number) =>
    Math.round(emotions.reduce((s, e) => s + sel(e), 0) / emotions.length);
  const summed = EMOTION_KEYS.reduce((acc, k) => {
    acc[k] = emotions.reduce((s, e) => s + e.scores[k], 0);
    return acc;
  }, {} as EmotionScores);
  let dominant: keyof EmotionScores = "neutral";
  let best = -1;
  for (const k of EMOTION_KEYS) {
    if (summed[k] > best) {
      best = summed[k];
      dominant = k;
    }
  }
  return {
    t,
    trust: avg((e) => e.trust),
    stress: avg((e) => e.stress),
    dominance: avg((e) => e.dominance),
    emotionDominant: dominant,
  };
}

// Re-export to keep Speaker referenced for downstream typing clarity.
export type { Speaker };
