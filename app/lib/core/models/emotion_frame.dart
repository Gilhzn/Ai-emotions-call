import 'emotion_scores.dart';
import 'speaker.dart';

/// Mirrors `EmotionMessage` in backend/src/contract.ts.
class EmotionFrame {
  const EmotionFrame({
    required this.speaker,
    required this.t,
    required this.scores,
    required this.trust,
    required this.dominance,
    required this.stress,
    required this.intent,
  });

  final Speaker speaker;
  final double t;
  final EmotionScores scores;
  final int trust;
  final int dominance;
  final int stress;
  final String intent;

  factory EmotionFrame.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.round() ?? 0;
    return EmotionFrame(
      speaker: Speaker.fromWire(json['speaker'] as String?),
      t: (json['t'] as num?)?.toDouble() ?? 0,
      scores: EmotionScores.fromJson(
        (json['scores'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      trust: v('trust'),
      dominance: v('dominance'),
      stress: v('stress'),
      intent: (json['intent'] as String?) ?? '',
    );
  }
}
