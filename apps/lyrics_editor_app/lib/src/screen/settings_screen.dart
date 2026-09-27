/// The settings: the tap and audio latencies of this device.
library;

import 'package:flutter/material.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

/// The settings.
class LyricsSettingsScreen extends StatelessWidget {
  /// The latency settings.
  final LyricsEditorSettings settings;

  /// The settings.
  const LyricsSettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Latency')),
      body: LyricsLatencySettings(settings: settings),
    );
  }
}
