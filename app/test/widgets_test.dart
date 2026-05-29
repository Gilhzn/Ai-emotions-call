import 'package:emotioncall/core/models/emotion_frame.dart';
import 'package:emotioncall/core/models/emotion_scores.dart';
import 'package:emotioncall/core/models/post_call_report.dart';
import 'package:emotioncall/core/models/speaker.dart';
import 'package:emotioncall/features/call/widgets/emotion_meter.dart';
import 'package:emotioncall/features/postcall/post_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('EmotionMeter shows listening state with no frame',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const EmotionMeter(speaker: Speaker.a, frame: null)),
    );
    expect(find.text('Rep (A)'), findsOneWidget);
    expect(find.text('Listening…'), findsOneWidget);
  });

  testWidgets('EmotionMeter renders scores, dimensions and intent',
      (tester) async {
    const frame = EmotionFrame(
      speaker: Speaker.b,
      t: 1,
      scores: EmotionScores(
        positive: 70,
        angry: 0,
        stressed: 30,
        neutral: 10,
        disappointed: 0,
        suspicious: 0,
        aggressive: 0,
      ),
      trust: 65,
      dominance: 40,
      stress: 30,
      intent: 'evaluating fit',
    );
    await tester.pumpWidget(
      _wrap(const EmotionMeter(speaker: Speaker.b, frame: frame)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Customer (B)'), findsOneWidget);
    expect(find.text('positive'), findsOneWidget);
    expect(find.text('Intent: evaluating fit'), findsOneWidget);
    expect(find.text('65'), findsWidgets); // trust dimension
  });

  testWidgets('PostCallScreen renders scores, summary and sections',
      (tester) async {
    // Tall viewport so the lazy ListView builds the summary + sections too.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const report = PostCallReport(
      summary: 'Solid call with a price objection.',
      scores: ReportScores(
        sellerScore: 78,
        customerEmotion: 61,
        trustLevel: 49,
        conversionProbability: 67,
      ),
      sections: [
        ReportSection(name: 'opening', summary: 'good energy', energy: 'high'),
      ],
      events: [CallEvent(type: 'interruption', t: 12, note: 'cut off')],
      timeline: [
        TimelinePoint(
            t: 0, trust: 50, stress: 20, dominance: 55, emotionDominant: 'neutral'),
        TimelinePoint(
            t: 10, trust: 60, stress: 30, dominance: 50, emotionDominant: 'positive'),
      ],
    );
    await tester.pumpWidget(
        const MaterialApp(home: PostCallScreen(report: report)));
    expect(find.text('78'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Solid call with a price objection.'), findsOneWidget);
    expect(find.text('opening'), findsOneWidget);
  });
}
