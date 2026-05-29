import {
  EMOTION_KEYS,
  type EmotionScores,
  type ServerMessage,
  type Speaker,
  type StartMessage,
  type TimelinePoint,
} from "../contract.js";
import type { LiveSttSession, Utterance } from "../stt/SttProvider.js";
import type { Providers } from "../providers.js";
import { AnalysisScheduler } from "../analysis/scheduler.js";
import type { SpeakerEmotion } from "../analysis/EmotionAnalyzer.js";

/** Number of recent utterances sent to the analyzer each pass. */
const WINDOW_SIZE = 8;

export interface CallSessionOptions {
  providers: Providers;
  analysisMinIntervalMs: number;
  /** Sends a JSON message to the connected client. */
  emit: (msg: ServerMessage) => void;
}

/**
 * Orchestrates one call: audio -> STT -> rolling transcript -> debounced
 * emotion analysis -> realtime events, and a post-call report on stop. One
 * instance per WebSocket connection.
 */
export class CallSession {
  private sttSession: LiveSttSession | null = null;
  private scheduler: AnalysisScheduler;
  private utterances: Utterance[] = [];
  private timeline: TimelinePoint[] = [];
  private startedAt = 0;
  private swapped = false;
  private closed = false;

  constructor(private opts: CallSessionOptions) {
    this.scheduler = new AnalysisScheduler({
      minIntervalMs: opts.analysisMinIntervalMs,
      run: () => this.runAnalysis(),
      onError: (err) =>
        this.emitError("analysis_failed", errMessage(err)),
    });
  }

  async start(msg: StartMessage): Promise<void> {
    this.startedAt = Date.now();
    this.opts.emit({ type: "status", state: "listening" });
    try {
      this.sttSession = await this.opts.providers.stt.openLive(
        { sampleRate: msg.sampleRate, encoding: msg.encoding },
        {
          onTranscript: (chunk) => this.onTranscript(chunk),
          onError: (err) => this.emitError("stt_error", err.message),
        },
      );
    } catch (err) {
      this.emitError("stt_open_failed", errMessage(err));
    }
  }

  handleAudio(buf: Buffer): void {
    this.sttSession?.sendAudio(buf);
  }

  swapSpeakers(): void {
    this.swapped = !this.swapped;
  }

  private mapSpeaker(s: Speaker): Speaker {
    if (!this.swapped) return s;
    return s === "A" ? "B" : "A";
  }

  private onTranscript(chunk: {
    speaker: Speaker;
    text: string;
    isFinal: boolean;
    tStart: number;
    tEnd: number;
  }): void {
    const speaker = this.mapSpeaker(chunk.speaker);
    this.opts.emit({
      type: "transcript",
      speaker,
      text: chunk.text,
      isFinal: chunk.isFinal,
      tStart: chunk.tStart,
      tEnd: chunk.tEnd,
    });
    if (chunk.isFinal) {
      this.utterances.push({
        speaker,
        text: chunk.text,
        tStart: chunk.tStart,
        tEnd: chunk.tEnd,
      });
      this.scheduler.notify();
    }
  }

  private elapsedSec(): number {
    return (Date.now() - this.startedAt) / 1000;
  }

  private async runAnalysis(): Promise<void> {
    if (this.closed) return;
    const window = this.utterances.slice(-WINDOW_SIZE);
    if (window.length === 0) return;
    const elapsed = this.elapsedSec();
    const { emotions, insights } =
      await this.opts.providers.analyzer.analyzeWindow(window, elapsed);

    for (const e of emotions) {
      this.opts.emit({
        type: "emotion",
        speaker: e.speaker,
        t: elapsed,
        scores: e.scores,
        trust: e.trust,
        dominance: e.dominance,
        stress: e.stress,
        intent: e.intent,
      });
    }
    for (const i of insights) {
      this.opts.emit({ type: "insight", t: elapsed, severity: i.severity, text: i.text });
    }

    const point = aggregateTimelinePoint(emotions, elapsed);
    if (point) this.timeline.push(point);
  }

  async stop(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    this.opts.emit({ type: "status", state: "analyzing" });
    try {
      await this.sttSession?.finish();
    } catch {
      /* ignore close errors */
    }
    // Run one last analysis pass on whatever arrived since the last one.
    await this.scheduler.flush();
    this.scheduler.stop();

    try {
      const report = await this.opts.providers.analyzer.buildReport(
        this.utterances,
        this.timeline,
      );
      this.opts.emit({ type: "report", report });
    } catch (err) {
      this.emitError("report_failed", errMessage(err));
    }
    this.opts.emit({ type: "status", state: "stopped" });
  }

  /** Tear down without producing a report (e.g. socket dropped). */
  abort(): void {
    this.closed = true;
    this.scheduler.stop();
    void this.sttSession?.finish().catch(() => {});
  }

  private emitError(code: string, message: string): void {
    this.opts.emit({ type: "error", code, message });
  }
}

/** Collapse per-speaker emotions into a single timeline sample. */
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

function errMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
