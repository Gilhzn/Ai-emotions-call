import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/backend_config.dart';
import '../../services/file_analysis_service.dart';
import '../call/call_screen.dart';
import '../postcall/post_call_screen.dart';

/// Entry screen: try the on-device demo, start a live call (needs a backend),
/// or import a recording. Also lets the user point the app at any backend at
/// runtime (no rebuild required).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadBackendUrl(ref));
  }

  Future<void> _editBackend() async {
    final current = ref.read(backendUrlProvider);
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('כתובת השרת'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            hintText: 'ws://192.168.1.50:8080',
            helperText: 'כתובת ה‑WebSocket של השרת (ללא ‎/call)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('שמירה'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await saveBackendUrl(ref, result);
    }
  }

  Future<void> _importRecording() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _analyzing = true);
    try {
      final base = ref.read(backendUrlProvider);
      final result = await FileAnalysisService(BackendUrls(base).analyzeFile)
          .analyze(path: path, filename: picked!.files.single.name);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostCallScreen(report: result.report),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('הייבוא נכשל: $e')));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _openCall(CallMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CallScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backendUrl = ref.watch(backendUrlProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.graphic_eq, size: 64, color: Color(0xFF5B8DEF)),
              const SizedBox(height: 16),
              const Text('EmotionCall AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('ניתוח רגשות וכוונות בזמן אמת לשיחות שלך',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed:
                    _analyzing ? null : () => _openCall(CallMode.onDevice),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.mic),
                label: const Text('ניתוח חי על המכשיר'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _analyzing ? null : () => _openCall(CallMode.demo),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('הדגמה (נתונים מדומים)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _analyzing ? null : () => _openCall(CallMode.live),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('שיחה חיה (דורש שרת)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _analyzing ? null : _importRecording,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_analyzing ? 'מנתח…' : 'ייבוא הקלטה (דורש שרת)'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _editBackend,
                icon: const Icon(Icons.settings, size: 16),
                label: Text('שרת: $backendUrl',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
