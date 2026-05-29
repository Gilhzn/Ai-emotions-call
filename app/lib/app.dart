import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class EmotionCallApp extends StatelessWidget {
  const EmotionCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmotionCall AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
