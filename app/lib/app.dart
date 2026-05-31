import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      // Hebrew UI, right-to-left throughout.
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
