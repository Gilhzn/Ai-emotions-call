import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/emotion_frame.dart';

/// Continuous realtime graph of trust / stress / dominance across the call.
/// Frames from both speakers are merged and ordered by time to show the overall
/// emotional arc of the conversation.
class EmotionTimeline extends StatelessWidget {
  const EmotionTimeline({super.key, required this.frames});

  final List<EmotionFrame> frames;

  static const Color trustColor = Color(0xFF2ECC71);
  static const Color stressColor = Color(0xFFE67E22);
  static const Color powerColor = Color(0xFF5B8DEF);

  @override
  Widget build(BuildContext context) {
    if (frames.length < 2) {
      return const Center(
        child: Text('Emotion timeline builds as the call progresses…',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final sorted = [...frames]..sort((a, b) => a.t.compareTo(b.t));
    List<FlSpot> series(int Function(EmotionFrame) sel) =>
        [for (final f in sorted) FlSpot(f.t, sel(f).toDouble())];

    LineChartBarData bar(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        );

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: _Legend(),
        ),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 20),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                bar(series((f) => f.trust), trustColor),
                bar(series((f) => f.stress), stressColor),
                bar(series((f) => f.dominance), powerColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _Dot(color: EmotionTimeline.trustColor, label: 'Trust'),
        SizedBox(width: 12),
        _Dot(color: EmotionTimeline.stressColor, label: 'Stress'),
        SizedBox(width: 12),
        _Dot(color: EmotionTimeline.powerColor, label: 'Dominance'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
