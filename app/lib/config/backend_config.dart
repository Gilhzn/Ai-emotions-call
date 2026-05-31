import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';

/// Runtime-configurable backend address so one build works against any backend
/// (local dev, LAN, or deployed) without recompiling. Defaults to the
/// compile-time [Env.backendUrl] and is persisted with SharedPreferences.
const String _prefsKey = 'backend_url';

/// Current backend WS base, e.g. `ws://192.168.1.50:8080` (no `/call`).
final backendUrlProvider = StateProvider<String>((ref) => Env.backendUrl);

class BackendUrls {
  const BackendUrls(this.base);
  final String base;

  String get callWs => '$base/call';
  String get analyzeFile => '$_http/analyze-file';

  String get _http {
    if (base.startsWith('wss://')) return 'https://${base.substring(6)}';
    if (base.startsWith('ws://')) return 'http://${base.substring(5)}';
    return base;
  }
}

/// Load the persisted backend URL into the provider (call once at startup).
Future<void> loadBackendUrl(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsKey);
  if (saved != null && saved.trim().isNotEmpty) {
    ref.read(backendUrlProvider.notifier).state = saved.trim();
  }
}

/// Persist + apply a new backend URL.
Future<void> saveBackendUrl(WidgetRef ref, String url) async {
  final clean = url.trim();
  ref.read(backendUrlProvider.notifier).state = clean;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, clean);
}
