---
name: tekaly-lyrics-editor-host
description: >-
  Use when a Flutter app embeds the lyrics editor of
  package:tekaly_lyrics_editor/lyrics_editor.dart: LyricsEditorController
  (document, player, settings, store, one undo history, debounced save,
  remote changes), LyricsTimingEditor / LyricsTimingKeys /
  LyricsTimingMenuButton / LyricsTapBar / LyricsEditorSaveButton,
  LyricsTextController / LyricsTextEditor / LyricsTextImportButton /
  LyricsTextMenuButton, LyricsLatencySettings, LyricsTransportBar,
  LyricsKaraokePreview, and the host interfaces LyricsEditorStore,
  LyricsEditorSettings, LyricsPlayerView, LyricsEditorAction.
---

# Hosting the lyrics editor (tekaly_lyrics_editor)

The editor widgets have no player and no storage of their own. The host
gives a `LyricsPlayer` (from `tekaly_lyrics_core`: a `ClockLyricsPlayer` when
there is no media), a `LyricsEditorStore` and `LyricsEditorSettings`, and
places the widgets in its own screens.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_lyrics_editor:
      git:
        url: https://github.com/tekartikprj/music
        path: packages_flutter/lyrics_editor
      version: '>=0.1.0'
  ```
  It re-exports `tekaly_lyrics_view` and `tekaly_lyrics_core`. File import
  and export go through `tekalyFilePicker` (`tekaly_file_picker`): the app
  initializes its Flutter implementation.
* `LyricsEditorController(document:, player:, settings:, store:)` is the
  state every widget shares: the lyrics (`lyrics`, `document`), the clock
  (`positionMs`, fed by the player unless it is a `LyricsPlayerClock`), the
  timing editor (`tapEditor`, null while there are no lyrics), the tap
  operations (`tap`, `release`, `endLine`, `pageHere`, `nudge`...), the
  transport (`play`, `seek`, `setRate`, `fromPreviousLine`, `loop`), one undo
  history (`undo`, `redo`, `canUndo`), and `setLyrics` for a text edit.
* Saving: every change calls `store.save(document)` 2 s later (and on
  `save()`, `close()`, `dispose()`). The store decides where it goes: a
  synced db, or a local draft that the app writes to the user's file on
  Ctrl+S. `store.remoteChanges` (may be null) feeds the "Reload / Keep mine"
  banner. The controller never disposes the player: the host does.
* `LyricsEditorSettings` gives `tapLatencyMs` and `audioLatencyMs` as
  `ValueListenable`s with their setters; `LyricsEditorSettingsMemory` keeps
  them in memory, `LyricsLatencySettings` edits them (with a tap
  calibration).
* Timing: `LyricsTimingEditor(controller:)` is the body (player view,
  preview, transport, lyrics, tap bar). Wrap the part of the screen that
  must get the keys in `LyricsTimingKeys(controller:, child:)` (it
  autofocuses). Put `LyricsEditorSaveButton` and
  `LyricsTimingMenuButton(actions: [...])` in the app bar; host actions are
  `LyricsEditorAction(label:, onSelected:)`.
* A player with a picture (YouTube) also implements `LyricsPlayerView`
  (`buildView(context)`): the timing editor shows it.
* Text: `LyricsTextController(lyrics:)` owns the text field and the lyrics
  it started from; `lyricsOfText()` keeps their times across the edit (and
  imports a pasted LRC/SRT). Apply it with `controller.setLyrics(...)` then
  `text.reset(controller.lyrics)`. `LyricsTextEditor`,
  `LyricsTextImportButton` and `LyricsTextMenuButton(fileName:)` are its
  widgets.
* In widget tests, use a `ClockLyricsPlayer` with an injected `nowMs`, a
  `LyricsEditorStoreMemory` and `LyricsEditorSettingsMemory(tapLatencyMs:
  0)`; pump with durations, never `pumpAndSettle` (the karaoke preview
  animates every frame); dispose the controller and the player at the end.

## Examples

### A timing screen

```dart
import 'package:flutter/material.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

class TimingScreen extends StatefulWidget {
  final CvLyricsDocument document;
  final LyricsEditorStore store;
  final LyricsEditorSettings settings;

  const TimingScreen({
    super.key,
    required this.document,
    required this.store,
    required this.settings,
  });

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> {
  // No media: timing against a clock.
  final _player = ClockLyricsPlayer();
  late final _controller = LyricsEditorController(
    document: widget.document,
    player: _player,
    settings: widget.settings,
    store: widget.store,
  );

  @override
  void dispose() {
    _controller.dispose(); // saves what is not saved yet
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LyricsTimingKeys(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timing'),
          actions: [
            LyricsEditorSaveButton(controller: _controller),
            LyricsTimingMenuButton(
              controller: _controller,
              actions: [
                LyricsEditorAction(
                  label: 'Latency…',
                  onSelected: (context) => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Latency')),
                        body: LyricsLatencySettings(settings: widget.settings),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: LyricsTimingEditor(controller: _controller),
      ),
    );
  }
}
```

### A store and settings for a test

```dart
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

Future<CvLyricsDocument?> timeOnce() async {
  initTekalyLyricsBuilders();
  var store = LyricsEditorStoreMemory();
  var player = ClockLyricsPlayer(nowMs: () => 0);
  var controller = LyricsEditorController(
    document: CvLyricsDocument.of(parseLyricsText('Hel|lo').lyrics),
    player: player,
    settings: LyricsEditorSettingsMemory(tapLatencyMs: 0),
    store: store,
  );
  controller.tap();
  await controller.close(); // saved, then disposed
  await player.dispose();
  return store.saved;
}
```
