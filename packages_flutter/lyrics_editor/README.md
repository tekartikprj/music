# tekaly_lyrics_editor

The lyrics editor widgets for a Flutter app: time lyrics by tapping along with
the song (per syllable, word, line or page; hold mode, nudge, loop, speed),
edit the text (syllables with `|`, `[C]` chords, pages, or the LRC itself),
calibrate the tap and audio latencies, preview as karaoke. One controller
(`LyricsEditorController`) shares the document, the clock and one undo history
between them.

No player and no storage of its own: the app gives a `LyricsPlayer`
(`tekaly_lyrics_core`; a `ClockLyricsPlayer` when there is no media), a
`LyricsEditorStore` (where the document is saved) and `LyricsEditorSettings`
(the latencies). `apps/lyrics_editor_app` in this repo hosts it on audio
files, YouTube or a clock, with local drafts.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekaly_lyrics_editor:
    git:
      url: https://github.com/tekartikprj/music
      path: packages_flutter/lyrics_editor
```

A timing screen on a clock, everything kept in memory:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

class TimingPage extends StatefulWidget {
  const TimingPage({super.key});

  @override
  State<TimingPage> createState() => _TimingPageState();
}

class _TimingPageState extends State<TimingPage> {
  final _player = ClockLyricsPlayer(); // no media: a clock
  late final _controller = LyricsEditorController(
    document: CvLyricsDocument.of(parseLyricsText('Hel|lo world').lyrics),
    player: _player,
    settings: LyricsEditorSettingsMemory(),
    store: LyricsEditorStoreMemory(),
  );

  @override
  void dispose() {
    _controller.dispose(); // saves what is not saved yet
    _player.dispose(); // the app owns the player
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LyricsTimingKeys(
    controller: _controller, // space taps, Enter ends a line...
    child: Scaffold(
      appBar: AppBar(
        actions: [
          LyricsEditorSaveButton(controller: _controller),
          LyricsTimingMenuButton(controller: _controller),
        ],
      ),
      body: LyricsTimingEditor(controller: _controller),
    ),
  );
}

void main() {
  initTekalyLyricsBuilders(); // once, before any lyrics
  runApp(const MaterialApp(home: TimingPage()));
}
```

### Platforms

Every Flutter platform (mobile, desktop, web): no plugin of its own. The
LRC/text import and export go through `tekaly_file_picker`: initialize its
Flutter implementation in the app for them.

## What to use

| Class | For |
|---|---|
| `LyricsEditorController` | The shared state: lyrics, clock (`positionMs`), taps, transport, undo/redo, debounced save, changes made elsewhere. |
| `LyricsTimingEditor`, `LyricsTimingKeys`, `LyricsTimingMenuButton`, `LyricsTapBar` | The timing screen, its keys, its menu (estimate, shift, clear, offset). |
| `LyricsTextController`, `LyricsTextEditor`, `LyricsTextImportButton`, `LyricsTextMenuButton` | The text (or LRC) editor, import, export. |
| `LyricsLatencySettings` | The tap and audio latencies, with a calibration. |
| `LyricsTransportBar`, `LyricsKaraokePreview` | Play/seek/speed/loop, the preview. |
| `LyricsEditorStore`, `LyricsEditorSettings`, `LyricsPlayerView`, `LyricsEditorAction` | What the app implements: storage, settings, a player with a picture, extra menu actions. |

## Common mistakes

* The widgets are built on `package:material_ui`: use its `MaterialApp` and
  `Scaffold` (`import 'package:material_ui/material_ui.dart'`), not Flutter's
  (they fail with "No Material widget found").
* Call `initTekalyLyricsBuilders()` once before creating lyrics.
* The controller never disposes the player: the app does.
* A store that throws keeps the document dirty and `save()` rethrows; the
  debounced save cannot report it: catch and report errors in the store.
* In widget tests, pump with durations, never `pumpAndSettle` (the preview
  animates every frame).

Agent skill: [tekaly-lyrics-editor-host](skills/tekaly-lyrics-editor-host/SKILL.md).
