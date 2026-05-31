import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/post_call_report.dart';
import '../../core/theme/emotion_palette.dart';

/// Post-call analysis: headline scores, AI summary, section-by-section
/// breakdown, detected events, and the full emotion timeline.
class PostCallScreen extends StatelessWidget {
  const PostCallScreen({super.key, required this.report});

  final PostCallReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.scores;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ניתוח השיחה'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _ScoreGauge(label: 'ציון המוכר', value: s.sellerScore),
              _ScoreGauge(label: 'רגש הלקוח', value: s.customerEmotion),
              _ScoreGauge(label: 'רמת אמון', value: s.trustLevel),
              _ScoreGauge(
                  label: 'סיכוי סגירה', value: s.conversionProbability, suffix: '%'),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'סיכום',
            child: Text(report.summary,
                style: const TextStyle(height: 1.4)),
          ),
          if (report.sections.isNotEmpty)
            _SectionCard(
              title: 'לפי שלבים',
              child: Column(
                children: [
                  for (final sec in report.sections)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _EnergyDot(energy: sec.energy),
                      title: Text(sec.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(sec.summary),
                    ),
                ],
              ),
            ),
          if (report.events.isNotEmpty)
            _SectionCard(
              title: 'אירועים שזוהו',
              child: Column(
                children: [
                  for (final e in report.events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text('${e.t.round()}s',
                          style: const TextStyle(color: Colors.white54)),
                      title: Text(e.type.replaceAll('_', ' ')),
                      subtitle: Text(e.note),
                    ),
                ],
              ),
            ),
          if (report.timeline.length >= 2)
            _SectionCard(
              title: 'ציר הרגשות',
              child: SizedBox(
                  height: 200, child: _ReportTimeline(points: report.timeline)),
            ),
        ],
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.label, required this.value, this.suffix = ''});
  final String label;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final color = EmotionPalette.forScore(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('$value$suffix',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _EnergyDot extends StatelessWidget {
  const _EnergyDot({required this.energy});
  final String energy;

  @override
  Widget build(BuildContext context) {
    final color = switch (energy) {
      'high' => const Color(0xFF2ECC71),
      'low' => const Color(0xFFE74C3C),
      _ => const Color(0xFFE67E22),
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ReportTimeline extends StatelessWidget {
  const _ReportTimeline({required this.points});
  final List<TimelinePoint> points;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> series(int Function(TimelinePoint) sel) =>
        [for (final p in points) FlSpot(p.t, sel(p).toDouble())];
    LineChartBarData bar(List<FlSpot> spots, Color c) => LineChartBarData(
          spots: spots,
          isCurved: true,
          color: c,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 20)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          bar(series((p) => p.trust), const Color(0xFF2ECC71)),
          bar(series((p) => p.stress), const Color(0xFFE67E22)),
          bar(series((p) => p.dominance), const Color(0xFF5B8DEF)),
        ],
      ),
    );
  }
}
