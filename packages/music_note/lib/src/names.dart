import 'package:tekaly_music_note/music_note.dart';

List<String> keyNames = [
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
  'B'
];

List<String> flatKeyNames = [
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
  'B'
];

List<String> sharpKeyNames = [
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
  'B'
];

List<String?> intervalShortNames = [
  'R',
  'm2',
  'M2',
  'm3',
  'M3',
  '4',
  'T',
  '5',
  'm6',
  'M6',
  'm7',
  'm7',
  // Octave
  'O',
  'm9',
  'M9',
  null,
  null,
  '11',
  null,
  null,
  null,
  '13'
];
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
  '13'
];

Map<ChordPattern, String> chordPatternNames = {
  major: 'Major',
  minor: 'Minor',
  major7: 'Major7',
  minor7: 'Minor7',
  major7M: 'Major7M',
  minor7M: 'Minor7M',
  major6: 'Major6',
  minor6: 'Minor6',
  dim: 'Dim',
  dim7: 'Dim7',
  aug: 'Aug',
  sus2: 'Sus2',
  sus4: 'Sus4',
  sevenSus4: '7Sus4',
  major9: 'Major9',
  minor9: 'Minor9',
  major9M: 'Major9M',
  majorAdd9: 'MajorAdd9',
  minorAdd9: 'MinorAdd9',
  major6_9: 'Major6/9',
  minor6_9: 'Minor6/9',
  major7_b5: 'Major7b5',
  minor7_b5: 'Minor7b5',
  major7_sharp5: 'Major7#5',
  major7_b9: 'Major7b9',
  minor7_b9: 'Minor7b9',
  major9_b5: 'Minor9b5',
  major_b5: 'Major/b5',
  major11: 'Major11',
  minor11: 'Minor11',
  major13: 'Major13',
  minor13: 'Minor13',
};

var unalteredKeyNames = [
  'C',
  'D',
  'E',
  'F',
  'G',
  'A',
  'B',
];
var alteredKeyNames = [
  'C#',
  'Db',
  'D#',
  'Eb',
  'F#',
  'Gb',
  'G#',
  'Ab',
  'A#',
  'Bb',
];
var keyAliases = {
  'C': c,
  'C#': cSharp,
  'Db': dFlat,
  'D': d,
  'D#': dSharp,
  'Eb': eFlat,
  'E': e,
  'F': f,
  'F#': fSharp,
  'Gb': gFlat,
  'G': g,
  'G#': gSharp,
  'Ab': aFlat,
  'A': a,
  'A#': aSharp,
  'Bb': bFlat,
  'B': b,
};
var chordPatternAliases = {
  '': major,
  'M': major,
  'm': minor,
  'maj': major,
  'min': minor,
  'min7': minor7,
  'min7M': minor7M,
  'min6': minor6,
  'min6/9': minor6_9,
  'min9': minor9,
  'min9M': minor9,
  'min11': minor11,
  'min13': minor13,
  'min7b5': minor7_b5,
  'min7b9': minor7_b9,
  //'min9b5': minor9_b5,
  'minadd9': minorAdd9,
  'minadd9M': minorAdd9,
  'minM': minor,
  'minM7': minor7M,
  'minM9': minor9,
  'minM11': minor11,
  'minM13': minor13,
  'minM7b5': minor7_b5,
  'minM7b9': minor7_b9,
  //'minM9b5': minor9_b5,
  'minMadd9': minorAdd9,
  'minMadd9M': minorAdd9,
  'maj7': major7,
  'maj7M': major7M,
  'maj6': major6,
  'maj6/9': major6_9,
  'maj9': major9,
  'maj9M': major9M,
  'maj11': major11,
  'maj13': major13,
  'maj7b5': major7_b5,
  'maj7b9': major7_b9,
  'maj9b5': major9_b5,
  'majadd9': majorAdd9,
  'majadd9M': majorAdd9,
  'majM': major,
  'majM7': major7M,
  'majM9': major9,
  'majM11': major11,
  'majM13': major13,
  'majM7b5': major7_b5,
  'majM7b9': major7_b9,
  'majM9b5': major9_b5,
  'majMadd9': majorAdd9,
  'majMadd9M': majorAdd9,
  '7sus4 ': sevenSus4,
};

var chordPatterShortName = {
  major: '',
  minor: 'm',
  major7: 'M7',
  minor7: 'm7',
  major7M: 'M7M',
  minor7M: 'm7M',
  major6: 'M6',
  minor6: 'm6',
  dim: 'dim',
  dim7: 'dim7',
  aug: 'aug',
  sus2: 'sus2',
  sus4: 'sus4',
  sevenSus4: '7sus4',
  major9: 'M9',
  minor9: 'm9',
  major9M: 'M9M',
  majorAdd9: 'Madd9',
  minorAdd9: 'madd9',
  major6_9: 'M6/9',
  minor6_9: 'm6/9',
  major7_b5: 'M7b5',
  minor7_b5: 'm7b5',
  major7_sharp5: 'M7#5',
  major7_b9: 'M7b9',
  minor7_b9: 'm7b9',
  major9_b5: 'M9b5',
  major_b5: 'M/b5',
  major11: 'M11',
  minor11: 'm11',
  major13: 'M13',
  minor13: 'm13',
};

/// Parse 'm', '7b5'...
ChordPattern? tryParseChordPattern(String text) {
  return chordPatternAliases[text];
}

/// Try to parse 'Am' ...
Chord? tryParseChord(String text) {
  /// Process altered keys first
  for (var key in [...alteredKeyNames, ...unalteredKeyNames]) {
    if (text.startsWith(key)) {
      var patternName = text.substring(key.length);

      var chordPattern = tryParseChordPattern(patternName);
      if (chordPattern != null) {
        return Chord(tryParseKey(key)!, chordPattern);
      }
    }
  }
  return null;
}

Key? tryParseKey(String keyName) {
  return keyAliases[keyName];
}

var nonAlteredKeyNames = {
  c: 'C',
  d: 'D',
  e: 'E',
  f: 'F',
  g: 'G',
  a: 'A',
  b: 'B',
};

final flatOnlyKeyNames = {
  cSharp: 'Db',
  dSharp: 'Eb',
  fSharp: 'Gb',
  gSharp: 'Ab',
  aSharp: 'Bb'
};
var sharpOnlyKeyNames = {
  cSharp: 'C#',
  dSharp: 'D#',
  fSharp: 'F#',
  gSharp: 'G#',
  aSharp: 'A#'
};
