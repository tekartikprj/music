---
name: tekaly-lyrics-core-player
description: >-
  Use when lyrics are timed or played against a player with
  package:tekaly_lyrics_core/lyrics_core.dart: the LyricsPlayer interface
  (reports, play, pause, seek, setRate, rates, durationMs), LyricsPlayerReport,
  the optional LyricsPlayerClock / LyricsPlayerTracks / LyricsPlayerMute,
  ClockLyricsPlayer (no media, an injectable time source), the document an
  editor opens and saves (CvLyricsDocument, CvLyricsMedia, CvLyricsTrack,
  toJsonText / parseLyricsDocumentJson / lyricsDocumentFromMap),
  decodeLyricsBytes, and LyricsTapEditor state / restore / isTimed /
  firstUntimedIndex for a host undo history.
---

# Players and documents (tekaly_lyrics_core)

The lyrics editor (`tekaly_lyrics_editor`) times lyrics against anything
that has a media time: a `LyricsPlayer`. It opens and saves a
`CvLyricsDocument`: the lyrics plus a title, an artist and the media they go
with.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_lyrics_core:
      git:
        url: https://github.com/tekartikprj/music
        path: packages/lyrics_core
      version: '>=0.1.0'
  ```
* Every time is a media time in milliseconds. A `LyricsPlayer` reports
  `LyricsPlayerReport(positionMs:, playing:, rate:)` on `reports` (every 100
  to 250 ms while playing, and on every play, pause, seek and rate change),
  and offers `play`, `pause`, `seek(ms)`, `setRate(rate)`, the `rates` of its
  speed menu, `durationMs` (null while unknown) and `dispose`.
* A player that already smooths its position hands it over by also
  implementing `LyricsPlayerClock` (`LyricsClock get clock`), so it is not
  smoothed twice. Otherwise the consumer feeds its own `LyricsClock` from the
  reports and calls `clock.seek` on every seek.
* Optional capabilities, tested with `is`: `LyricsPlayerTracks` (`tracks`,
  `track`, `selectTrack(name)`: several audio files on the same timeline,
  switching keeps the position) and `LyricsPlayerMute` (`setMuted`).
* `ClockLyricsPlayer` has no media: a stopwatch that plays, pauses, seeks
  (never below 0, never past `durationMs` when set, where it pauses) and
  changes rate (0.1 to 4). Inject `nowMs` in tests: positions are then exact,
  and reports go out on each command; the periodic reports need real time
  or a fake async.
* `CvLyricsDocument` holds `lyrics` (`CvLyrics`), `title`, `artist`,
  `album`, `instrumental`, `source` (a file name, `lrclib:<id>`) and `media`
  (`CvLyricsMedia.file(path, tracks:)`, `.youtube(videoId, url:)`,
  `.none()`). Call `initTekalyLyricsBuilders()` before (de)serializing;
  `toJsonText()` is the lossless native format (`X.lyrics.json`), read back
  with `parseLyricsDocumentJson` (or `lyricsDocumentFromMap` from a map).
* Read lyrics files with `decodeLyricsBytes(bytes)`: UTF-8 with its byte order
  mark dropped, Latin-1 when not valid UTF-8 (old LRC files).
* A host keeping one undo history for text edits and taps saves
  `tapEditor.state` (a copy: lyrics, cursor, last tapped unit) before each
  change and puts it back with `tapEditor.restore(state)`.
* Where timing carries on: `tapEditor.firstUntimedIndex`. `isTimed(ref)`
  counts the line start for the first syllable of a line (an LRC line start
  times it), where `timeOf(ref)` only gives the stored time.

## Examples

### Timing against no media

```dart
import 'package:tekaly_lyrics_core/lyrics_core.dart';

Future<void> main() async {
  initTekalyLyricsBuilders();
  var now = 0;
  var player = ClockLyricsPlayer(nowMs: () => now);
  var editor = LyricsTapEditor(parseLyricsText('Ka|ra|o|ke').lyrics);
  await player.play();
  now = 1200;
  editor.tap(player.positionMs);
  var before = editor.state;
  now = 1500;
  editor.tap(player.positionMs);
  editor.restore(before); // an undo kept by the host
  print(editor.cursorUnit); // Unit(0, 1)
  await player.dispose();
}
```

### A document and its native format

```dart
import 'package:tekaly_lyrics_core/lyrics_core.dart';

String saveNative(String lrc) {
  initTekalyLyricsBuilders();
  var imported = importLyrics(lrc, fileName: 'song.lrc');
  var document = CvLyricsDocument.of(
    imported.lyrics,
    title: imported.title,
    artist: imported.artist,
    media: CvLyricsMedia.file(
      'song.mp3',
      tracks: [CvLyricsTrack.of('instrumental', 'song-no_vocals.mp3')],
    ),
    source: 'song.lrc',
  );
  var text = document.toJsonText();
  assert(parseLyricsDocumentJson(text) == document);
  return text;
}
```
