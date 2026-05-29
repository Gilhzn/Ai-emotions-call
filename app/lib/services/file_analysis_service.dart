import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../core/models/emotion_frame.dart';
import '../core/models/insight.dart';
import '../core/models/post_call_report.dart';
import '../core/models/transcript_segment.dart';

/// Result of POST /analyze-file. Mirrors `FileAnalysisResult` in
/// backend/src/http/analyzeFile.ts.
class FileAnalysisResult {
  const FileAnalysisResult({
    required this.transcript,
    required this.emotionFrames,
    required this.insights,
    required this.report,
  });

  final List<TranscriptSegment> transcript;
  final List<EmotionFrame> emotionFrames;
  final List<Insight> insights;
  final PostCallReport report;

  factory FileAnalysisResult.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) {
      final raw = json[key] as List?;
      if (raw == null) return <T>[];
      return raw
          .whereType<Map>()
          .map((e) => f(e.cast<String, dynamic>()))
          .toList();
    }

    return FileAnalysisResult(
      transcript: list('transcript', TranscriptSegment.fromJson),
      emotionFrames: list('emotionFrames', EmotionFrame.fromJson),
      insights: list('insights', Insight.fromJson),
      report: PostCallReport.fromJson(
        (json['report'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

/// Uploads a recorded audio file to the backend for batch analysis.
class FileAnalysisService {
  Future<FileAnalysisResult> analyze({
    required String path,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(Env.analyzeFileUrl))
      ..files.add(await http.MultipartFile.fromPath('audio', path, filename: filename));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception(
        'Analysis failed (${response.statusCode}): ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FileAnalysisResult.fromJson(json);
  }
}
