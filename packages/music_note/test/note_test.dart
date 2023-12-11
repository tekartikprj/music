import 'package:tekaly_music_note/music_note.dart';

import 'package:test/test.dart';

void main() {
  group('note', () {
    test('c0', () {
      expect(c0, Note(12));
      expect(c0.semitones, 12);
      expect(c0.key, c);
      expect(c0.octave, 0);
    });
    test('a4', () {
      expect(a4.semitones, 69);
      expect(a4.key, a);
      expect(a4.octave, 4);
    });
    test('toString', () {
      expect(a4.toString(), 'A4');
    });
  });
}
