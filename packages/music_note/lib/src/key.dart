import 'interval.dart';
import 'names.dart';
import 'note.dart';
import 'octave.dart';
import 'semitones_base.dart';

class Key extends SemitonesBase {
  const Key(int semitones) : super(semitones % octaveNoteCount);

  Key keyAtOffset(int semitonesOffset) => Key(semitones + semitonesOffset);

  Key keyAtInterval(RawInterval interval) => keyAtOffset(interval.semitones);

  RawInterval getNoteInterval(Note note) =>
      RawInterval(note.semitones - semitones);

  @override
  String toString() => keyNames[semitones];

  bool get isAltered {
    switch (semitones) {
      case 1:
      case 3:
      case 6:
      case 8:
      case 10:
        return true;
      default:
        return false;
    }
  }

  Key get _exactNonAlteredKey {
    switch (semitones) {
      case 0:
        return c;
      case 2:
        return d;
      case 4:
        return e;
      case 5:
        return f;
      case 7:
        return g;
      case 9:
        return a;
      case 11:
        return b;
      default:
        throw 'bad usage key must be non altered';
    }
  }

  Key get floor {
    if (isAltered) {
      return keyAtOffset(-1)._exactNonAlteredKey;
    }
    return this;
  }

  Key get ceil {
    if (isAltered) {
      return keyAtOffset(1)._exactNonAlteredKey;
    }
    return this;
  }
}

const c = Key(0);
const cSharp = Key(1);
const dFlat = cSharp;
const d = Key(2);
const dSharp = Key(3);
const eFlat = dSharp;
const e = Key(4);
const f = Key(5);
const fSharp = Key(6);
const gFlat = fSharp;
const g = Key(7);
const gSharp = Key(8);
const aFlat = gSharp;
const a = Key(9);
const aSharp = Key(10);
const bFlat = aSharp;
const b = Key(11);

const List<Key> allKeys = [
  c,
  cSharp,
  d,
  dSharp,
  e,
  f,
  fSharp,
  g,
  gSharp,
  a,
  aSharp,
  b,
];

const List<Key> allAlteredKeys = [cSharp, dSharp, fSharp, gSharp, aSharp];

const List<Key> allUnalteredKeys = [c, d, e, f, g, a, b];

extension KeyExtension on Key {
  Key get transposeUp => keyAtOffset(1);
  Key get transposeDown => keyAtOffset(-1);
  Key transpose(int semitones) => keyAtOffset(semitones);
}

extension KeyListExtension on List<Key> {
  /// Transport a list of key
  List<Key> transpose(int semitones) =>
      map((key) => key.transpose(semitones)).toList();
}
