/// The app.
library;

import 'package:flutter/material.dart';

import 'app_context.dart';
import 'screen/home_screen.dart';

/// The app.
class LyricsEditorApp extends StatelessWidget {
  /// What the screens share.
  final LyricsAppContext appContext;

  /// The app.
  const LyricsEditorApp({super.key, required this.appContext});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      ),
    );
    return MaterialApp(
      title: lyricsEditorAppName,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: LyricsHomeScreen(appContext: appContext),
    );
  }
}
