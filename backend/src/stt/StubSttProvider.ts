import {
  indexToSpeaker,
  type LiveSttCallbacks,
  type LiveSttOptions,
  type LiveSttSession,
  type SttProvider,
  type Utterance,
} from "./SttProvider.js";

/**
 * Deterministic, network-free STT used when real keys are absent, when
 * USE_STUB_PROVIDERS=true, and in tests. It does NOT actually recognize speech;
 * it emits a fixed two-speaker sales script so the rest of the pipeline (emotion
 * analysis, timeline, report) can be exercised end-to-end.
 */
const SCRIPT: Omit<Utterance, "tStart" | "tEnd">[] = [
  { speaker: "A", text: "Hi, thanks for taking the call today. How are you doing?" },
  { speaker: "B", text: "I'm alright. To be honest I'm pretty busy, so let's keep it short." },
  { speaker: "A", text: "Absolutely. I'll get right to it — I think our plan can save your team real time." },
  { speaker: "B", text: "I'm not sure this is the right fit for us right now." },
  { speaker: "A", text: "Totally understand. Can I ask what's making you hesitate?" },
  { speaker: "B", text: "Honestly the price feels high compared to what we use today." },
  { speaker: "A", text: "That's fair. A lot of customers felt that way before they saw the ROI." },
  { speaker: "B", text: "Okay... if you can show me the numbers, I'm willing to look." },
  { speaker: "A", text: "Great, I'll send a breakdown right after this. Does Thursday work to review?" },
  { speaker: "B", text: "Yeah, Thursday could work. Send it over and we'll see." },
];

/** Seconds each scripted utterance occupies, for synthetic timestamps. */
const SECONDS_PER_UTTERANCE = 6;

function scriptToUtterances(): Utterance[] {
  return SCRIPT.map((u, i) => ({
    ...u,
    tStart: i * SECONDS_PER_UTTERANCE,
    tEnd: i * SECONDS_PER_UTTERANCE + SECONDS_PER_UTTERANCE - 1,
  }));
}

export class StubSttProvider implements SttProvider {
  async openLive(
    _opts: LiveSttOptions,
    cb: LiveSttCallbacks,
  ): Promise<LiveSttSession> {
    const utterances = scriptToUtterances();
    let index = 0;
    // Bytes of audio received before we advance the script. PCM16 mono @16k is
    // 32000 bytes/sec; advance roughly once per ~1.5s of audio so a streamed
    // fixture produces a believable cadence.
    let bytesSinceLast = 0;
    const ADVANCE_EVERY_BYTES = 48000;

    const emitNext = () => {
      if (index >= utterances.length) return;
      const u = utterances[index]!;
      cb.onTranscript({ ...u, isFinal: true });
      index += 1;
    };

    return {
      sendAudio(chunk: Buffer) {
        bytesSinceLast += chunk.length;
        while (bytesSinceLast >= ADVANCE_EVERY_BYTES && index < utterances.length) {
          bytesSinceLast -= ADVANCE_EVERY_BYTES;
          emitNext();
        }
      },
      async finish() {
        // Flush any remaining scripted lines.
        while (index < utterances.length) emitNext();
      },
    };
  }

  async transcribeFile(): Promise<Utterance[]> {
    return scriptToUtterances();
  }
}

export { indexToSpeaker };
