import 'package:collection/collection.dart';

import 'interval.dart';
import 'key.dart';
import 'octave.dart';

bool listEquals(List? list1, List? list2) =>
    const ListEquality<Object?>().equals(list1, list2);

bool semitonesSameKey(int semitones0, int semitones1) {
  return semitonesInOctave(semitones0) == semitonesInOctave(semitones1);
}

bool intervalSimilar(RawInterval? interval1, RawInterval? interval2) {
  if (interval1 == null) {
    return interval2 == null;
  } else if (interval2 != null) {
    return semitonesSameKey(interval1.semitones, interval2.semitones);
  }
  return false;
}

int positiveKeyDiff(Key key0, Key key1) {
  return semitonesInOctave(key1.semitones - key0.semitones);
}
