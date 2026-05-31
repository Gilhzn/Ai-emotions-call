import 'package:emotioncall/core/models/speaker.dart';
import 'package:emotioncall/services/ondevice_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final analyzer = OnDeviceAnalyzer();

  test('neutral text yields high neutral, mid trust, low stress', () {
    final f = analyzer.analyze(speaker: Speaker.a, text: 'אז נמשיך הלאה', t: 1);
    expect(f.scores.dominant, 'neutral');
    expect(f.stress, lessThan(40));
    expect(f.scores.positive, 0);
  });

  test('positive words raise trust and positive score', () {
    final f = analyzer.analyze(
        speaker: Speaker.b, text: 'תודה, נשמע מעולה ומעניין', t: 2);
    expect(f.scores.positive, greaterThan(40));
    expect(f.trust, greaterThan(60));
    expect(f.intent, 'מביע עניין');
  });

  test('price words set the price intent and lower trust', () {
    final f = analyzer.analyze(
        speaker: Speaker.b, text: 'זה נשמע יקר, כמה זה עולה?', t: 3);
    expect(f.intent, 'דיון במחיר');
    expect(f.scores.suspicious, greaterThan(0));
  });

  test('stress + anger words raise stress', () {
    final f = analyzer.analyze(
        speaker: Speaker.b, text: 'נמאס לי, יש בעיה דחופה וזה קשה', t: 4);
    expect(f.stress, greaterThan(50));
    expect(['מתנגד', 'דיון במחיר', 'שואל שאלה'], contains(f.intent));
  });

  test('report aggregates frames into ordered timeline and bounded scores', () {
    final frames = [
      analyzer.analyze(speaker: Speaker.a, text: 'שלום מה שלומך', t: 1),
      analyzer.analyze(speaker: Speaker.b, text: 'תודה מעולה', t: 5),
      analyzer.analyze(speaker: Speaker.a, text: 'נקבע פגישה', t: 9),
    ];
    final report = buildHeuristicReport(frames, [
      // a couple of dummy segments so summary isn't the empty-state text
      // (content not asserted here).
    ]);
    expect(report.timeline.length, frames.length);
    expect(report.scores.trustLevel, inInclusiveRange(0, 100));
    expect(report.scores.conversionProbability, inInclusiveRange(0, 100));
    for (var i = 1; i < report.timeline.length; i++) {
      expect(report.timeline[i].t,
          greaterThanOrEqualTo(report.timeline[i - 1].t));
    }
  });
}
