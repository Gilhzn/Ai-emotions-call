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

  SessionState status = SessionState.connected;
  bool isActive = false;
  bool isDemo = false;
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
    await _audioSub?.cancel();
    _audioSub = null;
    await _capture.stop();
    _client.stop(); // backend replies with the report + stopped status
    isActive = false;
    notifyListeners();
  }

  void swapSpeakers() {
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
