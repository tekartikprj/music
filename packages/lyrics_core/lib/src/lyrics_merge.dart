/// Keep across an edit of lyrics what the edited text could not carry: the
/// timing when the text format was edited, the chords, the sections and the
/// page times when the LRC was.
library;

import 'lyrics_model.dart';

/// [edited] (parsed from an edited text, untimed) with the times of
/// [previous] wherever they still make sense.
///
/// Lines are matched on their text (longest common subsequence): an
/// unchanged line keeps all its times. Between two matched lines, when as
/// many lines were edited as there were, they are paired in order: a
/// changed line keeps its start, end and page time, and its part times too
/// when it still has as many parts. Any other line is untimed. The offset
/// and the language are kept.
CvLyrics mergeLyricsTiming(CvLyrics previous, CvLyrics edited) {
  var result = edited.copy()
    ..offsetMs.v = previous.offsetMs.v
    ..language.v = edited.language.v ?? previous.language.v;
  var oldLines = previous.lineList;
  var newLines = result.lineList;
  for (var (oldIndex, newIndex) in _matchLines(oldLines, newLines)) {
    _copyTiming(oldLines[oldIndex], newLines[newIndex]);
  }
  return result;
}

/// [edited] (parsed from an edited LRC text, which carries the times but
/// no chord, section nor page time) with the chords, the sections and the
/// page times of [previous] wherever they still apply.
///
/// Lines are matched as in [mergeLyricsTiming]; a matched line takes the
/// section of the previous one when it has none, its page time when both
/// start a page, and its chords when it has none and as many parts. The
/// language is kept.
CvLyrics mergeLyricsExtras(CvLyrics previous, CvLyrics edited) {
  var result = edited.copy()
    ..language.v = edited.language.v ?? previous.language.v;
  var oldLines = previous.lineList;
  var newLines = result.lineList;
  for (var (oldIndex, newIndex) in _matchLines(oldLines, newLines)) {
    var from = oldLines[oldIndex];
    var to = newLines[newIndex];
    to.section.v ??= from.section.v;
    if (to.isNewPage && from.isNewPage && to.pageMs.v == null) {
      to.pageMs.v = from.pageMs.v;
    }
    var fromParts = from.partList;
    var toParts = to.partList;
    if (fromParts.length == toParts.length &&
        !toParts.any((part) => part.chord.v != null)) {
      for (var p = 0; p < toParts.length; p++) {
        toParts[p].chord.v = fromParts[p].chord.v;
      }
    }
  }
  return result;
}

/// The pairs (old index, new index) of the lines matched on their text
/// (longest common subsequence), plus the lines between two matches paired
/// in order when as many were edited as there were.
List<(int, int)> _matchLines(
  List<CvLyricsLine> oldLines,
  List<CvLyricsLine> newLines,
) {
  var oldKeys = oldLines.map(_lineKey).toList();
  var newKeys = newLines.map(_lineKey).toList();

  // Longest common subsequence table.
  var n = oldKeys.length;
  var m = newKeys.length;
  var table = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      table[i][j] = oldKeys[i] == newKeys[j]
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] >= table[i][j + 1]
                ? table[i + 1][j]
                : table[i][j + 1]);
    }
  }
  var pairs = <(int, int)>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (oldKeys[i] == newKeys[j]) {
      pairs.add((i, j));
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  var matches = <(int, int)>[];
  void pairGap(int oldFrom, int oldTo, int newFrom, int newTo) {
    if (oldTo - oldFrom != newTo - newFrom) {
      return;
    }
    for (var k = 0; k < oldTo - oldFrom; k++) {
      matches.add((oldFrom + k, newFrom + k));
    }
  }

  var previousOld = 0;
  var previousNew = 0;
  for (var (oldIndex, newIndex) in pairs) {
    pairGap(previousOld, oldIndex, previousNew, newIndex);
    matches.add((oldIndex, newIndex));
    previousOld = oldIndex + 1;
    previousNew = newIndex + 1;
  }
  pairGap(previousOld, n, previousNew, m);
  return matches;
}

/// What identifies a line across an edit: its parts (syllable split
/// included), chords left out.
String _lineKey(CvLyricsLine line) => line.partList
    .map((part) => '${part.textOrEmpty}${part.isJoined ? '|' : ' '}')
    .join();

void _copyTiming(CvLyricsLine from, CvLyricsLine to) {
  to
    ..startMs.v = from.startMs.v
    ..endMs.v = from.endMs.v;
  if (to.isNewPage && from.isNewPage) {
    to.pageMs.v = from.pageMs.v;
  }
  var fromParts = from.partList;
  var toParts = to.partList;
  if (fromParts.length != toParts.length) {
    // The line start may have come from its first part.
    if (to.startMs.v == null && fromParts.isNotEmpty) {
      to.startMs.v = fromParts.first.startMs.v;
    }
    return;
  }
  for (var p = 0; p < toParts.length; p++) {
    toParts[p]
      ..startMs.v = fromParts[p].startMs.v
      ..endMs.v = fromParts[p].endMs.v;
  }
}
