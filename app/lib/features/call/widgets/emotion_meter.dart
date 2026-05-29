import 'package:flutter/material.dart';

import '../../../core/models/emotion_frame.dart';
import '../../../core/models/speaker.dart';
import '../../../core/theme/emotion_palette.dart';

/// Live per-speaker emotional read: dominant-emotion header, the seven emotion
/// bars, and trust/dominance/stress dimension gauges with the current intent.
class EmotionMeter extends StatelessWidget {
  const EmotionMeter({super.key, required this.speaker, required this.frame});

  final Speaker speaker;
  final EmotionFrame? frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    final scores = f?.scores;
    final dominant = scores?.dominant ?? 'neutral';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(EmotionPalette.emojiOf(dominant),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(speaker.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (scores == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Listening…',
                    style: TextStyle(color: Colors.white54)),
              )
            else ...[
              for (final e in scores.entries)
                _EmotionBar(label: e.key, value: e.value),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Dim(label: 'Trust', value: f!.trust),
                  _Dim(label: 'Power', value: f.dominance),
                  _Dim(label: 'Stress', value: f.stress),
                ],
              ),
              if (f.intent.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Intent: ${f.intent}',
                    style: const TextStyle(
                        color: Colors.white70, fontStyle: FontStyle.italic)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _EmotionBar extends StatelessWidget {
  const _EmotionBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                tween: Tween(begin: 0, end: value / 100),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor:
                      AlwaysStoppedAnimation(EmotionPalette.of(label)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 26,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _Dim extends StatelessWidget {
  const _Dim({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EmotionPalette.forScore(value))),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }
}
