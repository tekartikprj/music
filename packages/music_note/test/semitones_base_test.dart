import 'package:tekaly_music_note/music_note.dart';
import 'package:test/test.dart';

class Semitones extends SemitonesBase {
  const Semitones(super.semitones);
}

class OtherSemitones extends SemitonesBase {
  const OtherSemitones(super.semitones);
}

const semitones0 = Semitones(0);
const semitones1 = Semitones(1);

const otherSemitones0 = OtherSemitones(0);

void main() {
  group('semitones_base', () {
    test('hashCode', () {
      expect(semitones0.hashCode, 0);
      expect(semitones1.hashCode, 1);
    });

    test('equals', () {
      expect(semitones0, Semitones(0));
      expect(semitones0, isNot(semitones1));

      expect(otherSemitones0, OtherSemitones(0));
      expect(otherSemitones0, isNot(semitones0));
    });

    test('toString', () {
      expect(semitones0.toString(), '0');
      expect(semitones1.toString(), '1');
    });

    test('compareTo', () {
      expect(semitones0.compareTo(semitones1), -1);
      expect(Comparable.compare(semitones0, semitones1), -1);
      expect(semitones0, lessThan(semitones1));
      expect(semitones0 < semitones1, isTrue);
      expect(semitones1 < semitones0, isFalse);
      expect(semitones0 <= semitones1, isTrue);
      expect(semitones1 <= semitones0, isFalse);
      expect(semitones0 <= semitones0, isTrue);
      expect(semitones1 > semitones0, isTrue);
      expect(semitones0 > semitones1, isFalse);
      expect(semitones1 >= semitones0, isTrue);
      expect(semitones0 >= semitones1, isFalse);
      expect(semitones1 >= semitones1, isTrue);
    });
  });
}
