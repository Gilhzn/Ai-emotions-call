import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures microphone audio as a stream of PCM16 (16 kHz mono) chunks suitable
/// for streaming to the backend. Wraps the `record` package so the rest of the
/// app depends only on this small surface.
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();

  /// 16 kHz, 16-bit, mono — matches the backend `start` contract.
  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
  );

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Begin capturing; emits raw PCM16 byte chunks until [stop] is called.
  Future<Stream<Uint8List>> start() {
    return _recorder.startStream(_config);
  }

  Future<void> stop() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
