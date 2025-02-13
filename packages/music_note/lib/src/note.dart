// Octave is -1 based. i.e. C0 => 12
import 'interval.dart';
import 'key.dart';
import 'octave.dart';
import 'semitones_base.dart';

class Note extends SemitonesBase {
  const Note(super.semitones);

  Note.from(Key key, int octave)
    : super((octave + 1) * octaveNoteCount + key.semitones);

  Note noteAtOffset(int semitonesOffset) => Note(semitones + semitonesOffset);

  Note noteAtInterval(Interval interval) => noteAtOffset(interval.semitones);

  RawInterval getNoteInterval(Note note) =>
      RawInterval(note.semitones - semitones);

  Key get key => Key(semitones);

  int get octave => (semitones ~/ octaveNoteCount) - 1;

  @override
  String toString() => '$key$octave';
}

Note _note(Key key, int octave) => Note.from(key, octave);
final c0 = _note(c, 0);
final a4 = _note(a, 4);

final c2 = _note(c, 2);
final d2 = _note(d, 2);
final e2 = _note(e, 2);
final g2 = _note(g, 2);
final b2 = _note(b, 2);
final a2 = _note(a, 2);
final c3 = _note(c, 3);
final d3 = _note(d, 3);
final e3 = _note(e, 3);

/// F3
final f3 = _note(f, 3);

/// F#3
final fSharp3 = _note(fSharp, 3);
final g3 = _note(g, 3);
final a3 = _note(a, 3);
final b3 = _note(b, 3);
final c4 = _note(c, 4);
final d4 = _note(d, 4);
final e4 = _note(e, 4);
final e5 = _note(e, 5);
