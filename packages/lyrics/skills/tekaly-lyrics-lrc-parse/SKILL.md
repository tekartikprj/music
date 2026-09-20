---
name: tekaly-lyrics-lrc-parse
description: >-
  Use when parsing, building or writing LRC lyrics (including word/syllable
  timed "enhanced LRC") in Dart with tekaly_lyrics: parseLyricLrc,
  parseLyricDurationLrc, LyricsData (title, artist, lines, toLrcLines,
  extractFromTo), LyricsLineData (time, text, parts, toLrcLine),
  LyricsLineSingleContent vs LyricsLineMultiContent, LyricsPartData,
  lrcFormatDuration and the package:tekaly_lyrics/lyrics.dart /
  utils/duration_helper.dart imports.
---

# Parsing and writing LRC lyrics (tekaly_lyrics)

`tekaly_lyrics` parses [LRC](https://en.wikipedia.org/wiki/LRC_(file_format))
lyrics — line timed `[00:12.34]text` and word timed
`[00:12.34]<00:12.34>Some <00:12.90>body` — into a small immutable model, and
writes that model back as LRC. It is pure Dart: no `dart:io`, no UI.

## Guidelines

* Dependency (git, private repo, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_lyrics:
      git:
        url: https://github.com/tekartikprj/music
        path: packages/lyrics
  ```
* Imports: `package:tekaly_lyrics/lyrics.dart` for the parser and the model;
  `package:tekaly_lyrics/utils/duration_helper.dart` for
  `lrcFormatDuration(duration)` and the duration extensions on `num` (`40.ms`,
  `2.s`, `3.mn`); `package:tekaly_lyrics/example/lyrics_example.dart` for the
  two sample songs `lrcDemo1` and `lrcUneSourisVerte`. Never import
  `package:tekaly_lyrics/src/...`: `parseLyricLine`, `parseLyricLineContent`
  and `findTime` are `@visibleForTesting` internals.
* `parseLyricLrc(String input)` returns a `LyricsData` and never throws: it
  keeps `[ti:...]` as `title` and `[ar:...]` as `artist`, turns every
  `[<digits>...]` tag into a line, and silently drops everything else
  (`[al:]`, `[length:]`, `[by:]`, comments, blank lines). `LyricsData.duration`
  is *not* filled by the parser — set it yourself if you need it.
* Each `LyricsLineData` exposes `time`, `text` and `parts`, and its `content`
  is one of two classes — test with `is` before casting:
  `LyricsLineSingleContent` (plain line, one `part` spanning the whole text)
  or `LyricsLineMultiContent` (word timed, `parts` in order plus the joined
  `text`). A trailing `<00:02>` with no text after it produces a last
  `LyricsPartData` with an empty `text`: that is the line's end marker, keep
  it, it drives the end of the last word.
* `LyricsPartData(time:, text:)` has value equality, so parts and part lists
  can be compared directly in tests. Part texts keep one trailing space when
  the source had one, which is what makes `parts.map((p) => p.text).join()`
  equal to the line `text`.
* Write back with `LyricsDataExt.toLrcLines()` (one string per line) or
  `LyricsLineDataExt.toLrcLine()`. The output is stable:
  `parseLyricLrc(lrc).toLrcLines()` round-trips a normalised LRC body (tags
  are *not* re-emitted — prepend `[ti:...]` / `[ar:...]` yourself). The first
  part's `<time>` is omitted when it equals the line time.
* `LyricsDataExt.extractFromTo({from, to})` returns a new `LyricsData` with
  the lines whose `time` is `>= from` and `<= to` (either bound may be null).
  It assumes the lines are ordered by time (the parser output is) and it
  drops `title`/`artist`, so re-attach them if you keep them.
* Durations: `parseLyricDurationLrc(token)` accepts `mm:ss`, `mm:ss.f`,
  `mm:ss.ff`, `mm:ss.fff` and bare `ss.ff`, ignores a trailing `]` or `>`,
  and returns `Duration.zero` when it cannot parse — check the input yourself
  when a zero would be wrong. `lrcFormatDuration(duration)` formats back as
  `MM:SS.cc` (hundredths, truncated); it wraps past 60 minutes, so do not use
  it for hour-long medleys.
* The model is plain Dart objects, ideal for a Flutter widget or a CLI. For
  positioning the current word inside a line (karaoke highlight) and for
  playback, use the `tekaly-lyrics-karaoke-sync` skill of this package
  ([SKILL.md](../tekaly-lyrics-karaoke-sync/SKILL.md)).
* Tests: `dart test`.

## Examples

### Parse a song and walk its lines

```dart
import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';

void main() {
  var data = parseLyricLrc(lrcUneSourisVerte);
  print('${data.title} - ${data.artist} (${data.lines.length} lines)');

  for (var line in data.lines) {
    var content = line.content;
    if (content is LyricsLineMultiContent) {
      // Word timed line: one part per word.
      var words = content.parts
          .map((part) => '${lrcFormatDuration(part.time)}:${part.text}')
          .join(' ');
      print('${lrcFormatDuration(line.time)} $words');
    } else if (content is LyricsLineSingleContent) {
      print('${lrcFormatDuration(line.time)} ${content.part.text}');
    }
  }
}
```

### Cut an excerpt and write it back as LRC

```dart
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';

/// LRC body of [lrc] between [from] and [to], title and artist kept.
String excerpt(String lrc, {Duration? from, Duration? to}) {
  var data = parseLyricLrc(lrc);
  var extract = data.extractFromTo(from: from, to: to);
  return [
    if (data.title != null) '[ti:${data.title}]',
    if (data.artist != null) '[ar:${data.artist}]',
    ...extract.toLrcLines(),
  ].join('\n');
}

void main() {
  var lrc = '[ti:Demo]\n'
      '[00:00.00]Zero\n'
      '[00:01.00]One\n'
      '[00:02.00]Two<00:03.00>Three\n';
  print(excerpt(lrc, from: 1.s));
  // [ti:Demo]
  // [00:01.00]One
  // [00:02.00]Two<00:03.00>Three
}
```

### Build word timed lyrics programmatically

```dart
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';

/// One word timed line, words evenly spread between [start] and [end].
LyricsLineData buildLine(List<String> words, Duration start, Duration end) {
  var step = (end - start) ~/ words.length;
  var parts = <LyricsPartData>[];
  for (var i = 0; i < words.length; i++) {
    var isLast = i == words.length - 1;
    parts.add(
      LyricsPartData(time: start + step * i, text: isLast ? words[i] : '${words[i]} '),
    );
  }
  // Empty last part: end of the line.
  parts.add(LyricsPartData(time: end, text: ''));
  return LyricsLineData(
    content: LyricsLineMultiContent(
      time: start,
      parts: parts,
      text: parts.map((part) => part.text).join(),
    ),
  );
}

void main() {
  var data = LyricsData(
    title: 'Demo',
    artist: 'Me',
    lines: [
      buildLine(['Hello', 'my', 'friend'], 1.s, 4.s),
      buildLine(['Time', 'to', 'go'], 5.s, 7.s),
    ],
  );
  print(data.toLrcLines().join('\n'));
}
```

### Test a parser round trip

```dart
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:test/test.dart';

void main() {
  test('round trip', () {
    var lrc = ['[00:00.00]Zero', '[00:01.00]One<00:02.00>Two'];
    expect(parseLyricLrc(lrc.join('\n')).toLrcLines(), lrc);
  });
  test('word timed line', () {
    var data = parseLyricLrc('[ti: Somebody]\n[00:00.02] <00:00.04>So<00:00.16>me body');
    expect(data.title, 'Somebody');
    var content = data.lines.first.content as LyricsLineMultiContent;
    expect(content.time, 20.ms);
    expect(content.text, 'Some body');
    expect(content.parts.first, LyricsPartData(time: 40.ms, text: 'So'));
  });
  test('durations', () {
    expect(parseLyricDurationLrc('00:41.50'), 41500.ms);
    expect(parseLyricDurationLrc('nope'), Duration.zero);
    expect(lrcFormatDuration(41500.ms), '00:41.50');
  });
}
```
