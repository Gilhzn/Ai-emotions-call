import type { PostCallReport } from "../contract.js";

/** A neutral, well-formed report used as a fallback / empty-call default. */
export function emptyReport(): PostCallReport {
  return {
    summary: "Not enough conversation was captured to analyze.",
    scores: {
      sellerScore: 50,
      customerEmotion: 50,
      trustLevel: 50,
      conversionProbability: 50,
    },
    sections: [],
    events: [],
    timeline: [],
  };
}
