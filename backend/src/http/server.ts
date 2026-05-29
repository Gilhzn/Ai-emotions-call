import express, { type Express } from "express";
import multer from "multer";
import type { Providers } from "../providers.js";
import { analyzeFile } from "./analyzeFile.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
});

/**
 * Build the Express app. Kept separate from `listen()` so tests can mount it
 * (e.g. with supertest) without binding a port.
 */
export function createApp(providers: Providers): Express {
  const app = express();

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  // Batch analysis of a complete recording — used for testing + the app's
  // "Import recording" flow.
  app.post("/analyze-file", upload.single("audio"), async (req, res) => {
    if (!req.file) {
      res.status(400).json({ error: "missing 'audio' file field" });
      return;
    }
    try {
      const result = await analyzeFile(
        providers,
        req.file.buffer,
        req.file.mimetype,
      );
      res.json(result);
    } catch (err) {
      res
        .status(500)
        .json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  return app;
}
