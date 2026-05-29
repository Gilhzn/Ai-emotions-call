/**
 * Throttles realtime analysis so we call the LLM at most once per
 * `minIntervalMs`, never overlap two analyses, and always run once more if new
 * transcript arrived while the previous analysis was in flight. This keeps the
 * transcript path instant (analysis runs off it) while bounding latency + cost.
 */
export interface AnalysisSchedulerOptions {
  minIntervalMs: number;
  run: () => Promise<void>;
  onError?: (err: unknown) => void;
}

export class AnalysisScheduler {
  private pending = false;
  private running = false;
  private lastRunAt = -Infinity;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private stopped = false;

  constructor(private opts: AnalysisSchedulerOptions) {}

  /** Signal that new finalized transcript is available. */
  notify(): void {
    if (this.stopped) return;
    this.pending = true;
    this.schedule();
  }

  /** Run immediately (used on call stop), bypassing the interval. */
  async flush(): Promise<void> {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    if (!this.pending) return;
    await this.fire();
  }

  stop(): void {
    this.stopped = true;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  private schedule(): void {
    if (this.timer || this.running || this.stopped) return;
    const elapsed = Date.now() - this.lastRunAt;
    const delay = Math.max(0, this.opts.minIntervalMs - elapsed);
    this.timer = setTimeout(() => {
      this.timer = null;
      void this.fire();
    }, delay);
  }

  private async fire(): Promise<void> {
    if (this.running || this.stopped) return;
    this.pending = false;
    this.running = true;
    this.lastRunAt = Date.now();
    try {
      await this.opts.run();
    } catch (err) {
      this.opts.onError?.(err);
    } finally {
      this.running = false;
      // New transcript arrived mid-run — schedule another pass.
      if (this.pending && !this.stopped) this.schedule();
    }
  }
}
