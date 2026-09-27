/// The lyrics text format, the one the lyrics are edited in, a subset of
/// ChordPro:
///
/// ```text
/// [Chorus]
/// Il en faut peu pour [C]ê|tre heu|reux
/// Vrai|ment très [G7]peu
///
/// Il faut se sa|tis|fai|re du né|ces|sai|re
/// ```
///
/// - one line per lyrics line, a blank line starts a new page;
/// - `|` inside a word splits syllables and is not shown;
/// - `[C]` (a chord name) puts a chord on the part that follows;
/// - a line made of a single `[Label]` that is not a chord names the section
///   of the lines that follow, up to the next blank line;
/// - ChordPro directives are understood: `{title:}`, `{artist:}`,
///   `{start_of_chorus}` / `{soc}` and the other `start_of_x`/`end_of_x`,
///   the others (comments included) are ignored;
/// - a line of chords only above a lyrics line (the chords over the lyrics
///   of a text songbook) puts each chord on the lyrics at its column.
///
/// Times are not part of it: see `mergeLyricsTiming` to keep them across an
/// edit.
library;

import 'dart:convert';

import 'lyrics_lrc.dart' show LyricsImport;
import 'lyrics_model.dart';

final _chordRegExp = RegExp(
  r'^(?:N\.?C\.?|[A-G][#b♯♭]?'
  r'(?:maj|min|dim|aug|sus|add|m|M|°|ø|\+)?'
  r'(?:\d{1,2})?'
  r'(?:\(?(?:maj|min|dim|aug|sus|add|b|#|♭|♯|\+|-)?\d{1,2}\)?)*'
  r'(?:/[A-G][#b♯♭]?)?)$',
);

/// True when [text] is a chord name (`C`, `Am7`, `F#m7b5`, `Csus4`, `D/F#`,
/// `N.C.`).
bool isLyricsChordName(String text) => _chordRegExp.hasMatch(text);

bool _isSpace(String char) => char.trim().isEmpty;

/// Parse one lyrics line of the text format into parts.
List<CvLyricsPart> parseLyricsTextLine(String line) {
  var parts = <CvLyricsPart>[];
  var buffer = StringBuffer();
  String? pendingChord;

  void emit({required bool join}) {
    parts.add(
      CvLyricsPart.of(buffer.toString(), join: join, chord: pendingChord),
    );
    buffer.clear();
    pendingChord = null;
  }

  var i = 0;
  while (i < line.length) {
    var char = line[i];
    if (char == '[') {
      var close = line.indexOf(']', i);
      if (close > i + 1) {
        var inner = line.substring(i + 1, close);
        if (isLyricsChordName(inner)) {
          if (buffer.isNotEmpty) {
            // Inside a word: the chord splits it.
            emit(join: true);
          } else if (pendingChord != null) {
            // Two chords in a row: the first one on an empty part.
            emit(join: false);
          }
          pendingChord = inner;
          i = close + 1;
          continue;
        }
      }
    }
    if (char == '|') {
      if (buffer.isNotEmpty) {
        emit(join: true);
      }
      i++;
      continue;
    }
    if (_isSpace(char)) {
      if (buffer.isNotEmpty) {
        emit(join: false);
      }
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }
  if (buffer.isNotEmpty || pendingChord != null) {
    emit(join: false);
  }
  if (parts.isNotEmpty) {
    parts.last.join.v = null;
  }
  return parts;
}

/// The chords of a chords-only line with their column, null when the line
/// is not made of chords only.
///
/// Short lyrics can look like chords (`B C`, `A`): several single letter
/// chords only count when spread out (two spaces or more between them).
List<({int column, String chord})>? _chordLineChords(String line) {
  var result = <({int column, String chord})>[];
  for (var match in RegExp(r'\S+').allMatches(line)) {
    var token = match.group(0)!;
    // `[C]` alone on a line is a ChordPro chord, not a chord over lyrics.
    if (!isLyricsChordName(token)) {
      return null;
    }
    result.add((column: match.start, chord: token));
  }
  if (result.isEmpty) {
    return null;
  }
  if (result.length > 1 && result.every((chord) => chord.chord.length == 1)) {
    for (var i = 1; i < result.length; i++) {
      var gap = result[i].column - result[i - 1].column - 1;
      if (gap < 2) {
        return null;
      }
    }
  }
  return result;
}

/// Merge a chords-over-lyrics pair into a ChordPro line.
String _mergeChordLine(
  List<({int column, String chord})> chords,
  String lyrics,
) {
  var sb = StringBuffer();
  var index = 0;
  for (var chord in chords) {
    var column = chord.column;
    // Over a space: the chord goes with the word that follows.
    while (column < lyrics.length && _isSpace(lyrics[column])) {
      column++;
    }
    if (column > lyrics.length) {
      column = lyrics.length;
    }
    if (column > index) {
      sb.write(lyrics.substring(index, column));
      index = column;
    }
    sb.write('[${chord.chord}]');
  }
  sb.write(lyrics.substring(index));
  return sb.toString();
}

final _directiveRegExp = RegExp(r'^\{\s*([a-zA-Z_]+)\s*(?::\s*(.*?))?\s*\}$');
final _labelRegExp = RegExp(r'^\[([^\]]+)\]:?$');

const _sectionShortcuts = {
  'soc': 'chorus',
  'sov': 'verse',
  'sob': 'bridge',
  'sot': 'tab',
  'sog': 'grid',
};

const _sectionEndShortcuts = {'eoc', 'eov', 'eob', 'eot', 'eog'};

/// Parse the lyrics text format (or a ChordPro file, or a text songbook with
/// the chords over the lyrics).
LyricsImport parseLyricsText(String content) {
  String? title;
  String? artist;
  var lines = <CvLyricsLine>[];
  var pendingNewPage = false;
  String? section;
  var sectionFromLabel = false;
  var rawLines = LineSplitter.split(content).toList();
  for (var r = 0; r < rawLines.length; r++) {
    var raw = rawLines[r].trimRight();
    var trimmed = raw.trim();
    if (trimmed.isEmpty) {
      if (lines.isNotEmpty) {
        pendingNewPage = true;
      }
      if (sectionFromLabel) {
        section = null;
        sectionFromLabel = false;
      }
      continue;
    }
    var directive = _directiveRegExp.firstMatch(trimmed);
    if (directive != null) {
      var name = directive.group(1)!.toLowerCase();
      var value = directive.group(2);
      switch (name) {
        case 'title':
        case 't':
          title = value;
        case 'artist':
        case 'subtitle':
        case 'st':
          artist ??= value;
        default:
          var shortcut = _sectionShortcuts[name];
          if (shortcut != null) {
            section = shortcut;
            sectionFromLabel = false;
          } else if (name.startsWith('start_of_')) {
            section = name.substring('start_of_'.length);
            sectionFromLabel = false;
          } else if (_sectionEndShortcuts.contains(name) ||
              name.startsWith('end_of_')) {
            section = null;
          }
      }
      continue;
    }
    var label = _labelRegExp.firstMatch(trimmed);
    if (label != null && !isLyricsChordName(label.group(1)!)) {
      section = label.group(1)!.trim();
      sectionFromLabel = true;
      continue;
    }
    var chords = _chordLineChords(raw);
    if (chords != null) {
      // Chords over lyrics: merged into the next line when it is lyrics.
      if (r + 1 < rawLines.length) {
        var next = rawLines[r + 1].trimRight();
        if (next.trim().isNotEmpty &&
            _chordLineChords(next) == null &&
            _directiveRegExp.firstMatch(next.trim()) == null &&
            _labelRegExp.firstMatch(next.trim()) == null) {
          raw = _mergeChordLine(chords, next);
          r++;
        } else {
          raw = chords.map((chord) => '[${chord.chord}]').join(' ');
        }
      } else {
        raw = chords.map((chord) => '[${chord.chord}]').join(' ');
      }
    }
    var parts = parseLyricsTextLine(raw);
    if (parts.isEmpty) {
      continue;
    }
    lines.add(
      CvLyricsLine.of(
        parts,
        newPage: pendingNewPage && lines.isNotEmpty,
        section: section,
      ),
    );
    pendingNewPage = false;
  }
  return LyricsImport(lyrics: CvLyrics.of(lines), title: title, artist: artist);
}

/// Format [lyrics] in the text format (times are dropped).
///
/// [chords] off leaves the chords out, [syllables] off writes the words
/// without their `|` syllable marks.
String formatLyricsText(
  CvLyrics lyrics, {
  bool chords = true,
  bool syllables = true,
}) {
  var sb = StringBuffer();
  String? previousSection;
  var list = lyrics.lineList;
  for (var i = 0; i < list.length; i++) {
    var line = list[i];
    if (i > 0 && line.isNewPage) {
      sb.writeln();
      // A blank line ends a labelled section.
      previousSection = null;
    }
    var section = line.section.v;
    if (section != null && section != previousSection) {
      sb.writeln('[$section]');
    }
    previousSection = section;
    var parts = line.partList;
    for (var p = 0; p < parts.length; p++) {
      var part = parts[p];
      var chord = part.chord.v;
      if (chords && chord != null) {
        sb.write('[$chord]');
      }
      sb.write(part.textOrEmpty);
      if (p < parts.length - 1) {
        if (part.isJoined) {
          if (syllables) {
            sb.write('|');
          }
        } else {
          sb.write(' ');
        }
      }
    }
    sb.writeln();
  }
  return sb.toString();
}
