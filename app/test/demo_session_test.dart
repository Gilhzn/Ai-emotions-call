import 'package:emotioncall/features/call/demo_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo script produces a multi-turn conversation', () {
    final script = buildDemoScript();
    expect(script.length, greaterThan(8));
    // Every beat has a transcript line and a matching emotion frame.
    for (final e in script) {
      expect(e.segment.text, isNotEmpty);
      expect(e.frame.intent, isNotEmpty);
      expect(e.frame.trust, inInclusiveRange(0, 100));
    }
    // At least a few coaching insights fire during the call.
    expect(script.where((e) => e.insight != null).length, greaterThan(2));
  });

  test('demo report is built from the accumulated frames', () {
    final frames = [for (final e in buildDemoScript()) e.frame];
    final report = buildDemoReport(frames);
    expect(report.timeline.length, frames.length);
    expect(report.summary, isNotEmpty);
    expect(report.sections, isNotEmpty);
    expect(report.scores.sellerScore, inInclusiveRange(0, 100));
    expect(report.scores.conversionProbability, inInclusiveRange(0, 100));
    // Timeline is ordered by time.
    for (var i = 1; i < report.timeline.length; i++) {
      expect(report.timeline[i].t, greaterThanOrEqualTo(report.timeline[i - 1].t));
    }
  });
}
