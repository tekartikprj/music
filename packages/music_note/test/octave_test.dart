import 'package:tekaly_music_note/music_note.dart';
import 'package:test/test.dart';

void main() {
  group('octave', () {
    test('noteCount', () {
      expect(octaveNoteCount, 12);
    });

    test('semitonesInOctave', () {
      expect(semitonesInOctave(0), 0);
      expect(semitonesInOctave(1), 1);
      expect(semitonesInOctave(12), 0);
      expect(semitonesInOctave(13), 1);
      expect(semitonesInOctave(25), 1);
      expect(semitonesInOctave(-13), 11);
      expect(semitonesInOctave(-12), 0);
      expect(semitonesInOctave(-11), 1);
    });
  });
}
