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

/// The live call experience: two-speaker emotion meters, a realtime timeline,
/// AI recommendations and a live transcript. Starts capturing on open and
/// navigates to the post-call report when the call ends.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final started = await ref.read(callControllerProvider).startLiveCall();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(callControllerProvider).error ?? 'Could not start call',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(callControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowReport());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Live Call'),
              const SizedBox(width: 10),
              _StatusChip(state: controller.status),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Swap speakers',
              icon: const Icon(Icons.swap_horiz),
              onPressed: controller.isActive ? controller.swapSpeakers : null,
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Pulse'), Tab(text: 'Transcript')],
          ),
        ),
        body: TabBarView(
          children: [
            _PulseTab(controller: controller),
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
                label: const Text('End & Analyze'),
              )
            : null,
      ),
    );
  }
}

class _PulseTab extends StatelessWidget {
  const _PulseTab({required this.controller});
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final allFrames = [...controller.historyA, ...controller.historyB];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SessionState.connected => ('Connected', Colors.blueGrey),
      SessionState.listening => ('● Listening', Color(0xFF2ECC71)),
      SessionState.analyzing => ('Analyzing…', Color(0xFFE67E22)),
      SessionState.stopped => ('Ended', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
