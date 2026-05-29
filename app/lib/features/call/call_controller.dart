import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/emotion_frame.dart';
import '../../core/models/insight.dart';
import '../../core/models/post_call_report.dart';
import '../../core/models/speaker.dart';
import '../../core/models/transcript_segment.dart';
import '../../core/ws/call_client.dart';
import '../../core/ws/server_message.dart';
import '../../services/audio_capture.dart';

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

  SessionState status = SessionState.connected;
  bool isActive = false;
  String? error;

  final List<TranscriptSegment> finalSegments = [];
  final Map<Speaker, TranscriptSegment> interim = {};

  final Map<Speaker, EmotionFrame> latest = {};
  final List<EmotionFrame> historyA = [];
  final List<EmotionFrame> historyB = [];
  final List<Insight> insights = [];

  PostCallReport? report;

  /// Start a live microphone call. Returns false if mic permission was denied.
  Future<bool> startLiveCall() async {
    if (isActive) return true;
    _reset();

    if (!await _capture.hasPermission()) {
      error = 'Microphone permission denied';
      notifyListeners();
      return false;
    }

    try {
      await _client.connect();
    } catch (e) {
      error = 'Could not reach backend: $e';
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
    _audioSub?.cancel();
    _msgSub?.cancel();
    _capture.dispose();
    _client.dispose();
    super.dispose();
  }
}

/// Provider for the live-call controller. Auto-disposed when the screen leaves.
final callControllerProvider =
    ChangeNotifierProvider.autoDispose<CallController>((ref) {
  final controller = CallController();
  ref.onDispose(controller.dispose);
  return controller;
});
