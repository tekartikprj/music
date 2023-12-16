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
        sharpOnlyKeyNames
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
  });
}
