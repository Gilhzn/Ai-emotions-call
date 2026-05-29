import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AnalysisScheduler } from "../src/analysis/scheduler.js";

describe("AnalysisScheduler", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("runs once after the min interval following a notify", async () => {
    const run = vi.fn(async () => {});
    const s = new AnalysisScheduler({ minIntervalMs: 1000, run });

    s.notify();
    expect(run).not.toHaveBeenCalled(); // first run waits the interval from -Inf? no: elapsed huge -> delay 0
    await vi.advanceTimersByTimeAsync(0);
    expect(run).toHaveBeenCalledTimes(1);
  });

  it("coalesces rapid notifies into a single run within the interval", async () => {
    const run = vi.fn(async () => {});
    const s = new AnalysisScheduler({ minIntervalMs: 1000, run });

    s.notify();
    await vi.advanceTimersByTimeAsync(0); // first run fires immediately (no prior run)
    expect(run).toHaveBeenCalledTimes(1);

    // Three notifies during the cool-down should collapse to one more run.
    s.notify();
    s.notify();
    s.notify();
    await vi.advanceTimersByTimeAsync(1000);
    expect(run).toHaveBeenCalledTimes(2);
  });

  it("does not overlap runs and reschedules work that arrives mid-run", async () => {
    let resolveRun: () => void = () => {};
    const run = vi.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveRun = resolve;
        }),
    );
    const s = new AnalysisScheduler({ minIntervalMs: 0, run });

    s.notify();
    await vi.advanceTimersByTimeAsync(0);
    expect(run).toHaveBeenCalledTimes(1); // in-flight, not resolved

    s.notify(); // arrives while running
    await vi.advanceTimersByTimeAsync(50);
    expect(run).toHaveBeenCalledTimes(1); // still only one (no overlap)

    resolveRun();
    await vi.advanceTimersByTimeAsync(0);
    expect(run).toHaveBeenCalledTimes(2); // pending work scheduled after completion
  });

  it("flush runs pending work immediately", async () => {
    const run = vi.fn(async () => {});
    const s = new AnalysisScheduler({ minIntervalMs: 100000, run });
    // Prime lastRun so the next notify would otherwise wait a long time.
    s.notify();
    await vi.advanceTimersByTimeAsync(0);
    expect(run).toHaveBeenCalledTimes(1);

    s.notify();
    await s.flush();
    expect(run).toHaveBeenCalledTimes(2);
  });
});
