---
name: tekaly-chordpro-convert
description: >-
  Use when converting plain "chords above the lyrics" song text into the
  ChordPro format with tekaly_chordpro: textToChordPro(String),
  textLinesToChordProLines(List<String>), the
  package:tekaly_chordpro/chordpro.dart import, how chord lines are detected
  (tryParseChord from tekaly_music_note), how [Verse 1] / [Chorus] headers
  become {start_of_verse: ...} / {end_of_chorus} directives, and why
  ChordPro input must not be fed back in.
---

# Text to ChordPro conversion (tekaly_chordpro)

`tekaly_chordpro` converts plain song text — a line of chords above a line of
lyrics, optional `[Section]` headers — into
[ChordPro](https://www.chordpro.org/chordpro/) text, with the chords inlined
as `[C]` at the column where they sat. It is a one-way converter: there is no
ChordPro parser, no song model and no renderer in this package.

## Guidelines

* Dependency (git, public repo, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_chordpro:
      git:
        url: https://github.com/tekartikprj/music
        path: packages/chordpro
  ```
  It pulls `tekaly_music_note` (same repo, `path: packages/music_note`) for
  chord recognition.
* One import, `package:tekaly_chordpro/chordpro.dart`, two functions:
  `String textToChordPro(String text)` and
  `List<String> textLinesToChordProLines(List<String> lines)`. Everything
  else is private. `textToChordPro` is `LineSplitter.split` +
  `textLinesToChordProLines` + `join('\n')`; use the list form when you read
  a file with `readAsLines()` or want to post-process line by line. Both are
  synchronous, pure and platform-neutral (no `dart:io`).
* Chord line detection decides everything: a line is a chord line when its
  space-separated tokens parse as chords — one token is enough for a
  one-token line, otherwise at least half of the tokens must parse.
  Parsing is `tryParseChord` from `tekaly_music_note`: `C`, `Am`, `Am7`,
  `Amin7`, `C7`, `Cmaj7`, `Cdim`, `Csus4`, `Cadd9`, `F#m`, `Bb`, `Ebmin7b5`
  work; slash chords (`G/B`), `N.C.` and lowercase names do **not**. Every
  word of a chord line is written as a chord, the unparsed ones included
  (`C G/B Am` gives `[C] [G/B] [Am]`), and a short lyric line made of chord
  names (`A man`) is read as a chord line.
* Chord line followed by a lyric line: the two are merged into one line and
  each chord is inserted at its column, `[C]Hello my[G] friend`. Alignment is
  by character position, so the source must use spaces (never tabs) and a
  monospaced layout. A chord past the end of the lyric text ends up appended
  at the end of the line.
* Chord line followed by another chord line, or last line of the input: it
  becomes a bracketed chord-only line, `[Am] [C]  [E]` (the spacing between
  chords is kept). Note that an empty line right after a chord line is
  consumed as its (empty) lyric line.
* A line starting with `[` and holding a `]` is a section header (one
  without `]` is copied as a plain line): `[Verse 1]` gives
  `{start_of_verse: Verse 1}`, `[Chorus]` `{start_of_chorus: Chorus}`; the
  first word decides the type, lowercased, and anything that is not `verse`,
  `chorus` or `bridge` (`[Intro]`, `[Solo]`...) falls back to `bridge` while
  keeping its original label. The section is closed with
  `{end_of_<type>}` by the next header, by the first plain (non chord) line
  or by the end of the input: a lyric line without chords in the middle of a
  verse ends it.
* Do not feed ChordPro (or any text with inline `[C]` chords) back in: a
  line starting with `[` is read as a section header and **the rest of the
  line is dropped** (`[C]Hello world` becomes `{start_of_bridge: C}`).
  Convert once, from the plain source, and store the result.
* Everything else is passed through untouched apart from `trimRight()`:
  blank lines, `{...}` markers, titles, tab notation. The converter never
  emits `{title:}` / `{artist:}` directives — add those yourself around the
  result.
* Tests: `dart test`; assert on `textLinesToChordProLines` (see
  `test/chordpro_test.dart`), it is easier to read than the joined string.

## Examples

### Convert a song in memory

```dart
import 'package:tekaly_chordpro/chordpro.dart';

void main() {
  var text = '''
[Verse 1]
C       G       Amin
Hello my friend, again
F         C
Time to go home

[Chorus]
C  G
''';
  print(textToChordPro(text));
  // {start_of_verse: Verse 1}
  // [C]Hello my[G] friend,[Amin] again
  // [F]Time to go[C] home
  // {end_of_verse}
  //
  // {start_of_chorus: Chorus}
  // [C]  [G]
  // {end_of_chorus}
}
```

### Convert a directory of text files

```dart
import 'dart:io';

import 'package:path/path.dart';
import 'package:tekaly_chordpro/chordpro.dart';

Future<void> main() async {
  var srcDir = join('.local', 'in');
  var dstDir = join('.local', 'out');
  await Directory(dstDir).create(recursive: true);
  await for (var entity in Directory(srcDir).list()) {
    if (entity is! File || extension(entity.path) != '.txt') {
      continue;
    }
    var lines = await entity.readAsLines();
    var outLines = textLinesToChordProLines(lines);
    var name = '${basenameWithoutExtension(entity.path)}.cho';
    await File(join(dstDir, name)).writeAsString(outLines.join('\n'));
  }
}
```

### Add directives around the converted body

```dart
import 'package:tekaly_chordpro/chordpro.dart';

/// Full ChordPro document for a song, directives included.
String toChordProDocument({
  required String title,
  required String artist,
  required List<String> textLines,
}) {
  return [
    '{title: $title}',
    '{artist: $artist}',
    '',
    ...textLinesToChordProLines(textLines),
  ].join('\n');
}

void main() {
  print(
    toChordProDocument(
      title: 'Demo',
      artist: 'Me',
      textLines: ['[Intro]', 'Amin  G'],
    ),
  );
  // {title: Demo} / {artist: Me} / {start_of_bridge: Intro} /
  // [Amin]  [G] / {end_of_bridge}
}
```

### Unit test the conversion of a tricky source

```dart
import 'package:tekaly_chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('chords over lyrics', () {
    expect(textLinesToChordProLines(['E D  E', 'I']), ['[E]I [D]  [E]']);
    expect(textLinesToChordProLines(['E  D', 'Id t']), ['[E]Id [D]t']);
  });
  test('section and chord only line', () {
    expect(textLinesToChordProLines(['[Intro]', 'Am C  E']), [
      '{start_of_bridge: Intro}',
      '[Am] [C]  [E]',
      '{end_of_bridge}',
    ]);
  });
  test('lowercase words are not chords', () {
    // 'am' does not parse as a chord, the line is copied as is.
    expect(textLinesToChordProLines(['am i', 'words']), [
      'am i',
      'words',
    ]);
  });
}
```
