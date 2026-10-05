/// The transport bar and the preview, shared by every tab of the editor.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

import 'lyrics_editor_controller.dart';
import 'lyrics_editor_dialogs.dart';

/// Play/pause, seek, speed, position, loop.
class LyricsTransportBar extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// Play/pause, seek, speed, position, loop.
  const LyricsTransportBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.playerState]),
      builder: (context, _) {
        var state = controller.playerState.value;
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Back to the previous line (Shift+←)',
              icon: const Icon(Icons.skip_previous),
              onPressed: controller.fromPreviousLine,
            ),
            IconButton(
              tooltip: '−2 s (←)',
              icon: const Icon(Icons.replay),
              onPressed: () => controller.seekBy(-2000),
            ),
            IconButton.filled(
              tooltip: 'Play/pause (K)',
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              onPressed: controller.togglePlayPause,
            ),
            IconButton(
              tooltip: '+2 s (→)',
              icon: const Icon(Icons.forward_5),
              onPressed: () => controller.seekBy(2000),
            ),
            IconButton(
              tooltip: 'Loop the current line (L)',
              isSelected: controller.loop,
              icon: const Icon(Icons.repeat_one),
              onPressed: controller.toggleLoop,
            ),
            LyricsSpeedMenu(
              rates: controller.player.rates,
              rate: state.rate,
              onSelected: controller.setRate,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                formatLyricsTime(state.positionMs),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The speed menu.
class LyricsSpeedMenu extends StatelessWidget {
  /// The rates offered.
  final List<double> rates;

  /// The current rate.
  final double rate;

  /// Called with the rate picked.
  final void Function(double rate) onSelected;

  /// The speed menu.
  const LyricsSpeedMenu({
    super.key,
    required this.rates,
    required this.rate,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Speed',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var candidate in rates)
          PopupMenuItem(
            value: candidate,
            child: Text(
              formatLyricsPlaybackRate(candidate),
              style: candidate == rate
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed),
            const SizedBox(width: 4),
            Text(formatLyricsPlaybackRate(rate)),
          ],
        ),
      ),
    );
  }
}

/// The karaoke preview of the lyrics being edited, following the clock
/// shifted by the audio latency.
class LyricsKaraokePreview extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// The layout.
  final KaraokeLyricsLayout layout;

  /// The karaoke preview.
  const LyricsKaraokePreview({
    super.key,
    required this.controller,
    this.layout = KaraokeLyricsLayout.page,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.settings.audioLatencyMs,
      ]),
      builder: (context, _) {
        var latency = controller.settings.audioLatencyMs.value;
        return KaraokeLyricsView(
          key: ValueKey(controller.revision),
          lyrics: controller.lyrics,
          layout: layout,
          positionMs: () => max(0, controller.positionMs - latency),
          style: KaraokeLyricsStyle.fromTheme(Theme.of(context)),
        );
      },
    );
  }
}
