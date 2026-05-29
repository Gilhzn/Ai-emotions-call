import type {
  EmotionScores,
  InsightSeverity,
  PostCallReport,
  Speaker,
  TimelinePoint,
} from "../contract.js";
import type { Utterance } from "../stt/SttProvider.js";

/** Per-speaker emotional read produced for one analysis window. */
export interface SpeakerEmotion {
  speaker: Speaker;
  scores: EmotionScores;
  trust: number;
  dominance: number;
  stress: number;
  intent: string;
}

export interface AnalysisInsight {
  severity: InsightSeverity;
  text: string;
}

export interface WindowAnalysis {
  emotions: SpeakerEmotion[];
  insights: AnalysisInsight[];
}

/**
 * Turns a rolling window of transcript into per-speaker emotion reads + coaching
 * insights, and (post-call) a full report. Implemented by the real Claude
 * analyzer and a deterministic stub.
 */
export interface EmotionAnalyzer {
  analyzeWindow(
    window: Utterance[],
    elapsedSec: number,
  ): Promise<WindowAnalysis>;

  buildReport(
    utterances: Utterance[],
    timeline: TimelinePoint[],
  ): Promise<PostCallReport>;
}
