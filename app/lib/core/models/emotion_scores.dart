/// Mirrors `EmotionScores` in backend/src/contract.ts. Each value is 0..100.
class EmotionScores {
  const EmotionScores({
    required this.positive,
    required this.angry,
    required this.stressed,
    required this.neutral,
    required this.disappointed,
    required this.suspicious,
    required this.aggressive,
  });

  final int positive;
  final int angry;
  final int stressed;
  final int neutral;
  final int disappointed;
  final int suspicious;
  final int aggressive;

  static const List<String> keys = [
    'positive',
    'angry',
    'stressed',
    'neutral',
    'disappointed',
    'suspicious',
    'aggressive',
  ];

  /// Ordered (label, value) pairs for rendering meters/charts.
  List<MapEntry<String, int>> get entries => [
        MapEntry('positive', positive),
        MapEntry('angry', angry),
        MapEntry('stressed', stressed),
        MapEntry('neutral', neutral),
        MapEntry('disappointed', disappointed),
        MapEntry('suspicious', suspicious),
        MapEntry('aggressive', aggressive),
      ];

  /// The highest-scoring emotion label.
  String get dominant {
    var best = entries.first;
    for (final e in entries) {
      if (e.value > best.value) best = e;
    }
    return best.key;
  }

  static const EmotionScores zero = EmotionScores(
    positive: 0,
    angry: 0,
    stressed: 0,
    neutral: 0,
    disappointed: 0,
    suspicious: 0,
    aggressive: 0,
  );

  factory EmotionScores.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.round() ?? 0;
    return EmotionScores(
      positive: v('positive'),
      angry: v('angry'),
      stressed: v('stressed'),
      neutral: v('neutral'),
      disappointed: v('disappointed'),
      suspicious: v('suspicious'),
      aggressive: v('aggressive'),
    );
  }
}
