# tekaly_chordpro

Converts plain song text, a line of chords above each line of lyrics, into
[ChordPro](https://www.chordpro.org/chordpro/) text, the chords inlined at
their column (`[C]Hello my[G] friend`). One way only: no ChordPro parser, no
song model, no renderer.

## Getting started

Not on pub.dev, a git dependency (pure Dart: VM, Flutter, web):

```yaml
dependencies:
  tekaly_chordpro:
    git:
      url: https://github.com/tekartikprj/music
      path: packages/chordpro
```

```dart
import 'package:tekaly_chordpro/chordpro.dart';

void main() {
  print(textToChordPro('''
[Verse 1]
C       G       Am
Hello my friend, again'''));
  // {start_of_verse: Verse 1}
  // [C]Hello my[G] friend,[Am] again
  // {end_of_verse}
}
```

`textToChordPro(String)` converts a whole text,
`textLinesToChordProLines(List<String>)` a list of lines (what
`File.readAsLines()` gives).

## How lines are read

* A chord line: its space separated words parse as chords (one word is
  enough on a one word line, otherwise at least half of them). `C`, `Am`,
  `Am7`, `C7`, `Cmaj7`, `Cdim`, `Csus4`, `F#m`, `Bb` parse; slash chords
  (`G/B`) and `N.C.` do not, but are written as chords on a line that is
  mostly chords.
* A chord line followed by a lyric line: merged, each chord at its column.
  Columns are characters: the source must use spaces, not tabs.
* A chord line followed by another chord line (or at the end): written alone,
  `[Am] [C]`.
* `[Verse 1]`, `[Chorus]`, `[Bridge]` alone on a line: a section,
  `{start_of_verse: Verse 1}`; any other name (`[Intro]`) is a bridge. The
  section ends at the next header, at the first line without chords, or at
  the end.
* Everything else is copied, trailing spaces removed.

## Common mistakes

* Do not feed ChordPro back in: a line starting with `[` and holding a `]` is
  a section header, the rest of the line is dropped (`[C]Hello` becomes
  `{start_of_bridge: C}`).
* A short lyric line made of chord names (`A man`) is read as chords.
* A lyric line without chords in the middle of a verse ends the section.

Agent skill: [tekaly-chordpro-convert](skills/tekaly-chordpro-convert/SKILL.md).
