import { describe, expect, it } from "vitest";
import { EMOTION_KEYS } from "../src/contract.js";
import { StubSttProvider } from "../src/stt/StubSttProvider.js";
import { StubEmotionAnalyzer } from "../src/analysis/StubEmotionAnalyzer.js";
import { analyzeFile } from "../src/http/analyzeFile.js";

const providers = {
  stt: new StubSttProvider(),
  analyzer: new StubEmotionAnalyzer(),
};

const inRange = (n: number) => n >= 0 && n <= 100;

describe("analyzeFile (stub pipeline)", () => {
  it("produces a transcript, emotion frames, insights and a well-formed report", async () => {
    const audio = Buffer.alloc(1024); // stub ignores content
    const result = await analyzeFile(providers, audio, "audio/wav");

    // Transcript: the stub script has 10 lines across two speakers.
    expect(result.transcript).toHaveLength(10);
    expect(result.transcript.every((t) => t.isFinal)).toBe(true);
    expect(new Set(result.transcript.map((t) => t.speaker))).toEqual(
      new Set(["A", "B"]),
    );

    // Emotion frames present and in range.
    expect(result.emotionFrames.length).toBeGreaterThan(0);
    for (const f of result.emotionFrames) {
      for (const k of EMOTION_KEYS) expect(inRange(f.scores[k])).toBe(true);
      expect(inRange(f.trust)).toBe(true);
      expect(inRange(f.dominance)).toBe(true);
      expect(inRange(f.stress)).toBe(true);
      expect(typeof f.intent).toBe("string");
    }

    // The script contains a price objection, so we expect at least one insight.
    expect(result.insights.length).toBeGreaterThan(0);
    expect(result.insights.some((i) => /price/i.test(i.text))).toBe(true);

    // Report shape + score ranges.
    const { report } = result;
    expect(typeof report.summary).toBe("string");
    for (const v of Object.values(report.scores)) expect(inRange(v)).toBe(true);
    expect(report.sections.map((s) => s.name)).toEqual([
      "opening",
      "middle",
      "close",
    ]);
    expect(Array.isArray(report.events)).toBe(true);
    expect(report.timeline.length).toBeGreaterThan(0);
    for (const p of report.timeline) {
      expect(inRange(p.trust)).toBe(true);
      expect(EMOTION_KEYS).toContain(p.emotionDominant);
    }
  });
});
