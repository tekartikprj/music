import 'package:tekaly_music_note/music_note.dart';
import 'package:tekaly_music_note/src/names.dart';

import 'package:test/test.dart';

import 'chord_test.dart';

void main() {
  group('keyNames', () {
    test('size', () {
      expect(keyNames.length, octaveNoteCount);
    });
    test('tryParseKey', () {
      for (var map in [
        nonAlteredKeyNames,
        flatOnlyKeyNames,
        sharpOnlyKeyNames,
      ]) {
        map.forEach((key, value) {
          expect(tryParseKey(value), key);
        });
      }
    });
    test('tryParseChord', () {
      expect(tryParseChord('C'), cMajor);
      expect(tryParseChord('Cm'), cMinor);
    });
    test('tryParseChord short forms', () {
      expect(tryParseChord('C7sus4'), Chord(c, sevenSus4));
      expect(tryParseChord('Am7'), Chord(a, minor7));
      expect(tryParseChord('D7'), Chord(d, major7));
      expect(tryParseChord('G7'), Chord(g, major7));
      expect(tryParseChord('Cdim'), Chord(c, dim));
      expect(tryParseChord('Cdim7'), Chord(c, dim7));
      expect(tryParseChord('Csus4'), Chord(c, sus4));
      expect(tryParseChord('Csus2'), Chord(c, sus2));
      expect(tryParseChord('Caug'), Chord(c, aug));
      expect(tryParseChord('Bm7b5'), Chord(b, minor7_b5));
      expect(tryParseChord('C7b5'), Chord(c, major7_b5));
      expect(tryParseChord('F#m'), Chord(fSharp, minor));
      expect(tryParseChord('Bb7M'), Chord(bFlat, major7M));
      // Existing long forms unchanged
      expect(tryParseChord('Cmaj7'), Chord(c, major7));
      expect(tryParseChord('Cmin7'), Chord(c, minor7));
      // Not chords
      expect(tryParseChord('Cx'), isNull);
      expect(tryParseChord('7'), isNull);
    });
    test('every alias pattern is named', () {
      for (var pattern in chordPatternAliases.values) {
        expect(chordPatternNames[pattern], isNotNull, reason: '$pattern');
      }
    });
  });
  group('intervalNames', () {
    test('major 7th', () {
      expect(intervalShortNames[10], 'm7');
      expect(intervalShortNames[11], 'M7');
      expect(major7M.toString(), 'Major7M[R, M3, 5, M7]');
    });
    test('long names', () {
      expect(major7th.semitones, 11);
      expect(RawInterval(11).toString(), 'major 7th');
      expect(RawInterval(23).toString(), 'major 7th');
    });
  });
}
