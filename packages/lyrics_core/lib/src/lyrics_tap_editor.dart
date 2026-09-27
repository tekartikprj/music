/// The logic of the timing editor: tap along with the media to time the
/// lyrics, to the syllable, the word, the line or the page, then fine-tune.
library;

import 'dart:math';

import 'lyrics_model.dart';
import 'lyrics_timeline.dart';

/// What one tap times.
enum LyricsTimingGranularity {
  /// The start of a part.
  syllable,

  /// The start of a word (its first part), the other parts are estimated.
  word,

  /// The start of a line, its parts timed before move along.
  line,

  /// The time a page is shown.
  page,
}

/// A unit of the lyrics: a part ([part] >= 0), or a line/page ([part] -1).
class LyricsUnitRef {
  /// Index of the line.
  final int line;

  /// Index of the part, -1 for the line itself.
  final int part;

  /// A unit.
  const LyricsUnitRef(this.line, [this.part = -1]);

  /// True when the unit is the line itself (line or page granularity).
  bool get isLine => part < 0;

  @override
  bool operator ==(Object other) =>
      other is LyricsUnitRef && other.line == line && other.part == part;

  @override
  int get hashCode => Object.hash(line, part);

  @override
  String toString() => 'Unit($line, $part)';
}

/// A problem found in a timing (not blocking).
class LyricsTimingIssue {
  /// Where.
  final LyricsUnitRef ref;

  /// What, in plain words.
  final String message;

  /// A problem.
  const LyricsTimingIssue(this.ref, this.message);

  @override
  String toString() => 'Issue($ref, $message)';
}

/// A state of a [LyricsTapEditor] (its lyrics, cursor and last tapped
/// unit), put back with [LyricsTapEditor.restore]: for an undo history kept
/// by the host, shared with the text edits.
class LyricsTapEditorState {
  /// The lyrics (a copy).
  final CvLyrics lyrics;

  /// The cursor, an index in the units.
  final int cursor;

  /// The unit tapped last, if any.
  final LyricsUnitRef? lastTapped;

  /// A state.
  const LyricsTapEditorState(this.lyrics, this.cursor, this.lastTapped);
}

class _Snapshot {
  final CvLyrics lyrics;
  final int cursor;
  final LyricsUnitRef? lastTapped;

  _Snapshot(this.lyrics, this.cursor, this.lastTapped);
}

/// The timing editor: a working copy of the lyrics, a cursor on the next
/// unit to time, and the operations of the keys.
///
/// Positions given to it are media positions (what the player reports); the
/// stored times have [tapLatencyMs] (the reaction time) and the lyrics
/// offset taken off.
class LyricsTapEditor {
  /// The lyrics being edited (a copy of the ones given).
  CvLyrics lyrics;

  /// What a tap times.
  LyricsTimingGranularity _granularity;

  /// Taken off every tap time: how late a tap is on what it marks.
  int tapLatencyMs;

  /// Lines per page of the automatic pages (when no page is explicit).
  final int linesPerPage;

  /// Most undo steps kept.
  final int maxUndo;

  var _units = <LyricsUnitRef>[];
  var _cursor = 0;
  LyricsUnitRef? _lastTapped;
  final _undoStack = <_Snapshot>[];

  /// The editor, on a copy of [lyrics].
  LyricsTapEditor(
    CvLyrics lyrics, {
    LyricsTimingGranularity granularity = LyricsTimingGranularity.syllable,
    this.tapLatencyMs = 0,
    this.linesPerPage = 2,
    this.maxUndo = 200,
  }) : lyrics = lyrics.copy(),
       // ignore: prefer_initializing_formals
       _granularity = granularity {
    _computeUnits();
  }

  /// What a tap times.
  LyricsTimingGranularity get granularity => _granularity;

  /// The units a tap walks through, in order.
  List<LyricsUnitRef> get units => List.unmodifiable(_units);

  /// Index of the cursor in [units], `units.length` once everything is
  /// timed.
  int get cursor => _cursor;

  /// The unit the next tap times, null at the end.
  LyricsUnitRef? get cursorUnit =>
      _cursor < _units.length ? _units[_cursor] : null;

  /// The unit the last tap timed.
  LyricsUnitRef? get lastTapped => _lastTapped;

  /// True when an undo is possible.
  bool get canUndo => _undoStack.isNotEmpty;

  List<CvLyricsLine> get _lines => lyrics.lineList;

  /// Change what a tap times, the cursor stays on the same line.
  void setGranularity(LyricsTimingGranularity granularity) {
    var line = cursorUnit?.line ?? _lines.length;
    _granularity = granularity;
    _computeUnits();
    moveCursorToLine(line);
  }

  void _computeUnits() {
    var units = <LyricsUnitRef>[];
    var lines = _lines;
    switch (_granularity) {
      case LyricsTimingGranularity.syllable:
        for (var l = 0; l < lines.length; l++) {
          var parts = lines[l].partList;
          for (var p = 0; p < parts.length; p++) {
            units.add(LyricsUnitRef(l, p));
          }
        }
      case LyricsTimingGranularity.word:
        for (var l = 0; l < lines.length; l++) {
          var parts = lines[l].partList;
          for (var p = 0; p < parts.length; p++) {
            if (p == 0 || !parts[p - 1].isJoined) {
              units.add(LyricsUnitRef(l, p));
            }
          }
        }
      case LyricsTimingGranularity.line:
        for (var l = 0; l < lines.length; l++) {
          units.add(LyricsUnitRef(l));
        }
      case LyricsTimingGranularity.page:
        var timeline = LyricsTimeline(
          lyrics,
          options: LyricsTimelineOptions(linesPerPage: linesPerPage),
        );
        for (var page in timeline.pages.skip(1)) {
          units.add(LyricsUnitRef(page.firstLine));
        }
    }
    _units = units;
    if (_cursor > _units.length) {
      _cursor = _units.length;
    }
  }

  /// Put the cursor on [ref] (or the first unit at or after it).
  void moveCursorTo(LyricsUnitRef ref) {
    var index = _units.indexWhere(
      (unit) =>
          unit.line > ref.line ||
          (unit.line == ref.line && (unit.part >= ref.part || unit.isLine)),
    );
    _cursor = index < 0 ? _units.length : index;
  }

  /// Put the cursor on the first unit of line [line] (or after).
  void moveCursorToLine(int line) => moveCursorTo(LyricsUnitRef(line));

  /// Move the cursor by [delta] units.
  void moveCursor(int delta) {
    _cursor = (_cursor + delta).clamp(0, _units.length);
  }

  int _stored(int positionMs) =>
      max(0, positionMs - tapLatencyMs - lyrics.offset);

  void _snapshot() {
    _undoStack.add(_Snapshot(lyrics.copy(), _cursor, _lastTapped));
    if (_undoStack.length > maxUndo) {
      _undoStack.removeAt(0);
    }
  }

  /// The state now, to put back later with [restore].
  LyricsTapEditorState get state =>
      LyricsTapEditorState(lyrics.copy(), _cursor, _lastTapped);

  /// Put [state] back (the granularity is kept, the undo stack too).
  void restore(LyricsTapEditorState state) {
    lyrics = state.lyrics.copy();
    _computeUnits();
    _cursor = min(state.cursor, _units.length);
    _lastTapped = state.lastTapped;
  }

  /// Undo the last change, false when there is nothing to undo.
  bool undo() {
    if (_undoStack.isEmpty) {
      return false;
    }
    var snapshot = _undoStack.removeLast();
    lyrics = snapshot.lyrics;
    _computeUnits();
    _cursor = min(snapshot.cursor, _units.length);
    _lastTapped = snapshot.lastTapped;
    return true;
  }

  /// A tap at [positionMs]: time the unit under the cursor and advance.
  /// False at the end (nothing left to time).
  bool tap(int positionMs) {
    var unit = cursorUnit;
    if (unit == null) {
      return false;
    }
    _snapshot();
    var ms = _stored(positionMs);
    var line = _lines[unit.line];
    var parts = line.partList;
    switch (_granularity) {
      case LyricsTimingGranularity.syllable:
        parts[unit.part]
          ..startMs.v = ms
          ..endMs.v = null;
        if (unit.part == 0) {
          line
            ..startMs.v = ms
            ..endMs.v = null;
        }
      case LyricsTimingGranularity.word:
        parts[unit.part]
          ..startMs.v = ms
          ..endMs.v = null;
        for (var p = unit.part + 1; p < parts.length; p++) {
          if (!parts[p - 1].isJoined) {
            break;
          }
          parts[p]
            ..startMs.v = null
            ..endMs.v = null;
        }
        if (unit.part == 0) {
          line
            ..startMs.v = ms
            ..endMs.v = null;
        }
      case LyricsTimingGranularity.line:
        var oldStart = line.startMs.v;
        if (oldStart == null) {
          for (var part in parts) {
            if (part.startMs.v != null) {
              oldStart = part.startMs.v;
              break;
            }
          }
        }
        if (oldStart != null && oldStart != ms) {
          // The syllables timed before follow the line.
          var delta = ms - oldStart;
          int? shift(int? value) =>
              value == null ? null : max(0, value + delta);
          for (var part in parts) {
            part
              ..startMs.v = shift(part.startMs.v)
              ..endMs.v = shift(part.endMs.v);
          }
          line.endMs.v = shift(line.endMs.v);
        }
        line.startMs.v = ms;
        if (parts.isNotEmpty && parts.first.startMs.v != null) {
          parts.first.startMs.v = ms;
        }
      case LyricsTimingGranularity.page:
        _materializePages();
        line
          ..newPage.v = true
          ..pageMs.v = ms;
    }
    _lastTapped = unit;
    _cursor++;
    return true;
  }

  /// A key release at [positionMs] (hold mode): the end of the unit the
  /// last tap timed.
  void release(int positionMs) {
    var unit = _lastTapped;
    if (unit == null) {
      return;
    }
    var ms = _stored(positionMs);
    var line = _lines[unit.line];
    var parts = line.partList;
    switch (_granularity) {
      case LyricsTimingGranularity.syllable:
        var start = parts[unit.part].startMs.v;
        if (start != null && ms > start) {
          parts[unit.part].endMs.v = ms;
        }
      case LyricsTimingGranularity.word:
        var last = unit.part;
        while (last < parts.length - 1 && parts[last].isJoined) {
          last++;
        }
        var start = parts[unit.part].startMs.v;
        if (start != null && ms > start) {
          parts[last].endMs.v = ms;
        }
      case LyricsTimingGranularity.line:
        var start = line.startMs.v;
        if (start != null && ms > start) {
          line.endMs.v = ms;
        }
      case LyricsTimingGranularity.page:
        break;
    }
  }

  /// The end of the current line at [positionMs] (the line of the last tap);
  /// the cursor moves on to the next line.
  void endLine(int positionMs) {
    var lineIndex = _lastTapped?.line;
    if (lineIndex == null) {
      return;
    }
    _snapshot();
    _lines[lineIndex].endMs.v = _stored(positionMs);
    var cursorLine = cursorUnit?.line;
    if (cursorLine != null && cursorLine <= lineIndex) {
      moveCursorToLine(lineIndex + 1);
    }
  }

  /// A page change at [positionMs]: the next line to time starts a new page,
  /// shown from now.
  void pageHere(int positionMs) {
    var unit = cursorUnit;
    int target;
    if (unit == null) {
      return;
    }
    if (unit.isLine || unit.part == 0) {
      target = unit.line;
    } else {
      target = unit.line + 1;
    }
    if (target <= 0 || target >= _lines.length) {
      return;
    }
    _snapshot();
    _materializePages();
    _lines[target]
      ..newPage.v = true
      ..pageMs.v = _stored(positionMs);
    if (_granularity == LyricsTimingGranularity.page) {
      _computeUnits();
    }
  }

  /// Turn the automatic pages into explicit ones, so that one explicit page
  /// break does not merge the others.
  void _materializePages() {
    var lines = _lines;
    if (lines.skip(1).any((line) => line.isNewPage)) {
      return;
    }
    for (var l = linesPerPage; l < lines.length; l += max(1, linesPerPage)) {
      lines[l].newPage.v = true;
    }
  }

  /// The stored start of [ref] (a part, or the line), without offset.
  int? timeOf(LyricsUnitRef ref) {
    var line = _lines[ref.line];
    if (ref.isLine) {
      return _granularity == LyricsTimingGranularity.page
          ? line.pageMs.v
          : line.startMs.v;
    }
    return line.partList[ref.part].startMs.v;
  }

  /// True when [ref] has a time: its own, or for the first part of a line,
  /// the start of the line (an LRC line start times its first syllable).
  bool isTimed(LyricsUnitRef ref) {
    if (timeOf(ref) != null) {
      return true;
    }
    return !ref.isLine &&
        ref.part == 0 &&
        _granularity != LyricsTimingGranularity.page &&
        _lines[ref.line].startMs.v != null;
  }

  /// The index of the first unit not timed yet ([isTimed]), the number of
  /// units when everything is.
  int get firstUntimedIndex {
    var index = _units.indexWhere((unit) => !isTimed(unit));
    return index < 0 ? _units.length : index;
  }

  /// Set the start of [ref] to [positionMs] (a media position, the offset is
  /// taken off but not the tap latency: this is not a tap).
  void setTime(LyricsUnitRef ref, int positionMs) {
    _snapshot();
    var ms = max(0, positionMs - lyrics.offset);
    _setStored(ref, ms);
  }

  void _setStored(LyricsUnitRef ref, int? ms) {
    var line = _lines[ref.line];
    if (ref.isLine) {
      if (_granularity == LyricsTimingGranularity.page) {
        line.pageMs.v = ms;
      } else {
        line.startMs.v = ms;
      }
      return;
    }
    line.partList[ref.part].startMs.v = ms;
    if (ref.part == 0 && line.startMs.v != null) {
      line.startMs.v = ms;
    }
  }

  /// Move the start of [ref] by [deltaMs].
  void nudge(LyricsUnitRef ref, int deltaMs) {
    var current = timeOf(ref);
    if (current == null) {
      return;
    }
    _snapshot();
    _setStored(ref, max(0, current + deltaMs));
  }

  /// Shift every time from line [fromLine] on by [deltaMs].
  void shiftFrom(int fromLine, int deltaMs) {
    _snapshot();
    lyrics.shiftTimes(deltaMs, fromLine: fromLine);
  }

  /// Remove every time from line [fromLine] on, the cursor goes there.
  void clearFrom(int fromLine) {
    _snapshot();
    lyrics.clearTimes(fromLine: fromLine);
    moveCursorToLine(fromLine);
  }

  /// Set the offset (added to every time).
  void setOffset(int offsetMs) {
    _snapshot();
    lyrics.offsetMs.v = offsetMs == 0 ? null : offsetMs;
  }

  /// Store the estimated part times of line [lineIndex] (from its start and
  /// end, in proportion of the text), as a starting point to refine.
  void estimateParts(int lineIndex) {
    var timeline = LyricsTimeline(lyrics);
    var line = timeline.lines[lineIndex];
    if (!line.isTimed) {
      return;
    }
    _snapshot();
    var offset = lyrics.offset;
    for (var part in line.parts) {
      var start = part.startMs;
      if (start != null && part.part.startMs.v == null) {
        part.part.startMs.v = max(0, start - offset);
      }
    }
  }

  /// The problems of the timing: times going backwards, parts outside their
  /// line.
  List<LyricsTimingIssue> validate() {
    var issues = <LyricsTimingIssue>[];
    int? previous;
    var lines = _lines;
    for (var l = 0; l < lines.length; l++) {
      var line = lines[l];
      var start = line.startMs.v;
      var end = line.endMs.v;
      if (start != null) {
        if (previous != null && start < previous) {
          issues.add(
            LyricsTimingIssue(
              LyricsUnitRef(l),
              'starts before the line before',
            ),
          );
        }
        if (end != null && end <= start) {
          issues.add(
            LyricsTimingIssue(LyricsUnitRef(l), 'ends before it starts'),
          );
        }
      }
      var parts = line.partList;
      var previousPart = start;
      for (var p = 0; p < parts.length; p++) {
        var partStart = parts[p].startMs.v;
        if (partStart == null) {
          continue;
        }
        if (previousPart != null && partStart < previousPart) {
          issues.add(
            LyricsTimingIssue(
              LyricsUnitRef(l, p),
              'starts before the part before',
            ),
          );
        }
        if (end != null && partStart > end) {
          issues.add(
            LyricsTimingIssue(LyricsUnitRef(l, p), 'starts after the line end'),
          );
        }
        previousPart = partStart;
      }
      previous = previousPart ?? previous;
    }
    return issues;
  }
}
