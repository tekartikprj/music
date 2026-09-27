---
name: tekaly-lyrics-core-model
description: >-
  Use when an app stores, imports, exports, times or plays song lyrics for
  karaoke or a songbook with package:tekaly_lyrics_core/lyrics_core.dart: the
  CvLyrics / CvLyricsLine / CvLyricsPart model (media milliseconds), LRC and
  enhanced LRC (parseLrcLyrics, formatLrcLyrics), SRT/WebVTT
  (parseSubtitleLyrics), the lyrics text format and ChordPro
  (parseLyricsText, formatLyricsText, isLyricsChordName), importLyrics /
  detectLyricsFormat, mergeLyricsTiming, LyricsTimeline (pages, locate,
  sungRanges), MediaRange / computePlayRanges / nextPlayRangeIndex,
  LyricsClock, LyricsTapEditor and transposeLyricsChord.
---

# tekaly_lyrics_core

Lyrics are lines of parts (syllables); every time is an `int` of
milliseconds of the media's own timeline (it depends neither on the playback
speed nor on the clips played) and every time is optional: untimed lyrics are
songbook text, timed ones karaoke, and the same model is enriched
progressively (pages first, or syllables right away). Pure Dart, the Flutter
display is `tekaly_lyrics_view` (`lyrics_view.dart`).

## Guidelines

* Import `package:tekaly_lyrics_core/lyrics_core.dart`; call
  `initTekalyLyricsBuilders()` before (de)serializing (the models are cv
  models, they go to sdb, firestore and json untouched).
* Model: `CvLyrics.of(lines, offsetMs:, language:)`,
  `CvLyricsLine.of(parts, startMs:, endMs:, newPage:, pageMs:, section:)`,
  `CvLyricsPart.of(text, startMs:, endMs:, join:, chord:)`. `join` means no
  space after (the syllables of a word); `newPage` starts a page, `pageMs`
  shows it at a given time; `offsetMs` is added to every time (reuse a
  timing on another recording). Helpers: `text`, `isTimed`,
  `hasPartTiming`, `hasChords`, `copy()`, `shiftTimes(delta, fromLine:)`,
  `clearTimes(fromLine:)`, `transposeChords(semitones)`.
* Formats, all returning a `LyricsImport` (`lyrics`, `title`, `artist`):
  `importLyrics(content, fileName:)` detects (`detectLyricsFormat`: the
  extension first, then the content) and dispatches to
  `parseLrcLyrics` (LRC, enhanced LRC with `<mm:ss.xx>` per part, repeated
  lines, `[offset:]`, an empty timed line ends the previous line, an empty
  line starts a page), `parseSubtitleLyrics` (SRT, WebVTT, its `<time>`
  karaoke timestamps; a cue is a page) or `parseLyricsText` (the text format:
  a line per line, a blank line per page, `|` between syllables, `[C]` chords,
  `[Chorus]` section labels, ChordPro directives, chords over lyrics).
  Export with `formatLrcLyrics(lyrics, title:, artist:)` (three digit
  milliseconds, offset applied) and `formatLyricsText(lyrics, chords:,
  syllables:)`.
* Editing the text of timed lyrics: parse the new text then
  `mergeLyricsTiming(previous, edited)` keeps the times of unchanged lines
  (and of changed lines in place when they keep their syllable count).
* `LyricsTimeline(lyrics, options: LyricsTimelineOptions(linesPerPage:,
  pageLeadInMs:))` derives what the stored times mean: line starts from the
  first timed part, ends from the next line, parts estimated in proportion
  of their text between known times (`LyricsTimelinePart.estimated`), the
  pages (explicit or every `linesPerPage` lines) and their show times.
  `locate(ms)` gives a `LyricsLocation` (page, line, part, progresses,
  singing), `sungRanges(leadInMs:, tailMs:, gapMinMs:)` the ranges to play
  when skipping the parts without lyrics.
* What a player plays: `computePlayRanges(clips:, sung:)` intersects the
  clips (in play order, `MediaRange(fromMs, toMs)`, an empty list for the
  whole media) with the sung ranges; `nextPlayRangeIndex(ranges, index,
  positionMs, durationMs:)` says when to seek to the next range or move to
  the next song.
* `LyricsClock` smooths the positions a player reports every 100–250 ms:
  `report(ms, playing:, rate:)`, `seek(ms)`, `setRate(rate)`, then read
  `positionMs` on every frame (no jitter backwards, extrapolation capped).
* The timing editor logic is `LyricsTapEditor(lyrics, granularity:,
  tapLatencyMs:)`: `tap(positionMs)` times the unit under the cursor and
  advances (syllable, word, line — its timed syllables move along —, page),
  `release` (hold mode end), `endLine`, `pageHere`, `undo`, `nudge`,
  `setTime`, `shiftFrom`, `clearFrom`, `setOffset`, `estimateParts`,
  `validate()`; positions are media positions, the stored times have the
  tap latency and the offset taken off. It works on a copy: save
  `editor.lyrics`.

## Examples

```dart
import 'package:tekaly_lyrics_core/lyrics_core.dart';

void main() {
  initTekalyLyricsBuilders();
  var lyrics = importLyrics('''
[00:10.000]<00:10.000>Do <00:10.500>ré <00:11.000>mi<00:11.500>
[00:40.000]Much later
''', fileName: 'demo.lrc').lyrics;
  var timeline = LyricsTimeline(lyrics);
  print(timeline.locate(10700).partIndex); // 1: ré
  var ranges = computePlayRanges(
    sung: timeline.sungRanges(leadInMs: 3000, tailMs: 1500, gapMinMs: 8000),
  );
  print(ranges); // the intro and the break skipped
  print(formatLyricsText(lyrics)); // Do ré mi / Much later
}
```
