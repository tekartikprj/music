/// Chord transposition.
library;

import 'lyrics_model.dart';

const _sharpNotes = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const _flatNotes = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

final _noteRegExp = RegExp(r'^([A-G])([#b♯♭]?)');

int? _noteIndex(String letter, String accidental) {
  var index = _sharpNotes.indexOf(letter);
  if (index < 0) {
    return null;
  }
  if (accidental == '#' || accidental == '♯') {
    index++;
  } else if (accidental == 'b' || accidental == '♭') {
    index--;
  }
  return index % 12;
}

String _transposeNote(String text, int semitones, {required bool flats}) {
  var match = _noteRegExp.firstMatch(text);
  if (match == null) {
    return text;
  }
  var index = _noteIndex(match.group(1)!, match.group(2)!);
  if (index == null) {
    return text;
  }
  var note = (flats ? _flatNotes : _sharpNotes)[(index + semitones) % 12];
  return '$note${text.substring(match.end)}';
}

/// [chord] moved by [semitones] (`Am7` + 2 = `Bm7`, `D/F#` + 1 = `D#/G`),
/// the bass note included. Flats stay flats (`Bb` + 2 = `C`, `Eb` + 1 = `E`),
/// sharps otherwise; anything that is not a chord is returned as is.
String transposeLyricsChord(String chord, int semitones) {
  if (semitones % 12 == 0) {
    return chord;
  }
  var flats = chord.length > 1 && (chord[1] == 'b' || chord[1] == '♭');
  var slash = chord.indexOf('/');
  if (slash > 0) {
    return '${_transposeNote(chord.substring(0, slash), semitones, flats: flats)}'
        '/${_transposeNote(chord.substring(slash + 1), semitones, flats: flats)}';
  }
  return _transposeNote(chord, semitones, flats: flats);
}

/// Chord helpers.
extension CvLyricsChordExt on CvLyrics {
  /// Every chord moved by [semitones] (in place).
  void transposeChords(int semitones) {
    for (var line in lineList) {
      for (var part in line.partList) {
        var chord = part.chord.v;
        if (chord != null) {
          part.chord.v = transposeLyricsChord(chord, semitones);
        }
      }
    }
  }
}
