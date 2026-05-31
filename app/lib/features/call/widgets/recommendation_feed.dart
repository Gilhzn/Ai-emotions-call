import 'package:flutter/material.dart';

import '../../../core/models/insight.dart';

/// Live AI coaching feed — newest recommendation on top, colored by severity.
class RecommendationFeed extends StatelessWidget {
  const RecommendationFeed({super.key, required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.lightbulb_outline, color: Colors.white38),
          title: Text('המלצות AI יופיעו כאן',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }
    final recent = insights.reversed.take(4).toList();
    return Column(
      children: [
        for (final i in recent)
          Card(
            child: ListTile(
              dense: true,
              leading: Icon(_icon(i.severity), color: _color(i.severity)),
              title: Text(i.text),
              trailing: Text('${i.t.round()} שנ׳',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ),
      ],
    );
  }

  IconData _icon(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.critical:
        return Icons.warning_amber_rounded;
      case InsightSeverity.warn:
        return Icons.info_outline;
      case InsightSeverity.info:
        return Icons.lightbulb_outline;
    }
  }

  Color _color(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.critical:
        return const Color(0xFFE74C3C);
      case InsightSeverity.warn:
        return const Color(0xFFE67E22);
      case InsightSeverity.info:
        return const Color(0xFF5B8DEF);
    }
  }
}
