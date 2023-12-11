import 'package:tekaly_music_note/music_note.dart';
import 'package:test/test.dart';

import 'semitones_base_test.dart';

void main() {
  group('key', () {
    test('equals', () {
      expect(Key(0), Key(12));
      expect(Key(1), Key(13));
      expect(Key(1), isNot(Key(12)));
    });
    test('ctor', () {
      expect(Key(0).semitones, 0);
      expect(Key(13).semitones, 1);
      expect(Key(-13).semitones, 11);
    });
    test('all keys', () {
      expect(allKeys.length, octaveNoteCount);

      for (var i = 0; i < octaveNoteCount; i++) {
        expect(allKeys[i].semitones, i);
      }
    });

    test('offset', () {
      expect(c.keyAtOffset(0), c);
      expect(c.keyAtOffset(1), cSharp);
      expect(c.keyAtOffset(-1), b);
      expect(b.keyAtOffset(1), c);
    });

    test('equals', () {
      expect(c, Key(0));
      expect(c, isNot(cSharp));
      expect(c, isNot(semitones0));
    });

    test('toString', () {
      expect(c.toString(), 'C');
      expect(cSharp.toString(), 'Db');
      expect(b.toString(), 'B');
    });

    test('transpose', () {
      expect(Key(0), Key(12));
    });
  });
}
