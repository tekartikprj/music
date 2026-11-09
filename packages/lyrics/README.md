# tekaly_lyrics

Parses and writes [LRC](https://en.wikipedia.org/wiki/LRC_(file_format))
lyrics, line timed (`[00:12.34]text`) or word timed ("enhanced LRC",
`[00:12.34]<00:12.34>Some <00:12.90>body`), and finds the line and the word
sung at a position (karaoke). Pure Dart: VM, web, Flutter.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekaly_lyrics:
    git:
      url: https://github.com/tekartikprj/music
      path: packages/lyrics
```

```dart
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

void main() {
  var lyrics = parseLyricLrc('''
[ti:Demo]
[00:01.00]<00:01.00>Hello <00:02.00>my <00:03.00>friend<00:04.00>
[00:05.00][00:09.00]Time to go
''');
  print('${lyrics.title}: ${lyrics.lines.length} lines');

  // The word sung at 2.5 s, and where it is in its line.
  var located = LocatedLyricsData(lyricsData: lyrics);
  var info = located.locateItemInfo(const Duration(milliseconds: 2500));
  var line = located.getLine(info.ref.lineIndex);
  print('${line.text}: "${info.text}" at ${info.start}..${info.end}');
}
```

A runnable example: [example/main.dart](example/main.dart).

## What to use

* `package:tekaly_lyrics/lyrics.dart`: `parseLyricLrc` gives a `LyricsData`
  (`title`, `artist`, `lines` sorted by time). Each `LyricsLineData` has a
  `time`, a `text` and its `parts` (one per timed word, or one for the whole
  line). `toLrcLines()` writes it back.
* `package:tekaly_lyrics/utils/lyrics_data_located.dart` (exports
  `lyrics.dart`): `LocatedLyricsData` and `locateItemInfo(position)`, the
  current line and word with their offsets in the line text, for a
  highlight driven by your audio player's position.
* `package:tekaly_lyrics/utils/duration_helper.dart`: `lrcFormatDuration`,
  `1.s`, `40.ms`.
* `package:tekaly_lyrics/lyrics_io.dart`: `LyricsDataPlayerIo` writes the
  words to stdout as their time comes (VM only, a demo).

## Good to know

* `parseLyricLrc` never throws: unknown tags and lines without a time are
  dropped, a time it cannot read is 0.
* A line with several time tags (`[00:05.00][00:09.00]Chorus`) is one line
  per time. Word times are absolute: do not combine them with several line
  tags.
* Before the first line `locateItemInfo` returns
  `LocatedLyricsDataItemRef.before()` (`lineIndex` -1): test it before
  `getLine`. After the last word it keeps returning that word.
* `LocatedLyricsData` expects lines sorted by time: sort them when you build
  a `LyricsData` by hand.
