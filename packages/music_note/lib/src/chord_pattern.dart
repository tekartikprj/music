import 'package:tekaly_music_note/src/utils.dart';

import 'interval.dart';
import 'key.dart';
import 'names.dart';

class ChordPattern {
  final List<Interval>? intervals;

  const ChordPattern(this.intervals);

  @override
  int get hashCode {
    return intervals![0].semitones * 17 +
        intervals![intervals!.length - 1].semitones;
  }

  @override
  bool operator ==(other) {
    if (other is ChordPattern) {
      return listEquals(intervals, other.intervals);
    }
    return false;
  }

  Interval? findNoteDiff(int semitones) {
    for (var interval in intervals!) {
      if (semitonesSameKey(semitones, interval.semitones)) {
        return interval;
      }
    }
    return null;
  }

  Interval? findInterval(RawInterval interval) {
    return findNoteDiff(interval.semitones);
  }

  @override
  String toString() {
    var sb = StringBuffer();
    sb.write(chordPatternNames[this] ?? '?');

    var longNames = <String?>[];
    for (var interval in intervals!) {
      longNames.add(intervalShortNames[interval.semitones]);
    }
    sb.write(longNames.toString());
    return sb.toString();
  }
}

void checkChordPattern(ChordPattern? chordPattern) {
  if (chordPattern == null) {
    throw ArgumentError('Null chord Pattern');
  }
  var intervals = chordPattern.intervals;

  if (intervals == null) {
    throw ArgumentError('Null interval');
  }
  if (intervals.length < 2) {
    throw ArgumentError('A chord pattern has at least 2 notes $intervals');
  }
  for (var i = 0; i < intervals.length - 1; i++) {
    if (intervals[i].compareTo(intervals[i + 1]) >= 0) {
      throw ArgumentError('intervals must be ordered properly $intervals');
    }
  }
  if (intervals.contains(octave)) {
    throw ArgumentError('intervals should not contain the octave');
  }

  // check that we don't have twice the same note
  var keys = <Key>{};
  for (var interval in intervals) {
    var key = Key(interval.semitones);
    if (keys.contains(key)) {
      throw ArgumentError('$interval already present in $intervals');
    }
  }
}

const power = ChordPattern([root, perfectFifth]);
const major = ChordPattern([root, major3rd, perfectFifth]);
const minor = ChordPattern([root, minor3rd, perfectFifth]);
const major7 = ChordPattern([root, major3rd, perfectFifth, minor7th]);
const minor7 = ChordPattern([root, minor3rd, perfectFifth, minor7th]);
const major7M = ChordPattern([root, major3rd, perfectFifth, major7th]);
const minor7M = ChordPattern([root, minor3rd, perfectFifth, major7th]);
const major6 = ChordPattern([root, major3rd, perfectFifth, major6th]);
const minor6 = ChordPattern([root, minor3rd, perfectFifth, major6th]);
const dim = ChordPattern([root, minor3rd, fifthFlat]);
const dim7 = ChordPattern([root, minor3rd, fifthFlat, seventhFlatFlat]);
const aug = ChordPattern([root, major3rd, fifthSharp]);
const sus2 = ChordPattern([root, major2nd, perfect5th]);
const sus4 = ChordPattern([root, perfect4th, perfect5th]);
const sevenSus4 = ChordPattern([root, perfect4th, perfect5th, minor7th]);
const major9 = ChordPattern([root, major3rd, perfectFifth, minor7th, major9th]);
const minor9 = ChordPattern([root, minor3rd, perfectFifth, minor7th, major9th]);
const major9M =
    ChordPattern([root, major3rd, perfectFifth, major7th, major9th]);
const majorAdd9 = ChordPattern([root, major3rd, perfectFifth, major9th]);
const minorAdd9 = ChordPattern([root, minor3rd, perfectFifth, major9th]);
const major6_9 =
    ChordPattern([root, major3rd, perfectFifth, major6th, major9th]);
const minor6_9 =
    ChordPattern([root, minor3rd, perfectFifth, major6th, major9th]);
// ignore: constant_identifier_names
const major7_b5 = ChordPattern([root, major3rd, fifthFlat, minor7th]);
// ignore: constant_identifier_names
const minor7_b5 = ChordPattern([root, minor3rd, fifthFlat, minor7th]);
// ignore: constant_identifier_names
const major7_sharp5 = ChordPattern([root, major3rd, fifthSharp, minor7th]);
// ignore: constant_identifier_names
const major7_b9 =
    ChordPattern([root, major3rd, perfect5th, minor7th, minor9th]);
// ignore: constant_identifier_names
const minor7_b9 =
    ChordPattern([root, minor3rd, perfect5th, minor7th, minor9th]);
// ignore: constant_identifier_names
const major9_b5 = ChordPattern([root, major3rd, fifthFlat, minor7th, major9th]);
// ignore: constant_identifier_names
const major_b5 = ChordPattern([root, major3rd, fifthFlat]);
const major11 = ChordPattern(
    [root, major3rd, perfectFifth, minor7th, major9th, perfect11th]);
const minor11 = ChordPattern(
    [root, minor3rd, perfectFifth, minor7th, major9th, perfect11th]);
const major13 = ChordPattern(
    [root, major3rd, perfectFifth, minor7th, major9th, perfect11th, major13th]);
const minor13 = ChordPattern(
    [root, minor3rd, perfectFifth, minor7th, major9th, perfect11th, major13th]);

Iterable<ChordPattern> allPatterns = chordPatternNames.keys;
