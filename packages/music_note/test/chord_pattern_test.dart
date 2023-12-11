import 'package:tekaly_music_note/music_note.dart';

import 'package:test/test.dart';

void main() {
  group('chordPattern', () {
    test('equals', () {
      expect(major, major);
      expect(major, ChordPattern([root, major3rd, perfectFifth]));
      expect(major, isNot(minor));
    });
    test('toString', () {
      expect(major.toString(), 'Major[R, M3, 5]');
    });

    List<int> noteDiffs(ChordPattern chordPattern) {
      var noteDiffs = <int>[];
      for (var interval in chordPattern.intervals!) {
        noteDiffs.add(interval.semitones);
      }
      return noteDiffs;
    }

    test('name', () {
      expect(chordPatternNames[minor], 'Minor');
      expect(chordPatternNames[major], 'Major');
    });
    test('noteDiffs', () {
      expect(noteDiffs(major), [0, 4, 7]);
      expect(noteDiffs(minor), [0, 3, 7]);

      expect(noteDiffs(major7), [0, 4, 7, 10]);

      expect(noteDiffs(minor7), [0, 3, 7, 10]);
      expect(noteDiffs(major7M), [0, 4, 7, 11]);
      expect(noteDiffs(minor7M), [0, 3, 7, 11]);
      expect(noteDiffs(major6), [0, 4, 7, 9]);
      expect(noteDiffs(minor6), [0, 3, 7, 9]);
      expect(noteDiffs(dim7), [0, 3, 6, 9]);
      expect(noteDiffs(aug), [0, 4, 8]);
      expect(noteDiffs(sus2), [0, 2, 7]);
      expect(noteDiffs(sus4), [0, 5, 7]);
      expect(noteDiffs(sevenSus4), [0, 5, 7, 10]);
      expect(noteDiffs(major9), [0, 4, 7, 10, 14]);
      expect(noteDiffs(minor9), [0, 3, 7, 10, 14]);
      expect(noteDiffs(major9M), [0, 4, 7, 11, 14]);
      expect(noteDiffs(majorAdd9), [0, 4, 7, 14]);
      expect(noteDiffs(minorAdd9), [0, 3, 7, 14]);
      expect(noteDiffs(major6_9), [0, 4, 7, 9, 14]);
      expect(noteDiffs(minor6_9), [0, 3, 7, 9, 14]);
      expect(noteDiffs(major7_b5), [0, 4, 6, 10]);
      expect(noteDiffs(minor7_b5), [0, 3, 6, 10]);
      expect(noteDiffs(major7_sharp5), [0, 4, 8, 10]);
      expect(noteDiffs(major7_b9), [0, 4, 7, 10, 13]);
      expect(noteDiffs(minor7_b9), [0, 3, 7, 10, 13]);
      expect(noteDiffs(major9_b5), [0, 4, 6, 10, 14]);
      expect(noteDiffs(major_b5), [0, 4, 6]);
      expect(noteDiffs(major11), [0, 4, 7, 10, 14, 17]);
      expect(noteDiffs(minor11), [0, 3, 7, 10, 14, 17]);
      expect(noteDiffs(major13), [0, 4, 7, 10, 14, 17, 21]);

      expect(noteDiffs(minor13), [0, 3, 7, 10, 14, 17, 21]); //????
    });

    test('checkChordPatternIntervals', () {
      expect(() => checkChordPattern(null),
          throwsA(const TypeMatcher<ArgumentError>()));
      expect(() => checkChordPattern(ChordPattern(null)),
          throwsA(const TypeMatcher<ArgumentError>()));
      expect(() => checkChordPattern(ChordPattern([])),
          throwsA(const TypeMatcher<ArgumentError>()));
      expect(() => checkChordPattern(ChordPattern([root])),
          throwsA(const TypeMatcher<ArgumentError>()));
      checkChordPattern(ChordPattern([root, major3rd]));
      expect(() => checkChordPattern(ChordPattern([root, major3rd])),
          isNot(throwsA(const TypeMatcher<ArgumentError>())));
      expect(() => checkChordPattern(ChordPattern([major2nd, major9th])),
          isNot(throwsA(const TypeMatcher<ArgumentError>())));
    });
    test('all chords', () {
      expect(chordPatternNames.length, 32);
      var existingPatterns = <ChordPattern>{};
      for (var chordPattern in allPatterns) {
        checkChordPattern(chordPattern);
        expect(existingPatterns, isNot(contains(chordPattern)),
            reason: chordPattern.toString());
        existingPatterns.add(chordPattern);
      }
    });
  });
}
