/// Keep the timing of lyrics across an edit of their text.
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

  void pairGap(int oldFrom, int oldTo, int newFrom, int newTo) {
    if (oldTo - oldFrom != newTo - newFrom) {
      return;
    }
    for (var k = 0; k < oldTo - oldFrom; k++) {
      _copyTiming(oldLines[oldFrom + k], newLines[newFrom + k]);
    }
  }

  var previousOld = 0;
  var previousNew = 0;
  for (var (oldIndex, newIndex) in pairs) {
    pairGap(previousOld, oldIndex, previousNew, newIndex);
    _copyTiming(oldLines[oldIndex], newLines[newIndex]);
    previousOld = oldIndex + 1;
    previousNew = newIndex + 1;
  }
  pairGap(previousOld, n, previousNew, m);
  return result;
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
