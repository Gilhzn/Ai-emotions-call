// Mirrors the post-call report types in backend/src/contract.ts.

class ReportScores {
  const ReportScores({
    required this.sellerScore,
    required this.customerEmotion,
    required this.trustLevel,
    required this.conversionProbability,
  });

  final int sellerScore;
  final int customerEmotion;
  final int trustLevel;
  final int conversionProbability;

  factory ReportScores.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.round() ?? 0;
    return ReportScores(
      sellerScore: v('sellerScore'),
      customerEmotion: v('customerEmotion'),
      trustLevel: v('trustLevel'),
      conversionProbability: v('conversionProbability'),
    );
  }
}

class ReportSection {
  const ReportSection({
    required this.name,
    required this.summary,
    required this.energy,
  });

  final String name;
  final String summary;
  final String energy; // low | medium | high

  factory ReportSection.fromJson(Map<String, dynamic> json) {
    return ReportSection(
      name: (json['name'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      energy: (json['energy'] as String?) ?? 'medium',
    );
  }
}

class CallEvent {
  const CallEvent({required this.type, required this.t, required this.note});

  final String type;
  final double t;
  final String note;

  factory CallEvent.fromJson(Map<String, dynamic> json) {
    return CallEvent(
      type: (json['type'] as String?) ?? '',
      t: (json['t'] as num?)?.toDouble() ?? 0,
      note: (json['note'] as String?) ?? '',
    );
  }
}

class TimelinePoint {
  const TimelinePoint({
    required this.t,
    required this.trust,
    required this.stress,
    required this.dominance,
    required this.emotionDominant,
  });

  final double t;
  final int trust;
  final int stress;
  final int dominance;
  final String emotionDominant;

  factory TimelinePoint.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.round() ?? 0;
    return TimelinePoint(
      t: (json['t'] as num?)?.toDouble() ?? 0,
      trust: v('trust'),
      stress: v('stress'),
      dominance: v('dominance'),
      emotionDominant: (json['emotionDominant'] as String?) ?? 'neutral',
    );
  }
}

class PostCallReport {
  const PostCallReport({
    required this.summary,
    required this.scores,
    required this.sections,
    required this.events,
    required this.timeline,
  });

  final String summary;
  final ReportScores scores;
  final List<ReportSection> sections;
  final List<CallEvent> events;
  final List<TimelinePoint> timeline;

  factory PostCallReport.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) {
      final raw = json[key] as List?;
      if (raw == null) return <T>[];
      return raw
          .whereType<Map>()
          .map((e) => f(e.cast<String, dynamic>()))
          .toList();
    }

    return PostCallReport(
      summary: (json['summary'] as String?) ?? '',
      scores: ReportScores.fromJson(
        (json['scores'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      sections: list('sections', ReportSection.fromJson),
      events: list('events', CallEvent.fromJson),
      timeline: list('timeline', TimelinePoint.fromJson),
    );
  }
}
