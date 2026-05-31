/// Backend connection config. The app holds NO API keys — only the address of
/// the backend proxy, which is supplied at build/run time via --dart-define:
///
///   flutter run --dart-define=BACKEND_URL=ws://10.0.2.2:8080
///
/// The default targets the Android emulator's host loopback (10.0.2.2). Use
/// your machine's LAN IP for a physical device, or your deployed backend URL.
class Env {
  /// WebSocket base, e.g. ws://10.0.2.2:8080 (no trailing slash, no /call).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );

  /// WebSocket URL for the live call endpoint.
  static String get callWsUrl => '$backendUrl/call';

  /// HTTP base derived from the WS base (ws->http, wss->https).
  static String get httpBase {
    if (backendUrl.startsWith('wss://')) {
      return 'https://${backendUrl.substring('wss://'.length)}';
    }
    if (backendUrl.startsWith('ws://')) {
      return 'http://${backendUrl.substring('ws://'.length)}';
    }
    return backendUrl;
  }

  /// HTTP URL for the batch file-analysis endpoint.
  static String get analyzeFileUrl => '$httpBase/analyze-file';
}
