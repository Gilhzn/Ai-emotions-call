import 'package:flutter/material.dart';

/// Shared colors + emoji for the seven emotions, used by meters, the timeline
/// and the heatmap so the visual language is consistent across screens.
class EmotionPalette {
  static const Map<String, Color> colors = {
    'positive': Color(0xFF2ECC71),
    'angry': Color(0xFFE74C3C),
    'stressed': Color(0xFFE67E22),
    'neutral': Color(0xFF95A5A6),
    'disappointed': Color(0xFF8E44AD),
    'suspicious': Color(0xFFF1C40F),
    'aggressive': Color(0xFFC0392B),
  };

  static const Map<String, String> emoji = {
    'positive': '😊',
    'angry': '😠',
    'stressed': '😨',
    'neutral': '😐',
    'disappointed': '😢',
    'suspicious': '🤔',
    'aggressive': '🔥',
  };

  static Color of(String emotion) => colors[emotion] ?? Colors.grey;

  static String emojiOf(String emotion) => emoji[emotion] ?? '😐';

  /// Color for a 0..100 score: red (low) -> amber -> green (high).
  static Color forScore(int score) {
    final t = (score.clamp(0, 100)) / 100.0;
    if (t < 0.5) {
      return Color.lerp(const Color(0xFFE74C3C), const Color(0xFFF1C40F), t * 2)!;
    }
    return Color.lerp(const Color(0xFFF1C40F), const Color(0xFF2ECC71), (t - 0.5) * 2)!;
  }
}
