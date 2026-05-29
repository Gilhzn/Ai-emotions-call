import {
  createClient,
  LiveTranscriptionEvents,
  type DeepgramClient,
} from "@deepgram/sdk";
import {
  indexToSpeaker,
  type LiveSttCallbacks,
  type LiveSttOptions,
  type LiveSttSession,
  type SttProvider,
  type TranscriptChunk,
  type Utterance,
} from "./SttProvider.js";

/**
 * Real STT via Deepgram. Streaming for live calls, prerecorded for file uploads.
 * Diarization (`diarize=true`) splits the two speakers; we map channel 0 -> A,
 * 1 -> B (the app can flip this with `swapSpeakers`).
 *
 * NOTE: this talks to the Deepgram cloud, so it is only exercised by opt-in
 * `*.live.test.ts` (gated on a real key), not by the default CI suite.
 */
export class DeepgramProvider implements SttProvider {
  private client: DeepgramClient;

  constructor(apiKey: string) {
    this.client = createClient(apiKey);
  }

  async openLive(
    opts: LiveSttOptions,
    cb: LiveSttCallbacks,
  ): Promise<LiveSttSession> {
    const connection = this.client.listen.live({
      model: "nova-2",
      language: "en",
      encoding: opts.encoding,
      sample_rate: opts.sampleRate,
      channels: 1,
      diarize: true,
      punctuate: true,
      interim_results: true,
      smart_format: true,
    });

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(
        () => reject(new Error("Deepgram live connection timed out")),
        10_000,
      );
      connection.on(LiveTranscriptionEvents.Open, () => {
        clearTimeout(timeout);
        resolve();
      });
      connection.on(LiveTranscriptionEvents.Error, (err: unknown) => {
        clearTimeout(timeout);
        reject(err instanceof Error ? err : new Error(String(err)));
      });
    });

    connection.on(LiveTranscriptionEvents.Transcript, (data: any) => {
      const chunk = mapLiveTranscript(data);
      if (chunk) cb.onTranscript(chunk);
    });
    connection.on(LiveTranscriptionEvents.Error, (err: unknown) => {
      cb.onError(err instanceof Error ? err : new Error(String(err)));
    });

    return {
      sendAudio(buf: Buffer) {
        // Send the exact bytes as an ArrayBuffer (Deepgram's send() typing
        // doesn't accept Node Buffers directly).
        connection.send(
          buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength),
        );
      },
      async finish() {
        connection.requestClose();
      },
    };
  }

  async transcribeFile(audio: Buffer, _mimeType: string): Promise<Utterance[]> {
    const { result, error } =
      await this.client.listen.prerecorded.transcribeFile(audio, {
        model: "nova-2",
        language: "en",
        diarize: true,
        punctuate: true,
        smart_format: true,
        utterances: true,
      });
    if (error) throw error instanceof Error ? error : new Error(String(error));
    return mapPrerecorded(result);
  }
}

/** Convert a Deepgram live transcript event into our TranscriptChunk shape. */
function mapLiveTranscript(data: any): TranscriptChunk | null {
  const alt = data?.channel?.alternatives?.[0];
  const text: string = alt?.transcript ?? "";
  if (!text.trim()) return null;
  const words: any[] = alt?.words ?? [];
  const speakerIndex: number = words[0]?.speaker ?? 0;
  const tStart: number = typeof data?.start === "number" ? data.start : 0;
  const duration: number = typeof data?.duration === "number" ? data.duration : 0;
  return {
    speaker: indexToSpeaker(speakerIndex),
    text,
    isFinal: Boolean(data?.is_final),
    tStart,
    tEnd: tStart + duration,
  };
}

/** Convert a Deepgram prerecorded result into our finalized Utterance list. */
function mapPrerecorded(result: any): Utterance[] {
  const utterances: any[] = result?.results?.utterances ?? [];
  if (utterances.length > 0) {
    return utterances
      .filter((u) => (u?.transcript ?? "").trim().length > 0)
      .map((u) => ({
        speaker: indexToSpeaker(u?.speaker ?? 0),
        text: u.transcript as string,
        tStart: u?.start ?? 0,
        tEnd: u?.end ?? 0,
      }));
  }
  // Fallback: stitch diarized words into utterances when `utterances` is absent.
  const words: any[] =
    result?.results?.channels?.[0]?.alternatives?.[0]?.words ?? [];
  const out: Utterance[] = [];
  let current: Utterance | null = null;
  for (const w of words) {
    const speaker = indexToSpeaker(w?.speaker ?? 0);
    const token = (w?.punctuated_word ?? w?.word ?? "") as string;
    if (!current || current.speaker !== speaker) {
      if (current) out.push(current);
      current = { speaker, text: token, tStart: w?.start ?? 0, tEnd: w?.end ?? 0 };
    } else {
      current.text += ` ${token}`;
      current.tEnd = w?.end ?? current.tEnd;
    }
  }
  if (current) out.push(current);
  return out;
}
