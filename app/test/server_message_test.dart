import 'package:emotioncall/core/models/insight.dart';
import 'package:emotioncall/core/models/speaker.dart';
import 'package:emotioncall/core/ws/server_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerMessage.parse', () {
    test('parses a transcript event', () {
      final msg = ServerMessage.parse(
        '{"type":"transcript","speaker":"B","text":"hi","isFinal":true,"tStart":1.0,"tEnd":2.0}',
      );
      expect(msg, isA<TranscriptEvent>());
      final t = (msg as TranscriptEvent).segment;
      expect(t.speaker, Speaker.b);
      expect(t.text, 'hi');
      expect(t.isFinal, true);
    });

    test('parses an emotion event with scores in range', () {
      final msg = ServerMessage.parse(
        '{"type":"emotion","speaker":"A","t":3.0,'
        '"scores":{"positive":80,"angry":0,"stressed":10,"neutral":20,'
        '"disappointed":0,"suspicious":5,"aggressive":0},'
        '"trust":70,"dominance":60,"stress":10,"intent":"showing interest"}',
      );
      expect(msg, isA<EmotionEvent>());
      final f = (msg as EmotionEvent).frame;
      expect(f.speaker, Speaker.a);
      expect(f.scores.positive, 80);
      expect(f.scores.dominant, 'positive');
      expect(f.intent, 'showing interest');
    });

    test('parses status, insight and report events', () {
      expect(
        (ServerMessage.parse('{"type":"status","state":"listening"}')
                as StatusEvent)
            .state,
        SessionState.listening,
      );

      final insight = ServerMessage.parse(
        '{"type":"insight","t":5.0,"severity":"critical","text":"slow down"}',
      ) as InsightEvent;
      expect(insight.insight.severity, InsightSeverity.critical);

      final report = ServerMessage.parse(
        '{"type":"report","report":{"summary":"ok",'
        '"scores":{"sellerScore":78,"customerEmotion":61,"trustLevel":49,"conversionProbability":67},'
        '"sections":[{"name":"opening","summary":"good","energy":"high"}],'
        '"events":[{"type":"interruption","t":4.0,"note":"cut off"}],'
        '"timeline":[{"t":1.0,"trust":50,"stress":20,"dominance":55,"emotionDominant":"neutral"}]}}',
      ) as ReportEvent;
      expect(report.report.scores.sellerScore, 78);
      expect(report.report.sections.single.name, 'opening');
      expect(report.report.timeline.single.emotionDominant, 'neutral');
    });

    test('returns null for garbage and unknown types', () {
      expect(ServerMessage.parse('not json'), isNull);
      expect(ServerMessage.parse('{"type":"explode"}'), isNull);
      expect(ServerMessage.parse('[]'), isNull);
    });
  });
}
