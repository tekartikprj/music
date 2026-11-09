## tekaly_lyrics_view

Flutter display of [`tekaly_lyrics_core`](../../packages/lyrics_core) lyrics
(`CvLyrics`):

* `KaraokeLyricsView` follows a media position: a page (or a scrolling list)
  of lines, the syllables wiped as they are sung, lead-in dots after a gap.
* `SongbookLyricsView` shows the text with the chords above the syllables,
  transposed if needed.

`package:tekaly_lyrics_view/lyrics_view.dart` also re-exports
`tekaly_lyrics_core` (the model, the LRC/SRT/text/ChordPro formats, the
timeline, `LyricsClock`, `ClockLyricsPlayer`).

## Getting started

Not on pub.dev, add a git dependency:

```yaml
dependencies:
  tekaly_lyrics_view:
    git:
      url: https://github.com/tekartikprj/music
      path: packages_flutter/lyrics_view
```

Karaoke lyrics following a player:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

final lyrics = parseLrcLyrics('''
[00:01.00]<00:01.00>Hel<00:01.50>lo <00:02.00>world
[00:04.00]A line timed by its start
''').lyrics;

/// A player with no media (a stopwatch), see below for a real one.
final player = ClockLyricsPlayer();

Widget karaoke() => SizedBox(
  height: 240,
  child: KaraokeLyricsView(
    lyrics: lyrics,
    positionMs: () => player.positionMs,
  ),
);
```

`await player.play()` starts it. The full example (karaoke, songbook, a play
button) is [`example/main.dart`](example/main.dart).

It runs on every Flutter platform (Android, iOS, Linux, macOS, Windows, web):
plain Flutter drawing, no plugin, no setup.

## The position

`positionMs` is a function, read on every frame: return the media position in
milliseconds (the media's own time, the lyrics offset is applied by the view).
A player reports its position only every 100 to 250 ms, too coarse for a
syllable wipe: feed a `LyricsClock` with the reports and read it instead.

```dart
import 'dart:math';

import 'package:tekaly_lyrics_view/lyrics_view.dart';

final clock = LyricsClock();

/// Call it on every position or state event of the player.
void onPlayerEvent(int positionMs, bool playing) =>
    clock.report(positionMs, playing: playing);

/// What to give to `positionMs`: the output latency of the device taken off.
int karaokePositionMs({int latencyMs = 0}) =>
    max(0, clock.positionMs - latencyMs);
```

`clock.seek(ms)` on a seek or a new media.

## What to use

| Widget | Shows | Main options |
| --- | --- | --- |
| `KaraokeLyricsView` | timed lyrics following `positionMs` | `layout` (`KaraokeLyricsLayout.page`, the default, or `.scroll`), `linesPerPage` (2, when the lyrics have no page breaks), `style`, `leadInGapMs`/`leadInMs` (3 s) |
| `KaraokeLyricsStyle` | the colors and font size of the karaoke | `.dark` (the default), `.light(sung:)`, `.fromTheme(theme)`, `fontSizeFactor`, `maxFontSize` |
| `SongbookLyricsView` | the text, the chords above the syllables, the section labels, a gap between pages | `showChords`, `transpose` (semitones), `textStyle`, `chordStyle` |

The karaoke uses the finest timing there is: each syllable wiped when parts
are timed, estimated syllables for a line timed by its start only, the whole
line, or the page. Untimed lyrics show as a plain list.

## Common mistakes

* An app on `package:flutter/material.dart`: these widgets are built on
  `package:material_ui` (Flutter's material library as a package), whose
  `ThemeData` is another type. `KaraokeLyricsStyle.fromTheme(Theme.of(context))`
  does not compile, and `SongbookLyricsView` gets material_ui's default theme
  instead of the app's. Import `package:material_ui/material_ui.dart` in the
  app.
* An unbounded box: give `KaraokeLyricsView` a bounded size (`Expanded`, a
  `SizedBox`). The page layout shrinks the font so that the page fits the
  height.
* Editing the lyrics in place: the view compares the lyrics it gets with the
  previous ones, the same instance is never seen as changed (old pages, and an
  error in paint when parts were removed). Pass a new `CvLyrics`
  (`lyrics.copy()` then edit the copy), or change the widget key.
* `pumpAndSettle` never settles in a widget test: the view keeps a ticker
  running. Pump durations (`tester.pump(const Duration(milliseconds: 16))`).
* Lead-in dots are drawn at the top of the view: in the scroll layout they are
  only seen before the first line.
* `SongbookLyricsView` is not scrollable: put it in a scroll view.

## More

* The lyrics model and formats: [`tekaly_lyrics_core`](../../packages/lyrics_core).
* The editor widgets built on this view:
  [`tekaly_lyrics_editor`](../lyrics_editor).
* Agent skill: [`skills/tekaly-lyrics-view-karaoke`](skills/tekaly-lyrics-view-karaoke/SKILL.md).
* In this repository the packages are a workspace: run `flutter pub get` at the
  root.
* Moved from `festenao_lyrics_player` (`tekaly/festenao`), whose deprecated
  `karaoke_player.dart` still re-exports it.
