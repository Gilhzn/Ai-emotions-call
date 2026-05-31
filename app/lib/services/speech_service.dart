import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around the device's built-in speech recognizer (Android
/// SpeechRecognizer / iOS Speech). Hebrew by default, no API keys, no backend.
class SpeechService {
  final SpeechToText _stt = SpeechToText();

  bool get isListening => _stt.isListening;

  Future<bool> init({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    return _stt.initialize(
      onStatus: onStatus,
      onError: (e) => onError(e.errorMsg),
      finalTimeout: const Duration(milliseconds: 800),
    );
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'he_IL',
  }) async {
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        autoPunctuation: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: localeId,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 5),
      ),
    );
  }

  Future<void> stop() => _stt.stop();

  Future<void> cancel() => _stt.cancel();
}
