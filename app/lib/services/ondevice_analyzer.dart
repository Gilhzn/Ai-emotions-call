import '../core/models/emotion_frame.dart';
import '../core/models/emotion_scores.dart';
import '../core/models/insight.dart';
import '../core/models/post_call_report.dart';
import '../core/models/speaker.dart';
import '../core/models/transcript_segment.dart';

/// A lightweight, fully on-device emotion/intent estimator. It scores a
/// transcript snippet against small Hebrew + English keyword lexicons — no
/// model, no network. Deterministic and unit-testable. This is a heuristic
/// (not an LLM), intended for the on-device live mode.
class OnDeviceAnalyzer {
  static const Map<String, List<String>> _lexicon = {
    'positive': [
      'תודה', 'מעולה', 'מצוין', 'נהדר', 'אהבתי', 'מעניין', 'שמח', 'סבבה',
      'כיף', 'נפלא', 'יופי', 'מושלם', 'בהחלט', 'אשמח', 'טוב', 'נשמע טוב',
      'great', 'good', 'thanks', 'perfect', 'love', 'nice', 'yes',
    ],
    'angry': [
      'נמאס', 'תפסיק', 'מספיק', 'אסור', 'שטות', 'כועס', 'עצבני', 'בושה',
      'חצוף', 'לא מקובל', 'נורא', 'angry', 'stop', 'ridiculous',
    ],
    'stressed': [
      'לחוץ', 'דחוף', 'מהר', 'בעיה', 'דאגה', 'חושש', 'פחד', 'קשה',
      'מסובך', 'אין זמן', 'stress', 'urgent', 'problem', 'worried',
    ],
    'disappointed': [
      'מאוכזב', 'חבל', 'ציפיתי', 'לא עבד', 'אכזבה', 'פספוס', 'לצערי',
      'disappointed', 'expected', 'let down',
    ],
    'suspicious': [
      'באמת', 'בטוח', 'ספק', 'לא יודע', 'חשש', 'יקר', 'מחיר', 'עולה',
      'כמה זה', 'תקציב', 'really', 'sure', 'expensive', 'price', 'cost',
    ],
    'aggressive': [
      'חייב', 'תקשיב', 'אמרתי', 'לא מעניין', 'עכשיו מיד', 'must', 'listen',
    ],
  };

  static final RegExp _splitter = RegExp(r'[^֐-׿a-zA-Z]+');
  static const List<String> _prefixes = ['ו', 'ה', 'ב', 'ל', 'כ', 'ש'];

  /// Word tokens of [text], plus prefix-stripped variants for common Hebrew
  /// conjunctions/prepositions (so "ומעניין" also matches "מעניין"). The "מ"
  /// prefix is intentionally NOT stripped, to avoid e.g. "מעולה" → "עולה".
  Set<String> _tokenize(String text) {
    final out = <String>{};
    for (final tok in text.split(_splitter)) {
      if (tok.isEmpty) continue;
      out.add(tok);
      if (tok.length > 2) {
        for (final p in _prefixes) {
          if (tok.startsWith(p)) {
            out.add(tok.substring(1));
            break;
          }
        }
      }
    }
    return out;
  }

  /// Single words match on word boundaries (token equality); multi-word phrases
  /// fall back to a substring check.
  bool _has(Set<String> tokens, String text, String word) =>
      word.contains(' ') ? text.contains(word) : tokens.contains(word);

  int _hits(Set<String> tokens, String text, String category) {
    var n = 0;
    for (final w in _lexicon[category]!) {
      if (_has(tokens, text, w)) n++;
    }
    return n;
  }

  int _scale(int hits, {int base = 0, int per = 28}) {
    final v = base + hits * per;
    return v.clamp(0, 100);
  }

  /// Produce an emotion read for [text] attributed to [speaker] at time [t].
  EmotionFrame analyze({
    required Speaker speaker,
    required String text,
    required double t,
  }) {
    final lower = text.toLowerCase();
    final tokens = _tokenize(lower);
    final pos = _hits(tokens, lower, 'positive');
    final ang = _hits(tokens, lower, 'angry');
    final str = _hits(tokens, lower, 'stressed');
    final dis = _hits(tokens, lower, 'disappointed');
    final sus = _hits(tokens, lower, 'suspicious');
    final agg = _hits(tokens, lower, 'aggressive');
    final signals = pos + ang + str + dis + sus + agg;
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    final scores = EmotionScores(
      positive: _scale(pos, base: pos > 0 ? 30 : 0),
      angry: _scale(ang),
      stressed: _scale(str),
      neutral: (signals == 0 ? 70 : (40 - signals * 8)).clamp(10, 80),
      disappointed: _scale(dis),
      suspicious: _scale(sus),
      aggressive: _scale(agg),
    );

    final trust = (55 + pos * 10 - sus * 8 - ang * 12 - dis * 6).clamp(0, 100);
    final stress = (20 + str * 16 + ang * 14 + dis * 8).clamp(0, 100);
    final dominance =
        (40 + agg * 14 + (words ~/ 6) * 6 + (text.contains('!') ? 10 : 0))
            .clamp(0, 100);

    return EmotionFrame(
      speaker: speaker,
      t: t,
      scores: scores,
      trust: trust,
      dominance: dominance,
      stress: stress,
      intent: _intent(tokens, lower, pos, ang, dis, sus, agg),
    );
  }

  String _intent(Set<String> tokens, String lower, int pos, int ang, int dis,
      int sus, int agg) {
    if (_has(tokens, lower, 'מחיר') ||
        _has(tokens, lower, 'יקר') ||
        _has(tokens, lower, 'עולה') ||
        lower.contains('כמה זה') ||
        _has(tokens, lower, 'price') ||
        _has(tokens, lower, 'cost')) {
      return 'דיון במחיר';
    }
    if (lower.contains('?') ||
        _has(tokens, lower, 'כמה') ||
        _has(tokens, lower, 'האם')) {
      return 'שואל שאלה';
    }
    if (ang > 0 || agg > 0) return 'מתנגד';
    if (dis > 0) return 'מביע אכזבה';
    if (sus > 0) return 'מסויג';
    if (pos > 0) return 'מביע עניין';
    return 'משוחח';
  }

  /// Optionally surface a coaching insight for a strong signal.
  Insight? insightFor(EmotionFrame f, String text, double t) {
    if (f.stress >= 60) {
      return Insight(
        t: t,
        severity: InsightSeverity.warn,
        text: 'רמת לחץ גבוהה זוהתה — האט את הקצב והכר ברגש של הצד השני.',
      );
    }
    if (f.intent == 'דיון במחיר') {
      return Insight(
        t: t,
        severity: InsightSeverity.info,
        text: 'עלה נושא המחיר — מסגר ערך ו‑ROI לפני מתן הנחה.',
      );
    }
    if (f.scores.dominant == 'positive' && f.trust >= 70) {
      return Insight(
        t: t,
        severity: InsightSeverity.info,
        text: 'אות חיובי וגבוה באמון — זה רגע טוב להציע צעד הבא.',
      );
    }
    return null;
  }
}

/// Build a post-call report from an on-device session's accumulated frames.
PostCallReport buildHeuristicReport(
  List<EmotionFrame> frames,
  List<TranscriptSegment> segments,
) {
  final sorted = [...frames]..sort((a, b) => a.t.compareTo(b.t));
  final timeline = [
    for (final f in sorted)
      TimelinePoint(
        t: f.t,
        trust: f.trust,
        stress: f.stress,
        dominance: f.dominance,
        emotionDominant: f.scores.dominant,
      ),
  ];

  int avg(int Function(EmotionFrame) sel) => sorted.isEmpty
      ? 0
      : (sorted.map(sel).reduce((a, b) => a + b) / sorted.length).round();

  final avgTrust = avg((f) => f.trust);
  final avgStress = avg((f) => f.stress);
  final avgPositive = avg((f) => f.scores.positive);
  final trustTrend = sorted.length >= 2
      ? sorted.last.trust - sorted.first.trust
      : 0;
  final conversion = (avgTrust + avgPositive - avgStress).clamp(0, 100);
  final sellerScore = ((avgTrust + (100 - avgStress)) / 2).round().clamp(0, 100);

  final trendText = trustTrend > 5
      ? 'מגמת האמון עלתה לאורך השיחה'
      : trustTrend < -5
          ? 'מגמת האמון ירדה לאורך השיחה'
          : 'מגמת האמון נשארה יציבה';

  return PostCallReport(
    summary: segments.isEmpty
        ? 'לא זוהה דיבור. ודא שהמיקרופון פעיל ושהדיבור בעברית ברור.'
        : 'נותחו ${segments.length} קטעי דיבור על המכשיר. $trendText. '
            'רמת אמון ממוצעת $avgTrust, לחץ ממוצע $avgStress. '
            'הניתוח מבוסס היוריסטיקה מקומית (ללא שרת).',
    scores: ReportScores(
      sellerScore: sellerScore,
      customerEmotion: avgPositive,
      trustLevel: avgTrust,
      conversionProbability: conversion,
    ),
    sections: [
      ReportSection(
        name: 'מהלך השיחה',
        summary: '$trendText. נמדדו ${frames.length} קריאות רגש.',
        energy: avgStress > 55 ? 'low' : (avgPositive > 50 ? 'high' : 'medium'),
      ),
    ],
    events: const [],
    timeline: timeline,
  );
}
