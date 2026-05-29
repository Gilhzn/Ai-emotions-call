import type { Speaker } from "../contract.js";

/** One finalized or interim transcript chunk emitted by an STT provider. */
export interface TranscriptChunk {
  speaker: Speaker;
  text: string;
  isFinal: boolean;
  tStart: number;
  tEnd: number;
}

/** A finalized utterance used as input to the emotion analyzer + report. */
export interface Utterance {
  speaker: Speaker;
  text: string;
  tStart: number;
  tEnd: number;
}

/**
 * A live streaming STT session. The pipeline feeds it raw PCM16 audio frames
 * and receives transcript chunks via the callbacks.
 */
export interface LiveSttSession {
  sendAudio(chunk: Buffer): void;
  /** Signal end of audio; provider should flush remaining results then close. */
  finish(): Promise<void>;
}

export interface LiveSttCallbacks {
  onTranscript: (chunk: TranscriptChunk) => void;
  onError: (err: Error) => void;
}

export interface LiveSttOptions {
  sampleRate: number;
  encoding: "linear16";
}

/** Maps a provider's raw speaker index (0/1/...) to our Speaker labels. */
export function indexToSpeaker(index: number): Speaker {
  return index % 2 === 0 ? "A" : "B";
}

export interface SttProvider {
  /** Open a streaming recognition session. */
  openLive(opts: LiveSttOptions, cb: LiveSttCallbacks): Promise<LiveSttSession>;
  /** Transcribe a complete audio file (used by the /analyze-file path + tests). */
  transcribeFile(audio: Buffer, mimeType: string): Promise<Utterance[]>;
}
