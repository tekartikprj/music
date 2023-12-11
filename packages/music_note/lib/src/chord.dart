import 'chord_pattern.dart';
import 'interval.dart';
import 'key.dart';

class Chord {
  final Key key;
  final ChordPattern? pattern;

  Chord(this.key, this.pattern);

  @override
  int get hashCode => key.hashCode + pattern.hashCode;

  @override
  bool operator ==(other) {
    if (other is Chord) {
      return other.key == key && other.pattern == pattern;
    }
    return false;
  }

  @override
  String toString() {
    return '$key $pattern';
  }

  bool containsKey(Key key) {
    for (var interval in pattern!.intervals!) {
      var chordKeyNote = this.key.keyAtOffset(interval.semitones);
      if (key == chordKeyNote) {
        return true;
      }
    }
    return false;
  }

  Interval? findInterval(Key? key) {
    for (var interval in pattern!.intervals!) {
      var chordKeyNote = this.key.keyAtOffset(interval.semitones);
      if (key == chordKeyNote) {
        return interval;
      }
    }
    return null;
  }
}

extension ChordExtension on Chord {
  /// Transpose the chord by the given number of semitones.
  Chord transpose(int semitones) {
    return Chord(key.keyAtOffset(semitones), pattern);
  }
}

extension ChordListExtension on List<Chord> {
  /// Transpose the chord by the given number of semitones.
  List<Chord> transpose(int semitones) {
    return map((chord) => chord.transpose(semitones)).toList();
  }
}
