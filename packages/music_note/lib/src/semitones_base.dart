abstract class SemitonesBase implements Comparable<SemitonesBase> {
  final int _semitones;
  int get semitones => _semitones;

  const SemitonesBase(this._semitones);

  @override
  int get hashCode => _semitones;

  @override
  bool operator ==(other) {
    if (other is SemitonesBase) {
      return other.runtimeType == runtimeType && other._semitones == _semitones;
    }
    return false;
  }

  @override
  String toString() => _semitones.toString();

  @override
  int compareTo(SemitonesBase other) {
    return _semitones - other._semitones;
  }

  bool operator <(SemitonesBase other) => semitones < other.semitones;
  bool operator <=(SemitonesBase other) => semitones <= other.semitones;
  bool operator >(SemitonesBase other) => semitones > other.semitones;
  bool operator >=(SemitonesBase other) => semitones >= other.semitones;
}
