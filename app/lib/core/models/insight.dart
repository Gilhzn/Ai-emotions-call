/// Severity of a realtime coaching insight (mirrors backend InsightSeverity).
enum InsightSeverity {
  info,
  warn,
  critical;

  static InsightSeverity fromWire(String? s) {
    switch (s) {
      case 'critical':
        return InsightSeverity.critical;
      case 'warn':
        return InsightSeverity.warn;
      default:
        return InsightSeverity.info;
    }
  }
}

/// Mirrors `InsightMessage` in backend/src/contract.ts.
class Insight {
  const Insight({required this.t, required this.severity, required this.text});

  final double t;
  final InsightSeverity severity;
  final String text;

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      t: (json['t'] as num?)?.toDouble() ?? 0,
      severity: InsightSeverity.fromWire(json['severity'] as String?),
      text: (json['text'] as String?) ?? '',
    );
  }
}
