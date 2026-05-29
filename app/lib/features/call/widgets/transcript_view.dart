import 'package:flutter/material.dart';

import '../../../core/models/speaker.dart';
import '../../../core/models/transcript_segment.dart';

/// Auto-scrolling live transcript, colored per speaker, with any in-progress
/// (interim) utterances shown faded at the bottom.
class TranscriptView extends StatefulWidget {
  const TranscriptView({
    super.key,
    required this.finalSegments,
    required this.interim,
  });

  final List<TranscriptSegment> finalSegments;
  final Map<Speaker, TranscriptSegment> interim;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interimRows = widget.interim.values.toList();
    final total = widget.finalSegments.length + interimRows.length;
    if (total == 0) {
      return const Center(
        child: Text('Transcript will appear here…',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: total,
      itemBuilder: (context, i) {
        if (i < widget.finalSegments.length) {
          return _Line(segment: widget.finalSegments[i], faded: false);
        }
        return _Line(
          segment: interimRows[i - widget.finalSegments.length],
          faded: true,
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.segment, required this.faded});
  final TranscriptSegment segment;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final isA = segment.speaker == Speaker.a;
    final color = isA ? const Color(0xFF5B8DEF) : const Color(0xFF2ECC71);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: faded ? 0.5 : 1,
        child: Column(
          crossAxisAlignment:
              isA ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(segment.speaker.label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(segment.text),
            ),
          ],
        ),
      ),
    );
  }
}
