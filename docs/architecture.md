# EmotionCall AI — architecture (v1)

## Goal

Listen to a live conversation, transcribe it in real time, and surface a live
"emotional map" of both speakers (emotion, trust, dominance, stress, intent),
plus a post-call analysis report. v1 targets **sales / general** calls.

## Pipeline

```
 Flutter app (mic / file)
        │  PCM16 16kHz mono, ~100ms frames  (WebSocket binary)
        ▼
 Backend proxy (Node + TS)  ── holds all API keys ──
        │
        ├─► Deepgram streaming STT (diarized)  ──► transcript events ──► app
        │
        ├─► rolling transcript buffer
        │        │  (debounced, ≥ ANALYSIS_MIN_INTERVAL_MS, no overlap)
        │        ▼
        │   Claude (forced tool-use) ──► per-speaker emotion + insights ──► app
        │
        └─► on stop: Claude report ──► PostCallReport ──► app
```

Key principle: **the LLM is off the transcript path.** Transcript renders the
instant Deepgram emits it; emotion analysis runs asynchronously and is throttled
by `AnalysisScheduler`, so meters lag at most ~1 utterance while transcript and
audio stay real-time.

## Why a backend proxy

API keys (Deepgram, Anthropic) must never ship inside a mobile binary. The
backend is the only component that holds secrets; the app only knows the backend
URL (`--dart-define=BACKEND_URL`). The backend also lets us swap STT/LLM
providers and throttle/cost-control LLM calls centrally.

## Components

### Backend (`backend/`)
- `src/contract.ts` — canonical WS message types + guards.
- `src/config.ts` — zod-validated env; auto-falls back to stubs when keys are absent.
- `src/stt/` — `SttProvider` interface, `DeepgramProvider` (real), `StubSttProvider` (scripted, network-free).
- `src/analysis/` — `EmotionAnalyzer` interface, `ClaudeEmotionAnalyzer` (forced tool-use + prompt caching), `StubEmotionAnalyzer` (keyword heuristics), `AnalysisScheduler` (debounce/no-overlap), `prompts.ts`.
- `src/pipeline/CallSession.ts` — per-connection orchestration.
- `src/ws/callSocket.ts` — `/call` WebSocket endpoint.
- `src/http/` — Express app + `/analyze-file` batch path (`analyzeFile.ts`).

### App (`app/`, Flutter + Riverpod)
- `core/models/` — Dart mirrors of the contract.
- `core/ws/` — `CallClient` (socket) + `ServerMessage` parsing.
- `services/` — `AudioCaptureService` (mic → PCM16 via `record`), `FileAnalysisService` (upload).
- `features/call/` — `CallController` (state) + `CallScreen` + widgets (emotion meter, timeline, recommendations, transcript).
- `features/postcall/` — `PostCallScreen` (score gauges, sections, events, timeline).
- `features/home/` — entry: start live / import recording.

## Stub mode

When `DEEPGRAM_API_KEY`/`ANTHROPIC_API_KEY` are missing (or
`USE_STUB_PROVIDERS=true`), the backend uses deterministic, network-free
providers: a scripted two-speaker sales conversation + keyword-based emotion
heuristics. This keeps the whole pipeline runnable and testable in CI without
keys or network, and lets the app be demoed offline.

## Known v1 limitations / risks
- **No acoustic emotion** yet — emotion is inferred from text only. Adding
  wav2vec2/OpenSMILE acoustic features is a planned enhancement.
- **Diarization** on a single far-field mic can mislabel speakers → manual
  "swap speakers" control.
- **iOS** cannot tap system phone calls; v1 uses in-app mic only.
- **Latency/cost** bounded by `AnalysisScheduler` + prompt caching, but realtime
  LLM analysis still costs per finalized utterance.

## Roadmap (post-v1)
Acoustic emotion models · VoIP/WebRTC two-party calls · AI Coach history ·
additional personas (recruiter / relationship / legal) · enterprise dashboards ·
on-device/private processing mode · E2E encryption + retention controls.
