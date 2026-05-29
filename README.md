# EmotionCall AI

Realtime conversation intelligence: listen to a call, transcribe it live, and
show a live **emotional map** of both speakers — emotion, trust, dominance,
stress, intent, and AI coaching — plus a full **post-call analysis** report.
v1 is tuned for **sales / general** calls.

> This is the **v1 MVP**: a Flutter mobile app + a Node backend proxy, using
> **Deepgram** (streaming STT, diarized) and **Claude** (emotion/intent +
> report). Audio source is the in-app microphone, plus importing a recorded
> file. See [`docs/architecture.md`](docs/architecture.md) for the full design
> and the roadmap toward the larger vision.

```
app/       Flutter mobile app (UI + mic capture)
backend/   Node + TypeScript proxy (holds API keys; STT + LLM pipeline)
docs/      architecture + WebSocket contract
```

## How it works

The app streams microphone audio to the backend over a WebSocket. The backend
(the only component holding API keys) runs: **audio → Deepgram STT → rolling
transcript → debounced Claude emotion analysis → realtime events**, and a
**post-call report** when the call ends. Transcript renders instantly;
emotion analysis runs off the transcript path and is throttled to bound latency
and cost. See [`docs/websocket-contract.md`](docs/websocket-contract.md).

## 1. Backend

```bash
cd backend
npm install
cp .env.example .env        # add DEEPGRAM_API_KEY and ANTHROPIC_API_KEY
npm run dev                 # ws://localhost:8080/call  +  POST /analyze-file
```

**No keys?** The backend automatically runs in **stub mode** — deterministic,
network-free providers that emit a scripted sales conversation and heuristic
emotions, so you can run and demo the whole pipeline offline.

Backend commands:

| command | what |
| --- | --- |
| `npm run dev` | run with hot reload |
| `npm test` | vitest suite (scheduler, contract, file pipeline, WS contract) |
| `npm run typecheck` | `tsc` no-emit |
| `npm run build` / `npm start` | compile to `dist/` and run |
| `npm run simulate` | stream synthetic audio at the live `/call` socket |

Quick check without the app:

```bash
curl -s -X POST http://localhost:8080/analyze-file -F "audio=@some.wav;type=audio/wav" | jq
```

## 2. App (Flutter)

The Flutter source lives in `app/lib`. Native platform folders are **not**
checked in — generate them once, then run.

```bash
cd app
flutter create --platforms=android,ios .   # one-time: add android/ & ios/ folders
flutter pub get
flutter analyze
flutter test                               # model + widget tests (no device needed)
```

Add the microphone permission to the generated native projects:

- **Android** — `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  <uses-permission android:name="android.permission.INTERNET" />
  ```
- **iOS** — `ios/Runner/Info.plist`:
  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>EmotionCall analyzes the live conversation to show realtime emotion.</string>
  ```

Run on a device/emulator, pointing at your backend:

```bash
# Android emulator reaches the host machine at 10.0.2.2
flutter run --dart-define=BACKEND_URL=ws://10.0.2.2:8080

# Physical device: use your computer's LAN IP
flutter run --dart-define=BACKEND_URL=ws://192.168.1.50:8080
```

The app holds **no API keys** — only the backend URL.

## 3. Try it

1. Start the backend (stub mode is fine).
2. Launch the app → **Start live call**, grant mic permission, and talk (phone
   on speaker works well for two voices). Watch the transcript, per-speaker
   emotion meters, the live timeline, and AI recommendations. Tap **End &
   Analyze** for the post-call report.
3. Or tap **Import a recording** to analyze an existing audio file.

## Privacy & legal

Recording calls is regulated (some jurisdictions require all-party consent;
GDPR applies to EU data). v1 uses in-app microphone capture only and does not
tap system phone calls. Encryption at rest/in transit, retention controls, and a
private/on-device processing mode are on the roadmap — see
[`docs/architecture.md`](docs/architecture.md).
