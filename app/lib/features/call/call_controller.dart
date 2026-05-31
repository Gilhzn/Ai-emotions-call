import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/emotion_frame.dart';
import '../../core/models/insight.dart';
import '../../core/models/post_call_report.dart';
import '../../core/models/speaker.dart';
import '../../core/models/transcript_segment.dart';
import '../../config/backend_config.dart';
import '../../core/ws/call_client.dart';
import '../../core/ws/server_message.dart';
import '../../services/audio_capture.dart';
import '../../services/ondevice_analyzer.dart';
import '../../services/speech_service.dart';
import 'demo_session.dart';

/// Drives a live call: mic -> backend -> realtime events, accumulating the
/// transcript, per-speaker emotion state + history, insights, and the final
/// report. Exposed as a [ChangeNotifier] so the UI rebuilds on each event.
class CallController extends ChangeNotifier {
  CallController({CallClient? client, AudioCaptureService? capture})
      : _client = client ?? CallClient(),
        _capture = capture ?? AudioCaptureService();

  final CallClient _client;
  final AudioCaptureService _capture;

  StreamSubscription<ServerMessage>? _msgSub;
  StreamSubscription<dynamic>? _audioSub;
  Timer? _demoTimer;

  // On-device (mic + device speech recognition + heuristic) session state.
  SpeechService? _speech;
  final OnDeviceAnalyzer _analyzer = OnDeviceAnalyzer();
  DateTime? _sessionStart;
  int _speechTimeouts = 0;

  SessionState status = SessionState.connected;
  bool isActive = false;
  bool isDemo = false;
  bool isOnDevice = false;

  /// In on-device mode the mic can't tell speakers apart, so the user tags the
  /// currently-talking speaker; recognized speech is attributed to this.
  Speaker activeSpeaker = Speaker.a;
  String? error;

  final List<TranscriptSegment> finalSegments = [];
  final Map<Speaker, TranscriptSegment> interim = {};

  final Map<Speaker, EmotionFrame> latest = {};
  final List<EmotionFrame> historyA = [];
  final List<EmotionFrame> historyB = [];
  final List<Insight> insights = [];

  PostCallReport? report;

  /// Start a fully on-device simulated call — drives the live UI with scripted
  /// Hebrew dialogue and evolving emotions. No backend, network, or mic needed.
  Future<bool> startDemoCall() async {
    if (isActive) return true;
    _reset();
    isDemo = true;
    isActive = true;
    status = SessionState.listening;
    notifyListeners();

    final script = buildDemoScript();
    var i = 0;
    _demoTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (i >= script.length) {
        stopCall();
        return;
      }
      final ev = script[i++];
      _onMessage(TranscriptEvent(ev.segment));
      _onMessage(EmotionEvent(ev.frame));
      final insight = ev.insight;
      if (insight != null) _onMessage(InsightEvent(insight));
    });
    return true;
  }

  /// Start a fully on-device live analysis: the device's speech recognizer
  /// transcribes the mic (Hebrew) and a local heuristic estimates emotion —
  /// no backend, network, or API keys. Returns false if recognition is
  /// unavailable (e.g. no recognition service / permission denied).
  Future<bool> startOnDeviceCall() async {
    if (isActive) return true;
    _reset();
    isOnDevice = true;
    activeSpeaker = Speaker.a;
    _sessionStart = DateTime.now();
    _speech = SpeechService();

    final ok = await _speech!.init(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (!ok) {
      error =
          'זיהוי דיבור אינו זמין במכשיר. ודא ששירות זיהוי הדיבור (Google) פעיל ושניתנה הרשאת מיקרופון.';
      isOnDevice = false;
      notifyListeners();
      return false;
    }

    isActive = true;
    status = SessionState.listening;
    notifyListeners();
    await _listenAgain();
    return true;
  }

  double get _elapsed => _sessionStart == null
      ? 0
      : DateTime.now().difference(_sessionStart!).inMilliseconds / 1000.0;

  Future<void> _listenAgain() async {
    if (!isActive || _speech == null || _speech!.isListening) return;
    try {
      await _speech!.listen(onResult: _onSpeechResult);
    } catch (_) {
      // Ignore; the status listener will retry.
    }
  }

  void _onSpeechStatus(String status) {
    if (!isActive || !isOnDevice) return;
    // The recognizer stops after each utterance/silence; restart for a
    // continuous session.
    if (status == 'done' || status == 'notListening') {
      Future.delayed(const Duration(milliseconds: 300), _listenAgain);
    }
  }

  // Recognizer errors that are normal during a session (silence, brief glitches)
  // — we keep listening instead of surfacing them as a failure.
  static const Set<String> _transientSpeechErrors = {
    'error_speech_timeout',
    'error_no_match',
    'error_busy',
    'error_recognizer_busy',
    'error_client',
    'error_audio_error',
  };

  void _onSpeechError(String code) {
    if (!isActive || !isOnDevice) return;
    if (_transientSpeechErrors.contains(code)) {
      _speechTimeouts++;
      // Only nudge the user if nothing has been recognized yet — most often
      // because the mic is busy (e.g. an active phone call) or speech is too
      // quiet/far.
      error = (finalSegments.isEmpty && _speechTimeouts >= 2)
          ? 'עדיין לא זוהה דיבור. אם אתה בשיחה טלפונית — המיקרופון תפוס; '
              'נסה כשאינך בשיחה, ודבר קרוב וברור בעברית.'
          : null;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 400), _listenAgain);
      return;
    }
    if (code == 'error_language_unavailable' ||
        code == 'error_language_not_supported') {
      error = 'עברית אינה זמינה בזיהוי הדיבור במכשיר. התקן/הפעל חבילת שפה '
          'עברית בשירות הזיהוי של Google.';
    } else if (code == 'error_permission') {
      error = 'הרשאת מיקרופון נדחתה. אפשר אותה בהגדרות → אפליקציות → EmotionCall.';
    } else {
      error = 'זיהוי דיבור נכשל: $code';
    }
    notifyListeners();
  }

  void _onSpeechResult(String text, bool isFinal) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final t = _elapsed;
    _onMessage(TranscriptEvent(TranscriptSegment(
      speaker: activeSpeaker,
      text: clean,
      isFinal: isFinal,
      tStart: t,
      tEnd: t,
    )));
    if (isFinal) {
      _speechTimeouts = 0;
      if (error != null) error = null;
      final frame = _analyzer.analyze(speaker: activeSpeaker, text: clean, t: t);
      _onMessage(EmotionEvent(frame));
      final insight = _analyzer.insightFor(frame, clean, t);
      if (insight != null) _onMessage(InsightEvent(insight));
    }
  }

  /// Start a live microphone call. Returns false if mic permission was denied.
  Future<bool> startLiveCall() async {
    if (isActive) return true;
    _reset();

    if (!await _capture.hasPermission()) {
      error = 'הרשאת מיקרופון נדחתה';
      notifyListeners();
      return false;
    }

    try {
      await _client.connect();
    } catch (e) {
      error = 'לא ניתן להתחבר לשרת: $e';
      notifyListeners();
      return false;
    }

    _msgSub = _client.messages.listen(_onMessage);
    _client.start(mode: 'live');

    final audioStream = await _capture.start();
    _audioSub = audioStream.listen(_client.sendAudio);

    isActive = true;
    status = SessionState.listening;
    notifyListeners();
    return true;
  }

  Future<void> stopCall() async {
    if (!isActive) return;
    if (isDemo) {
      _demoTimer?.cancel();
      _demoTimer = null;
      isActive = false;
      status = SessionState.analyzing;
      notifyListeners();
      report = buildDemoReport([...historyA, ...historyB]);
      status = SessionState.stopped;
      notifyListeners();
      return;
    }
    if (isOnDevice) {
      isActive = false; // stops the listen-restart loop
      await _speech?.stop();
      status = SessionState.analyzing;
      notifyListeners();
      report = buildHeuristicReport(
        [...historyA, ...historyB],
        finalSegments,
      );
      status = SessionState.stopped;
      notifyListeners();
      return;
    }
    await _audioSub?.cancel();
    _audioSub = null;
    await _capture.stop();
    _client.stop(); // backend replies with the report + stopped status
    isActive = false;
    notifyListeners();
  }

  void swapSpeakers() {
    if (isOnDevice) {
      // No diarization on-device: flip which speaker new speech is tagged as.
      activeSpeaker = activeSpeaker == Speaker.a ? Speaker.b : Speaker.a;
      notifyListeners();
      return;
    }
    _client.swapSpeakers();
  }

  void _onMessage(ServerMessage msg) {
    switch (msg) {
      case StatusEvent(:final state):
        status = state;
      case TranscriptEvent(:final segment):
        if (segment.isFinal) {
          interim.remove(segment.speaker);
          finalSegments.add(segment);
        } else {
          interim[segment.speaker] = segment;
        }
      case EmotionEvent(:final frame):
        latest[frame.speaker] = frame;
        (frame.speaker == Speaker.a ? historyA : historyB).add(frame);
      case InsightEvent(:final insight):
        insights.add(insight);
      case ErrorEvent(:final message):
        error = message;
      case ReportEvent(:final report):
        this.report = report;
    }
    notifyListeners();
  }

  void _reset() {
    error = null;
    report = null;
    isDemo = false;
    isOnDevice = false;
    _speechTimeouts = 0;
    finalSegments.clear();
    interim.clear();
    latest.clear();
    historyA.clear();
    historyB.clear();
    insights.clear();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _speech?.cancel();
    _audioSub?.cancel();
    _msgSub?.cancel();
    _capture.dispose();
    _client.dispose();
    super.dispose();
  }
}

/// Provider for the live-call controller. Auto-disposed when the screen leaves.
/// Uses the runtime-configured backend URL so no rebuild is needed to retarget.
final callControllerProvider =
    ChangeNotifierProvider.autoDispose<CallController>((ref) {
  final base = ref.watch(backendUrlProvider);
  final controller =
      CallController(client: CallClient(url: BackendUrls(base).callWs));
  ref.onDispose(controller.dispose);
  return controller;
});
