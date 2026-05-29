# EmotionCall AI — WebSocket contract

Language-neutral description of the realtime protocol. The canonical typed
source is [`backend/src/contract.ts`](../backend/src/contract.ts); the Dart
mirror lives in [`app/lib/core/models/`](../app/lib/core/models/) and
[`app/lib/core/ws/server_message.dart`](../app/lib/core/ws/server_message.dart).
Keep all three in sync.

## Connection

- Endpoint: `GET ws(s)://<backend>/call` (WebSocket upgrade).
- One connection per call.
- **Binary frames** = audio: PCM16 little-endian, mono, 16 kHz, ~100 ms each.
- **Text frames** = JSON messages described below.

## Client → Server

| message | shape |
| --- | --- |
| start | `{ "type":"start", "sampleRate":16000, "encoding":"linear16", "mode":"live"\|"file" }` |
| stop | `{ "type":"stop" }` — ends the call; server replies with the report |
| swapSpeakers | `{ "type":"swapSpeakers" }` — flips which diarized channel is A vs B |

Audio is sent as binary frames after `start`.

## Server → Client

| message | shape |
| --- | --- |
| status | `{ "type":"status", "state":"connected"\|"listening"\|"analyzing"\|"stopped" }` |
| transcript | `{ "type":"transcript", "speaker":"A"\|"B", "text":string, "isFinal":bool, "tStart":sec, "tEnd":sec }` |
| emotion | `{ "type":"emotion", "speaker":"A"\|"B", "t":sec, "scores":{...7 emotions 0-100}, "trust":0-100, "dominance":0-100, "stress":0-100, "intent":string }` |
| insight | `{ "type":"insight", "t":sec, "severity":"info"\|"warn"\|"critical", "text":string }` |
| error | `{ "type":"error", "code":string, "message":string }` |
| report | `{ "type":"report", "report": PostCallReport }` |

The seven emotion keys: `positive, angry, stressed, neutral, disappointed,
suspicious, aggressive`.

### PostCallReport

```jsonc
{
  "summary": "string",
  "scores": {
    "sellerScore": 0-100,
    "customerEmotion": 0-100,
    "trustLevel": 0-100,
    "conversionProbability": 0-100
  },
  "sections": [ { "name": "opening", "summary": "string", "energy": "low|medium|high" } ],
  "events":   [ { "type": "interruption|silence|aggressive_reaction|excitement_spike", "t": sec, "note": "string" } ],
  "timeline": [ { "t": sec, "trust": 0-100, "stress": 0-100, "dominance": 0-100, "emotionDominant": "<emotion>" } ]
}
```

## Typical call lifecycle

```
client                         server
  | --- connect ------------->  |
  | <-- status:connected ------ |
  | --- start ---------------->  |
  | <-- status:listening ------ |
  | --- audio (binary) ...---->  |
  | <-- transcript (interim) -- |
  | <-- transcript (final) ---- |
  | <-- emotion (A), (B) ------ |   (debounced, off the transcript path)
  | <-- insight --------------- |
  |            ...              |
  | --- stop ----------------->  |
  | <-- status:analyzing ------ |
  | <-- report ---------------- |
  | <-- status:stopped -------- |
```

## Batch path (no socket)

`POST /analyze-file` (multipart, field `audio`) returns the same data in one
response: `{ transcript[], emotionFrames[], insights[], report }`. Used by the
app's "Import recording" flow and by the backend integration tests.
