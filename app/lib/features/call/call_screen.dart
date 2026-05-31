import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/speaker.dart';
import '../../core/ws/server_message.dart';
import '../postcall/post_call_screen.dart';
import 'call_controller.dart';
import 'widgets/emotion_meter.dart';
import 'widgets/emotion_timeline.dart';
import 'widgets/recommendation_feed.dart';
import 'widgets/transcript_view.dart';

/// How the live screen sources its data.
enum CallMode {
  /// Fully on-device scripted simulation (no mic, no network).
  demo,

  /// On-device speech recognition + local heuristic emotion analysis.
  onDevice,

  /// Mic streamed to the backend for transcription + AI analysis.
  live,
}

/// The live call experience: two-speaker emotion meters, a realtime timeline,
/// AI recommendations and a live transcript. Starts on open per [mode] and
/// navigates to the post-call report when the call ends.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, this.mode = CallMode.live});

  final CallMode mode;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(callControllerProvider);
      final started = switch (widget.mode) {
        CallMode.demo => await controller.startDemoCall(),
        CallMode.onDevice => await controller.startOnDeviceCall(),
        CallMode.live => await controller.startLiveCall(),
      };
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.error ?? 'לא ניתן להתחיל שיחה')),
        );
      }
    });
  }

  void _maybeShowReport() {
    final controller = ref.read(callControllerProvider);
    final report = controller.report;
    if (report != null && !_navigated && mounted) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PostCallScreen(report: report)),
      );
    }
  }

  String get _title => switch (widget.mode) {
        CallMode.demo => 'הדגמה חיה',
        CallMode.onDevice => 'ניתוח על המכשיר',
        CallMode.live => 'שיחה חיה',
      };

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(callControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowReport());
    final showSwap = widget.mode != CallMode.demo;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(_title),
              const SizedBox(width: 10),
              _StatusChip(state: controller.status),
            ],
          ),
          actions: [
            if (showSwap)
              IconButton(
                tooltip: widget.mode == CallMode.onDevice
                    ? 'החלף דובר פעיל'
                    : 'החלף דוברים',
                icon: const Icon(Icons.swap_horiz),
                onPressed: controller.isActive ? controller.swapSpeakers : null,
              ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'דופק'), Tab(text: 'תמלול')],
          ),
        ),
        body: TabBarView(
          children: [
            _PulseTab(controller: controller, mode: widget.mode),
            TranscriptView(
              finalSegments: controller.finalSegments,
              interim: controller.interim,
            ),
          ],
        ),
        floatingActionButton: controller.isActive
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xFFE74C3C),
                onPressed: () => controller.stopCall(),
                icon: const Icon(Icons.stop),
                label: const Text('סיים ונתח'),
              )
            : null,
      ),
    );
  }
}

class _PulseTab extends StatelessWidget {
  const _PulseTab({required this.controller, required this.mode});
  final CallController controller;
  final CallMode mode;

  @override
  Widget build(BuildContext context) {
    final allFrames = [...controller.historyA, ...controller.historyB];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (mode == CallMode.demo)
            const _Banner(
              color: Color(0xFF5B8DEF),
              icon: Icons.play_circle_outline,
              text: 'מצב הדגמה — נתונים מדומים רצים על המכשיר, ללא שרת.',
            ),
          if (mode == CallMode.onDevice)
            _Banner(
              color: const Color(0xFF5B8DEF),
              icon: Icons.mic_none,
              text:
                  'ניתוח על המכשיר (היוריסטי). דבר בעברית ברור. דובר פעיל: '
                  '${controller.activeSpeaker.label} — הקש על ⇄ כדי להחליף.',
            ),
          if (controller.error != null)
            _Banner(
              color: const Color(0xFFE74C3C),
              icon: Icons.error_outline,
              text: controller.error!,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EmotionMeter(
                  speaker: Speaker.a,
                  frame: controller.latest[Speaker.a],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EmotionMeter(
                  speaker: Speaker.b,
                  frame: controller.latest[Speaker.b],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 200,
                child: EmotionTimeline(frames: allFrames),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RecommendationFeed(insights: controller.insights),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SessionState.connected => ('מחובר', Colors.blueGrey),
      SessionState.listening => ('● מקשיב', const Color(0xFF2ECC71)),
      SessionState.analyzing => ('מנתח…', const Color(0xFFE67E22)),
      SessionState.stopped => ('הסתיים', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
