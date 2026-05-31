import '../../core/models/emotion_frame.dart';
import '../../core/models/emotion_scores.dart';
import '../../core/models/insight.dart';
import '../../core/models/post_call_report.dart';
import '../../core/models/speaker.dart';
import '../../core/models/transcript_segment.dart';

/// One scripted beat of the on-device demo: a transcript line, the matching
/// emotion read for that speaker, and an optional coaching insight.
class DemoEvent {
  const DemoEvent(this.segment, this.frame, [this.insight]);
  final TranscriptSegment segment;
  final EmotionFrame frame;
  final Insight? insight;
}

EmotionScores _scores({
  int positive = 0,
  int angry = 0,
  int stressed = 0,
  int neutral = 0,
  int disappointed = 0,
  int suspicious = 0,
  int aggressive = 0,
}) =>
    EmotionScores(
      positive: positive,
      angry: angry,
      stressed: stressed,
      neutral: neutral,
      disappointed: disappointed,
      suspicious: suspicious,
      aggressive: aggressive,
    );

DemoEvent _beat({
  required Speaker speaker,
  required double t,
  required String text,
  required EmotionScores scores,
  required int trust,
  required int dominance,
  required int stress,
  required String intent,
  Insight? insight,
}) =>
    DemoEvent(
      TranscriptSegment(
        speaker: speaker,
        text: text,
        isFinal: true,
        tStart: t,
        tEnd: t + 4,
      ),
      EmotionFrame(
        speaker: speaker,
        t: t,
        scores: scores,
        trust: trust,
        dominance: dominance,
        stress: stress,
        intent: intent,
      ),
      insight,
    );

/// A fully on-device, simulated sales call in Hebrew. Drives the live UI with
/// realistic, evolving emotion data — no backend, no network, no API keys.
List<DemoEvent> buildDemoScript() => [
      _beat(
        speaker: Speaker.a,
        t: 4,
        text: 'שלום, מדבר דניאל מחברת אומגה. תפסתי אותך בזמן טוב?',
        scores: _scores(positive: 45, neutral: 50),
        trust: 55,
        dominance: 60,
        stress: 20,
        intent: 'פותח שיחה',
      ),
      _beat(
        speaker: Speaker.b,
        t: 11,
        text: 'כן, אבל יש לי רק כמה דקות.',
        scores: _scores(neutral: 60, suspicious: 35, stressed: 25),
        trust: 40,
        dominance: 45,
        stress: 35,
        intent: 'מסויג',
      ),
      _beat(
        speaker: Speaker.a,
        t: 18,
        text: 'מצוין, אהיה קצר. רציתי להראות לך איך לחסוך זמן בתהליך המכירה.',
        scores: _scores(positive: 55, neutral: 40),
        trust: 60,
        dominance: 62,
        stress: 18,
        intent: 'מציג ערך',
        insight: const Insight(
          t: 18,
          severity: InsightSeverity.info,
          text: 'טון פתיחה טוב — שמור על קצב רגוע ותן ללקוח מקום.',
        ),
      ),
      _beat(
        speaker: Speaker.b,
        t: 26,
        text: 'תשמע, כבר ניסיתי כלים כאלה וזה פשוט לא עבד.',
        scores: _scores(disappointed: 55, suspicious: 40, stressed: 30),
        trust: 35,
        dominance: 50,
        stress: 45,
        intent: 'ספקן',
        insight: const Insight(
          t: 26,
          severity: InsightSeverity.warn,
          text: 'הלקוח מביע אכזבה מניסיון קודם — הכר בכך לפני שתמשיך.',
        ),
      ),
      _beat(
        speaker: Speaker.a,
        t: 34,
        text: 'אני מבין לגמרי. הרבה כלים מבטיחים ולא מספקים. מה בדיוק לא עבד אצלך?',
        scores: _scores(positive: 50, neutral: 45),
        trust: 68,
        dominance: 55,
        stress: 20,
        intent: 'מברר צורך',
        insight: const Insight(
          t: 34,
          severity: InsightSeverity.info,
          text: 'יפה — שאלת שאלת המשך במקום להתגונן.',
        ),
      ),
      _beat(
        speaker: Speaker.b,
        t: 42,
        text: 'בעיקר שזה לקח יותר מדי זמן להטמיע אצלנו.',
        scores: _scores(neutral: 55, disappointed: 35),
        trust: 45,
        dominance: 48,
        stress: 38,
        intent: 'חושף כאב',
      ),
      _beat(
        speaker: Speaker.a,
        t: 50,
        text: 'זה בדיוק מה שפתרנו — ההטמעה אצלנו לוקחת יום, לא חודש.',
        scores: _scores(positive: 70, neutral: 25),
        trust: 72,
        dominance: 65,
        stress: 15,
        intent: 'מתגבר על התנגדות',
      ),
      _beat(
        speaker: Speaker.b,
        t: 58,
        text: 'אוקיי, זה נשמע מעניין. כמה זה עולה?',
        scores: _scores(positive: 50, neutral: 40, suspicious: 15),
        trust: 55,
        dominance: 45,
        stress: 30,
        intent: 'מתעניין במחיר',
        insight: const Insight(
          t: 58,
          severity: InsightSeverity.info,
          text: 'אות קנייה — הלקוח שואל על מחיר. המשך בביטחון.',
        ),
      ),
      _beat(
        speaker: Speaker.a,
        t: 66,
        text: 'תלוי בגודל הצוות, אבל רוב הלקוחות מתחילים ב‑199 לחודש.',
        scores: _scores(positive: 60, neutral: 35),
        trust: 70,
        dominance: 60,
        stress: 22,
        intent: 'מציג מחיר',
      ),
      _beat(
        speaker: Speaker.b,
        t: 74,
        text: 'זה קצת יקר לי לעומת מה שיש לי היום.',
        scores: _scores(disappointed: 45, stressed: 45, neutral: 25),
        trust: 48,
        dominance: 52,
        stress: 50,
        intent: 'התנגדות מחיר',
        insight: const Insight(
          t: 74,
          severity: InsightSeverity.warn,
          text: 'התנגדות מחיר — התמקד בערך וב‑ROI, אל תמהר לתת הנחה.',
        ),
      ),
      _beat(
        speaker: Speaker.a,
        t: 82,
        text: 'הבנתי. בוא נסתכל על מה שאתה חוסך — רוב הלקוחות מחזירים את העלות תוך חודש.',
        scores: _scores(positive: 65, neutral: 30),
        trust: 74,
        dominance: 63,
        stress: 20,
        intent: 'ממסגר ROI',
      ),
      _beat(
        speaker: Speaker.b,
        t: 90,
        text: 'טיעון הגיוני. אפשר לקבל תקופת ניסיון?',
        scores: _scores(positive: 65, neutral: 30),
        trust: 62,
        dominance: 44,
        stress: 25,
        intent: 'מתקדם לסגירה',
        insight: const Insight(
          t: 90,
          severity: InsightSeverity.info,
          text: 'הלקוח מבקש להתקדם — הצע ניסיון והגדר צעד הבא ברור.',
        ),
      ),
      _beat(
        speaker: Speaker.a,
        t: 98,
        text: 'בהחלט, 14 יום ניסיון חינם. אשלח לך לינק עכשיו ונקבע שיחה קצרה בשבוע הבא?',
        scores: _scores(positive: 78, neutral: 18),
        trust: 78,
        dominance: 66,
        stress: 16,
        intent: 'סוגר צעד הבא',
      ),
      _beat(
        speaker: Speaker.b,
        t: 106,
        text: 'מעולה, תשלח. תודה דניאל.',
        scores: _scores(positive: 80, neutral: 18),
        trust: 70,
        dominance: 42,
        stress: 18,
        intent: 'מסכים',
        insight: const Insight(
          t: 106,
          severity: InsightSeverity.info,
          text: 'נסגר צעד הבא בהצלחה 🎉 שלח את הלינק מיד וסכם בכתב.',
        ),
      ),
    ];

/// Build the post-call report for the demo from the accumulated frames.
PostCallReport buildDemoReport(List<EmotionFrame> frames) {
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

  return PostCallReport(
    summary:
        'שיחת מכירה בת כשתי דקות. הלקוח פתח במסויגות ובאכזבה מניסיון קודם, '
        'אך הנציג הגיב באמפתיה, בירר את הכאב (זמן הטמעה) ומיסגר את הערך וה‑ROI. '
        'לאחר התנגדות מחיר, הנציג הציע תקופת ניסיון וסגר צעד הבא. מגמת האמון '
        'עלתה לאורך השיחה והסתיימה בנימה חיובית — סיכוי סגירה סביר.',
    scores: const ReportScores(
      sellerScore: 82,
      customerEmotion: 68,
      trustLevel: 70,
      conversionProbability: 64,
    ),
    sections: const [
      ReportSection(
        name: 'פתיחה',
        summary: 'פתיחה קצרה ועניינית; הלקוח מסויג אך זמין להקשיב.',
        energy: 'medium',
      ),
      ReportSection(
        name: 'בירור צורך',
        summary: 'הנציג זיהה אכזבה מניסיון קודם ובירר את הכאב — זמן הטמעה.',
        energy: 'high',
      ),
      ReportSection(
        name: 'התנגדות מחיר',
        summary: 'ההתנגדות טופלה במיסגור ROI במקום מתן הנחה מיידית.',
        energy: 'medium',
      ),
      ReportSection(
        name: 'סגירה',
        summary: 'הוצעה תקופת ניסיון ונסגר צעד הבא לשבוע הבא.',
        energy: 'high',
      ),
    ],
    events: const [
      CallEvent(type: 'אות קנייה', t: 58, note: 'הלקוח שאל על מחיר'),
      CallEvent(type: 'התנגדות', t: 74, note: 'התנגדות מחיר'),
      CallEvent(type: 'סגירה', t: 98, note: 'הוצעה תקופת ניסיון וצעד הבא'),
    ],
    timeline: timeline,
  );
}
