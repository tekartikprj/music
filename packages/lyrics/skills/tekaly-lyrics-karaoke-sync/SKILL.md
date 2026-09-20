---
name: tekaly-lyrics-karaoke-sync
description: >-
  Use when highlighting or playing back timed lyrics in sync with a position
  with tekaly_lyrics: LocatedLyricsData (locateItemInfo, getLine, getItemInfo,
  getNextRef, getPreviousRef), LocatedLyricsDataItemRef (before, lineBefore,
  lineIndex, partIndex), LocatedLyricsDataItemInfo (start, end, text),
  LocatedLyricsDataLine/LocatedLyricsDataPart, the
  package:tekaly_lyrics/utils/lyrics_data_located.dart import, and the
  console player LyricsDataPlayerIo (load, resume, done, onPlayText) from
  package:tekaly_lyrics/lyrics_io.dart.
---

# Karaoke positioning and playback (tekaly_lyrics)

`LocatedLyricsData` decorates a parsed `LyricsData` with character positions,
so that for any playback position you get the current line, the current word
and its `start`/`end` offsets inside the line text — everything a karaoke
highlight needs. `lyrics_io.dart` adds a console player that writes the words
to `stdout` as they come.

## Guidelines

* Dependency (git, private repo, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_lyrics:
      git:
        url: https://github.com/tekartikprj/music
        path: packages/lyrics
  ```
* Import `package:tekaly_lyrics/utils/lyrics_data_located.dart`: it
  re-exports `lyrics.dart` (so `parseLyricLrc`, `LyricsData`... come with it)
  and adds `LocatedLyricsData`, `LocatedLyricsDataLine`,
  `LocatedLyricsDataPart`, `LocatedLyricsDataItemRef` and
  `LocatedLyricsDataItemInfo`. Add
  `package:tekaly_lyrics/utils/duration_helper.dart` for `40.ms` / `2.s` /
  `lrcFormatDuration`. See the `tekaly-lyrics-lrc-parse` skill of this
  package ([SKILL.md](../tekaly-lyrics-lrc-parse/SKILL.md)) for the parsing
  and model side.
* Build it once per song: `LocatedLyricsData(lyricsData: parseLyricLrc(lrc))`.
  It walks every line, lays the parts out end to end and stores each part's
  `start` / `end` index in the line `text`, so offsets are valid only while
  you display exactly `line.text`. Rebuild it when the lyrics change; do not
  mutate `lines` afterwards.
* `locateItemInfo(position)` is the main entry point: it binary-searches the
  line, then the part, and returns a `LocatedLyricsDataItemInfo` with `ref`,
  `start`, `end` and `text` (the current word). Before the first line it
  returns the `LocatedLyricsDataItemRef.before()` ref (`lineIndex == -1`,
  `partIndex == -1`) with `start == end == 0` and an empty `text` — always
  test `ref.lineIndex < 0` before indexing anything.
* After the last timed part it keeps returning that last part, so it never
  tells you the song is over; compare `position` with your own end time (or
  with `LyricsData.duration`) when you need an "after the end" state. An
  empty `text` with a valid ref is the end-of-line marker part produced by a
  trailing `<00:02>` tag: it is the right moment to stop highlighting.
* The lines and the parts must be ordered by time (they are, straight out of
  `parseLyricLrc`), otherwise the search returns nonsense.
* Highlight with the offsets, not with string search:
  `line.text.substring(0, info.end)` is the sung part,
  `line.text.substring(info.start, info.end)` the current word. Get the line
  with `getLine(info.ref.lineIndex)` (`LocatedLyricsDataLine` exposes `time`,
  `text`, `lineData` and the located `parts`).
* Navigation without a position: `getNextRef(ref)` / `getPreviousRef(ref)`
  walk the parts, stepping through the `LocatedLyricsDataItemRef.lineBefore(
  lineIndex)` ref (`partIndex == -1`) at each line boundary — that ref means
  "line started, no word yet" and `getItemInfo` maps it to an empty info.
  `getNextRef` clamps on the very last part, `getPreviousRef` on
  `before()`. Refs are `Comparable` and have value equality, so they can be
  stored as "what is currently highlighted" and compared to avoid redundant
  repaints.
* Call `locateItemInfo` on every tick (a Flutter `Ticker`, a periodic timer
  or an audio player position stream) and repaint only when `info.ref`
  changed. The lookup allocates little but is not free: keep the
  `LocatedLyricsData` in the state, not in `build`.
* `LocatedLyricsData.devDump()` is annotated `@doNotSubmit`: use it while
  debugging, remove it before committing.
* Playback: `package:tekaly_lyrics/lyrics_io.dart` gives `LyricsDataPlayerIo`
  (`dart:io`, VM only). `player.load(lyricsData)`, `player.resume()`, then
  `await player.done`; it writes each part to `stdout` as its time comes
  (plus a `'\n'` text event at the start of every line), driven by a midi
  player (`tekartik_midi`) that starts counting at the first tick. Override
  `onPlayText(String text)` in a subclass to send the words somewhere else. There is no `pause`, no `seek` and no position getter: for
  a real UI, drive `LocatedLyricsData` from your audio player's position
  instead.
* Tests: `dart test`; assert on `info.ref.lineIndex` / `info.ref.partIndex`
  and `info.text` (see `test/located_lyrics_data_test.dart`).

## Examples

### Highlight the current word

```dart
import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

/// The line text with the sung part wrapped in brackets, '' before the start.
String highlight(LocatedLyricsData located, Duration position) {
  var info = located.locateItemInfo(position);
  var lineIndex = info.ref.lineIndex;
  if (lineIndex < 0) {
    return '';
  }
  var text = located.getLine(lineIndex).text;
  return '[${text.substring(0, info.end)}]${text.substring(info.end)}';
}

void main() {
  var located = LocatedLyricsData(
    lyricsData: parseLyricLrc(
      '[00:01.00]<00:01.00>Hello <00:02.00>my <00:03.00>friend<00:04.00>\n'
      '[00:05.00]Time to go',
    ),
  );
  for (var position in [500.ms, 1.s, 2.s, 3.s, 4.s, 5.s]) {
    print('${lrcFormatDuration(position)} ${highlight(located, position)}');
  }
}
```

### Repaint only when the highlighted word changes

```dart
import 'dart:async';

import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

/// Polls [position] and calls [onItem] only when the current word changes.
StreamSubscription<void> followLyrics(
  LocatedLyricsData located,
  Duration Function() position,
  void Function(LocatedLyricsDataItemInfo info) onItem, {
  Duration period = const Duration(milliseconds: 50),
}) {
  LocatedLyricsDataItemRef? current;
  return Stream<void>.periodic(period).listen((_) {
    var info = located.locateItemInfo(position());
    if (info.ref != current) {
      current = info.ref;
      onItem(info);
    }
  });
}
```

### Step through the words without a clock

```dart
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

void main() {
  var located = LocatedLyricsData(
    lyricsData: parseLyricLrc('[00:01]Hey<00:02>Joe<00:03>\n[00:05]Bye'),
  );
  var ref = LocatedLyricsDataItemRef.before();
  while (true) {
    var next = located.getNextRef(ref);
    if (next == ref) {
      break; // getNextRef clamps on the last part.
    }
    ref = next;
    var info = located.getItemInfo(ref);
    print('$ref [${info.start}..${info.end}] "${info.text}"');
  }
}
```

### Play the lyrics to the console, or anywhere else

```dart
import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/lyrics_io.dart';

/// Collects the words instead of writing them to stdout.
class CollectLyricsPlayer extends LyricsDataPlayerIo {
  final words = <String>[];

  @override
  void onPlayText(String text) {
    words.add(text);
  }
}

Future<void> main() async {
  var data = parseLyricLrc(lrcDemo1);

  var player = LyricsDataPlayerIo();
  player.load(data);
  player.resume();
  await player.done;

  var collect = CollectLyricsPlayer();
  collect.load(data);
  collect.resume();
  await collect.done;
  print('\n${collect.words.length} text events');
}
```

### Test the positioning

```dart
import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';
import 'package:test/test.dart';

void main() {
  test('locate', () {
    var located = LocatedLyricsData(
      lyricsData: parseLyricLrc('[00:01]Hey<00:03>\n[00:05]Joe'),
    );
    expect(located.locateItemInfo(999.ms).ref, LocatedLyricsDataItemRef.before());
    var info = located.locateItemInfo(1.s);
    expect(info.ref, LocatedLyricsDataItemRef(0, 0));
    expect(info.text, 'Hey');
    expect([info.start, info.end], [0, 3]);
    // The empty part of the trailing <00:03> tag: line done.
    expect(located.locateItemInfo(4.s).text, '');
    expect(located.locateItemInfo(5.s).ref, LocatedLyricsDataItemRef(1, 0));
  });
}
```
