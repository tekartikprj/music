---
name: tekaly-music-note-model
description: >-
  Use when modelling keys, notes, intervals and chords in Dart with
  tekaly_music_note: Key (c, cSharp, dFlat, allKeys, keyAtOffset,
  keyAtInterval, isAltered, floor, ceil, transpose), Note (Note.from, key,
  octave, noteAtInterval, c4, a4), Interval/RawInterval (root, major3rd,
  perfectFifth, minor7th, major9th), ChordPattern (major, minor, major7,
  dim7, sus4, allPatterns, checkChordPattern), Chord (containsKey,
  findInterval, transpose), the name tables (keyNames, sharpKeyNames,
  intervalShortNames, chordPatternNames) and the parsers tryParseKey,
  tryParseChordPattern, tryParseChord.
---

# Keys, notes, intervals and chords (tekaly_music_note)

`tekaly_music_note` is a tiny dependency-free model of western music theory:
everything is a semitone count. `Key` is a pitch class (0..11), `Note` is an
absolute pitch (its `semitones` is the MIDI note number), `Interval` is a
distance, `ChordPattern` is a list of intervals and `Chord` is a key plus a
pattern.

## Guidelines

* Dependency (git, private repo, not on pub.dev):
  ```yaml
  dependencies:
    tekaly_music_note:
      git:
        url: https://github.com/tekartikprj/music
        path: packages/music_note
      version: '>=0.1.0'
  ```
* One import for everything: `package:tekaly_music_note/music_note.dart`.
  Only what it re-exports is public API; do not import `src/` files.
* `Key(int semitones)` normalises modulo 12 (`Key(13) == Key(1)`,
  `Key(-13).semitones == 11`). Use the `const` singletons `c`, `cSharp`, `d`,
  `dSharp`, `e`, `f`, `fSharp`, `g`, `gSharp`, `a`, `aSharp`, `b` and their
  flat aliases `dFlat`, `eFlat`, `gFlat`, `aFlat`, `bFlat` (`dFlat` *is*
  `cSharp`: the model is enharmonic, there is no spelling). `allKeys`,
  `allUnalteredKeys` and `allAlteredKeys` are const lists.
* Move around with `keyAtOffset(semitones)` or `keyAtInterval(interval)`;
  `KeyExtension` adds `transpose(semitones)`, `transposeUp`, `transposeDown`,
  and `KeyListExtension.transpose(semitones)` transposes a whole list.
  `isAltered` is true for the 5 black keys, `floor` / `ceil` round an altered
  key down / up to the neighbouring natural key.
* `Note` is octave `-1` based, so `C0` is 12 and `a4.semitones` is 69 (MIDI).
  Build with `Note.from(key, octave)` or `Note(midiNumber)`; read back `key`
  and `octave`. Ready-made notes: `c0`, `c2`..`e5` (`c3`, `fSharp3`, `c4`,
  `a4`, ...) — these are `final`, not `const`. Move with
  `noteAtOffset(semitones)` / `noteAtInterval(interval)`,
  `noteFrom.getNoteInterval(noteTo)` gives the `RawInterval` between two
  notes (it can be negative or larger than an octave).
* Intervals: `RawInterval(semitones)` is the raw distance, `Interval(name,
  semitones)` is a named one. Named constants: `root`, `minor2nd`,
  `major2nd`, `minor3rd`, `major3rd`, `perfect4th`, `tritone`, `fifthFlat`,
  `perfectFifth` (alias `perfect5th`), `fifthSharp`, `minor6th`, `major6th`,
  `seventhFlatFlat`, `minor7th`, `major7th`, `octave`, `minor9th`,
  `major9th`, `perfect11th`, `major13th`.
* Equality is by type *and* semitones: `Interval` also compares its `name`,
  so `RawInterval(4) != major3rd` and `fifthFlat != tritone` even though both
  are 6 semitones. Use `intervalSimilar(a, b)` (octave-insensitive) or
  `semitonesSameKey(s0, s1)` when only the pitch class matters, and
  `positiveKeyDiff(from, to)` for the 0..11 distance between two keys.
* `SemitonesBase` (the base of `Key`, `Note`, `RawInterval`) is
  `Comparable` and defines `<`, `<=`, `>`, `>=` on `semitones`, so notes sort
  naturally. Keys compare as pitch classes, not as pitches.
* `ChordPattern(intervals)` takes a `List<Interval>?` (the field is
  nullable: `pattern.intervals!` is the normal read). Constants: `major`,
  `minor`, `major7`, `minor7`, `major7M`, `minor7M`, `major6`, `minor6`,
  `dim`, `dim7`, `aug`, `sus2`, `sus4`, `sevenSus4`, `major9`, `minor9`,
  `major9M`, `majorAdd9`, `minorAdd9`, `major6_9`, `minor6_9`, `major7_b5`,
  `minor7_b5`, `major7_sharp5`, `major7_b9`, `minor7_b9`, `major9_b5`,
  `major_b5`, `major11`, `minor11`, `major13`, `minor13`. `allPatterns`
  iterates all 32 of them (it is `chordPatternNames.keys`).
  `findInterval(rawInterval)` / `findNoteDiff(semitones)` return the matching
  `Interval` of the pattern (pitch class match) or null.
* `checkChordPattern(pattern)` throws `ArgumentError` for a custom pattern
  that is null/empty, has fewer than 2 intervals, is not strictly ascending,
  or contains `octave`. Call it once when you build a pattern from user data.
* `Chord(key, pattern)` takes both positionally. `containsKey(key)` and
  `findInterval(key)` walk the pattern intervals (they throw on a chord built
  with a null pattern). `ChordExtension.transpose(semitones)` returns a new
  chord, `ChordListExtension.transpose(semitones)` a new list.
* Names: `keyNames` (flat spelling, what `Key.toString()` uses),
  `flatKeyNames`, `sharpKeyNames` are 12-entry `List<String>` indexed by
  `key.semitones`; `intervalShortNames` / `intervalLongNames` are
  `List<String?>` indexed by semitones, with null holes above the octave — do
  not assume a non-null name. `chordPatternNames` maps pattern to display
  name.
* Parsing is alias-table based and narrow, so always handle the null:
  `tryParseKey(name)` takes one of `C D E F G A B` with an optional `#` or
  `b` (both spellings work, `tryParseKey('Ab') == tryParseKey('G#')`).
  `tryParseChordPattern(suffix)` only knows the `''`/`M`/`m`/`maj`/`min`
  family: `'min7'`, `'maj7M'`, `'min7b5'`, `'majadd9'`, `'maj6/9'`... It does
  **not** know the short forms `'m7'`, `'7'`, `'dim'`, `'sus4'` or `'aug'`,
  so `tryParseChord('Am7')` is null while `tryParseChord('Amin7')` and
  `tryParseChord('C#maj7')` are not. Map your own input syntax onto the
  `ChordPattern` constants instead of relying on the table for user text.
* Formatting is intentionally crude: `Key.toString()` always prints the flat
  name (`cSharp.toString()` is `'Db'`) and `ChordPattern.toString()` appends
  the interval short names (`'Major[R, M3, 5]'`). Render chords yourself from
  `sharpKeyNames` / `chordPatternNames` when the output matters.
* No i/o, no Flutter, no platform code: everything runs on the VM and on the
  web. Run the package tests with `dart test`.

## Examples

### Transposing a song's keys and chords

```dart
import 'package:tekaly_music_note/music_note.dart';

void main() {
  var progression = [
    Chord(c, major),
    Chord(a, minor),
    Chord(f, major7M),
    Chord(g, sevenSus4),
  ];

  // Up a whole tone: D, Bm, G7M, A7sus4
  for (var chord in progression.transpose(2)) {
    print('${chord.key} ${chordPatternNames[chord.pattern]}');
  }

  // Same, one chord at a time, sharp spelling.
  var chord = Chord(bFlat, minor7).transpose(1);
  print('${sharpKeyNames[chord.key.semitones]}m7'); // Bm7
}
```

### Parsing chord text and inspecting its keys

```dart
import 'package:tekaly_music_note/music_note.dart';

/// Keys of a chord written as text ('Am7', 'C#', 'Gmaj7'), null if unknown.
List<Key>? chordKeys(String text) {
  var chord = tryParseChord(text);
  if (chord == null) {
    return null;
  }
  return [
    for (var interval in chord.pattern!.intervals!)
      chord.key.keyAtInterval(interval),
  ];
}

void main() {
  print(chordKeys('Amin7')); // [A, C, E, G]
  print(chordKeys('C#')); // [Db, F, Ab]
  print(chordKeys('Am7')); // null: 'm7' is not a known suffix, 'min7' is

  var cMajor = Chord(c, major);
  print(cMajor.containsKey(e)); // true
  print(cMajor.findInterval(g)); // 5 (perfectFifth)
  print(cMajor.findInterval(d)); // null
}
```

### Notes, octaves and intervals

```dart
import 'package:tekaly_music_note/music_note.dart';

void main() {
  var root = Note.from(c, 4); // middle C
  print('$root ${root.semitones}'); // C4 60
  print(a4.semitones); // 69, the midi number of A440

  var fifth = root.noteAtInterval(perfectFifth);
  print('$fifth ${fifth.key} ${fifth.octave}'); // G4 G 4

  // Distance between two notes, and the same distance as a pitch class.
  var distance = c3.getNoteInterval(e4);
  print(distance.semitones); // 16
  print(intervalSimilar(distance, major3rd)); // true, 16 % 12 == 4
  print(positiveKeyDiff(c, e)); // 4

  // SemitonesBase is Comparable and ordered.
  var notes = [e4, c3, fSharp3]..sort();
  print(notes); // [C3, Gb3, E4]
  print(c4 > c3); // true
}
```

### Building and validating a custom chord pattern

```dart
import 'package:tekaly_music_note/music_note.dart';

ChordPattern buildPattern(List<Interval> intervals) {
  var pattern = ChordPattern(intervals);
  // Throws ArgumentError on unordered, too short or octave-containing input.
  checkChordPattern(pattern);
  return pattern;
}

void main() {
  var power = buildPattern([root, perfectFifth]);
  print(power.findInterval(RawInterval(19)) == perfectFifth); // true
  print(power.findNoteDiff(4)); // null, no third

  // Name the known patterns only.
  for (var pattern in allPatterns) {
    print('${chordPatternNames[pattern]}: ${pattern.intervals!.length} notes');
  }
}
```

### Test against the model

```dart
import 'package:tekaly_music_note/music_note.dart';
import 'package:test/test.dart';

void main() {
  test('transpose a minor progression', () {
    var progression = [Chord(a, minor), Chord(e, major7)];
    expect(progression.transpose(3), [Chord(c, minor), Chord(g, major7)]);
  });
  test('altered keys', () {
    expect(cSharp.isAltered, isTrue);
    expect(cSharp.floor, c);
    expect(cSharp.ceil, d);
    expect(allKeys.transpose(1).first, cSharp);
  });
}
```
