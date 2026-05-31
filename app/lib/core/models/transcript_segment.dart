import 'speaker.dart';

/// Mirrors `TranscriptMessage` in backend/src/contract.ts.
class TranscriptSegment {
  const TranscriptSegment({
    required this.speaker,
    required this.text,
    required this.isFinal,
    required this.tStart,
    required this.tEnd,
  });

  final Speaker speaker;
  final String text;
  final bool isFinal;
  final double tStart;
  final double tEnd;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      speaker: Speaker.fromWire(json['speaker'] as String?),
      text: (json['text'] as String?) ?? '',
      isFinal: (json['isFinal'] as bool?) ?? false,
      tStart: (json['tStart'] as num?)?.toDouble() ?? 0,
      tEnd: (json['tEnd'] as num?)?.toDouble() ?? 0,
    );
  }
}
