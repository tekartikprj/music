import 'octave.dart';
import 'semitones_base.dart';

class Interval extends RawInterval {
  final String name;
  const Interval(this.name, int semitones) : super(semitones);

  @override
  String toString() => name;

  @override
  int get hashCode => super.hashCode + name.hashCode;

  @override
  bool operator ==(other) {
    if (other is Interval) {
      return other.name == name && super == (other);
    }
    return false;
  }
}

class RawInterval extends SemitonesBase {
  const RawInterval(super.semitones);

  @override
  String toString() {
    try {
      return intervalLongNames[semitones]!;
    } catch (_) {
      return intervalLongNames[semitones % octaveNoteCount]!;
    }
  }
}

List<String?> intervalLongNames = [
  'Root',
  'Minor 2nd',
  'major 2nd',
  'Minor 3rd',
  'major 3rd',
  'Perfect 4th',
  'Tritone',
  'Perfect 5th',
  'Minor 6th',
  'major 6th',
  'Minor 7th',
  'major 7th',
  // Octave
  'Octave',
  'b9',
  '9',
  null,
  null,
  '11',
  null,
  null,
  null,
  '13',
];

const root = Interval('root', 0);
const minor3rd = Interval('b3', 3);
const major3rd = Interval('3', 4);
const perfectFifth = Interval('5', 7);
const minor2nd = Interval('b2', 1);
const major2nd = Interval('2', 2);
const minor9th = Interval('b9', 13);
const major9th = Interval('9', 14);
const perfect4th = Interval('4', 5);
const perfect11th = Interval('11', 17);
const tritone = Interval('tt', 6);
const fifthFlat = Interval('b5', 6);
const perfect5th = perfectFifth;
const fifthSharp = Interval('5#', 8);
const minor6th = Interval('b6', 8);
const major6th = Interval('6', 9);
const major13th = Interval('13', 21);
const seventhFlatFlat = Interval('bb7', 9);
const minor7th = Interval('b7', 10);
const major7th = Interval('7', 11);
const octave = Interval('o', 12);
