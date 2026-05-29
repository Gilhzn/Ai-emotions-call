import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../services/file_analysis_service.dart';
import '../call/call_screen.dart';
import '../postcall/post_call_screen.dart';

/// Entry screen: start a live call or import a recorded conversation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _analyzing = false;

  Future<void> _importRecording() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _analyzing = true);
    try {
      final result = await FileAnalysisService()
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
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Realtime emotion & intent for your calls',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: _analyzing
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CallScreen()),
                        ),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.mic),
                label: const Text('Start live call'),
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
                label: Text(_analyzing ? 'Analyzing…' : 'Import a recording'),
              ),
              const Spacer(),
              Text('Backend: ${Env.backendUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
