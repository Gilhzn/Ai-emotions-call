import 'dart:convert';

import '../models/emotion_frame.dart';
import '../models/insight.dart';
import '../models/post_call_report.dart';
import '../models/transcript_segment.dart';

/// Parsed server -> client messages. Mirrors `ServerMessage` in
/// backend/src/contract.ts.
sealed class ServerMessage {
  const ServerMessage();

  /// Parse a raw JSON text frame. Returns null for unknown/garbage frames.
  static ServerMessage? parse(String raw) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      json = decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    switch (json['type']) {
      case 'status':
        return StatusEvent(sessionStateFromWire(json['state'] as String?));
      case 'transcript':
        return TranscriptEvent(TranscriptSegment.fromJson(json));
      case 'emotion':
        return EmotionEvent(EmotionFrame.fromJson(json));
      case 'insight':
        return InsightEvent(Insight.fromJson(json));
      case 'error':
        return ErrorEvent(
          (json['code'] as String?) ?? 'error',
          (json['message'] as String?) ?? '',
        );
      case 'report':
        final r = (json['report'] as Map?)?.cast<String, dynamic>();
        if (r == null) return null;
        return ReportEvent(PostCallReport.fromJson(r));
      default:
        return null;
    }
  }
}

enum SessionState { connected, listening, analyzing, stopped }

SessionState sessionStateFromWire(String? s) {
  switch (s) {
    case 'listening':
      return SessionState.listening;
    case 'analyzing':
      return SessionState.analyzing;
    case 'stopped':
      return SessionState.stopped;
    default:
      return SessionState.connected;
  }
}

class StatusEvent extends ServerMessage {
  const StatusEvent(this.state);
  final SessionState state;
}

class TranscriptEvent extends ServerMessage {
  const TranscriptEvent(this.segment);
  final TranscriptSegment segment;
}

class EmotionEvent extends ServerMessage {
  const EmotionEvent(this.frame);
  final EmotionFrame frame;
}

class InsightEvent extends ServerMessage {
  const InsightEvent(this.insight);
  final Insight insight;
}

class ErrorEvent extends ServerMessage {
  const ErrorEvent(this.code, this.message);
  final String code;
  final String message;
}

class ReportEvent extends ServerMessage {
  const ReportEvent(this.report);
  final PostCallReport report;
}
