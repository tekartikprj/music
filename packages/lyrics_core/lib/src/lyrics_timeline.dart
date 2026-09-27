/// The effective timing of lyrics: what the stored (partial) times mean once
/// derived, estimated and offset, and where a media position falls in them.
library;

import 'dart:math';

import 'lyrics_model.dart';
import 'media_range.dart';

/// The effective timing of one part.
class LyricsTimelinePart {
  /// Index of the part in its line.
  final int index;

  /// The part.
  final CvLyricsPart part;

  /// Effective start (offset applied), null when it cannot be derived.
  final int? startMs;

  /// Effective end (offset applied), null when it cannot be derived.
  final int? endMs;

  /// True when [startMs] is an estimate (proportional to the text length
  /// between two known times), not a stored time.
  final bool estimated;

  /// The effective timing of one part.
  const LyricsTimelinePart({
    required this.index,
    required this.part,
    required this.startMs,
    required this.endMs,
    required this.estimated,
  });

  /// True when the part has an effective start.
  bool get isTimed => startMs != null;

  @override
  String toString() =>
      'Part($index, ${part.textOrEmpty}, $startMs-$endMs${estimated ? '~' : ''})';
}

/// The effective timing of one line.
class LyricsTimelineLine {
  /// Index of the line in the lyrics.
  final int index;

  /// The line.
  final CvLyricsLine line;

  /// Its parts.
  final List<LyricsTimelinePart> parts;

  /// Effective start (offset applied), null for an untimed line.
  final int? startMs;

  /// Effective end: the stored end, the last part end, else the next line
  /// start. Null when none is known (an untimed or last line).
  final int? endMs;

  /// Where singing stops for the gap computation: like [endMs] but never
  /// running to the next line start across a long instrumental break (an
  /// estimate from the last known time instead, see [LyricsTimeline]).
  final int? sungEndMs;

  /// Index of the page the line is on.
  final int pageIndex;

  /// The effective timing of one line.
  const LyricsTimelineLine({
    required this.index,
    required this.line,
    required this.parts,
    required this.startMs,
    required this.endMs,
    required this.sungEndMs,
    required this.pageIndex,
  });

  /// True when the line has an effective start.
  bool get isTimed => startMs != null;

  @override
  String toString() => 'Line($index, $startMs-$endMs, page $pageIndex)';
}

/// A page: lines shown together.
class LyricsTimelinePage {
  /// Index of the page.
  final int index;

  /// Index of its first line.
  final int firstLine;

  /// Index after its last line.
  final int endLine;

  /// When the page is shown (offset applied), null when untimed; the first
  /// page is shown from 0.
  final int? showMs;

  /// A page.
  const LyricsTimelinePage({
    required this.index,
    required this.firstLine,
    required this.endLine,
    required this.showMs,
  });

  /// Number of lines on the page.
  int get lineCount => endLine - firstLine;

  @override
  String toString() => 'Page($index, $firstLine..$endLine, $showMs)';
}

/// Where a media position falls in the lyrics.
class LyricsLocation {
  /// The page shown, 0 before anything.
  final int pageIndex;

  /// The current line: the last one started, -1 before the first line.
  final int lineIndex;

  /// The current part in [lineIndex], -1 when the line has no timed part
  /// started yet.
  final int partIndex;

  /// How far into the current part, 0 to 1.
  final double partProgress;

  /// How far into the current line, 0 to 1 (1 once it ended).
  final double lineProgress;

  /// True while the current line is being sung (between its start and end).
  final bool singing;

  /// Where a media position falls.
  const LyricsLocation({
    required this.pageIndex,
    required this.lineIndex,
    required this.partIndex,
    required this.partProgress,
    required this.lineProgress,
    required this.singing,
  });

  /// Before the first line.
  static const start = LyricsLocation(
    pageIndex: 0,
    lineIndex: -1,
    partIndex: -1,
    partProgress: 0,
    lineProgress: 0,
    singing: false,
  );

  @override
  bool operator ==(Object other) =>
      other is LyricsLocation &&
      other.pageIndex == pageIndex &&
      other.lineIndex == lineIndex &&
      other.partIndex == partIndex &&
      other.partProgress == partProgress &&
      other.lineProgress == lineProgress &&
      other.singing == singing;

  @override
  int get hashCode => Object.hash(
    pageIndex,
    lineIndex,
    partIndex,
    partProgress,
    lineProgress,
    singing,
  );

  @override
  String toString() =>
      'Location(page $pageIndex, line $lineIndex, part $partIndex '
      '${partProgress.toStringAsFixed(2)}, '
      'line ${lineProgress.toStringAsFixed(2)}${singing ? ', singing' : ''})';
}

/// Options of the timeline derivation.
class LyricsTimelineOptions {
  /// Lines per page when the lyrics have no explicit page break.
  final int linesPerPage;

  /// How long before its first line a page is shown, by default.
  final int pageLeadInMs;

  /// For the gap computation: how long after the last known time of a line
  /// without end singing is assumed to go on, at most (a line timed only by
  /// its start: an estimate from its length, capped by this).
  final int maxImplicitLineMs;

  /// Milliseconds per character to estimate how long a line without end is
  /// sung.
  final int msPerChar;

  /// Options.
  const LyricsTimelineOptions({
    this.linesPerPage = 2,
    this.pageLeadInMs = 2000,
    this.maxImplicitLineMs = 8000,
    this.msPerChar = 120,
  });
}

/// The effective timing of [CvLyrics].
///
/// Stored times are partial by design (a line timed by its start only,
/// syllables timed for the chorus only); this derives the rest:
///
/// - a line start is its own, else the one of its first timed part;
/// - a line end is its own, else its last part end, else the next line start;
/// - a part start is its own; between two known times, untimed parts get an
///   estimate proportional to their text length ([LyricsTimelinePart.estimated]);
/// - a part end is its own, else the next part start, else the line end.
///
/// Every time has the lyrics offset applied.
class LyricsTimeline {
  /// The lyrics.
  final CvLyrics lyrics;

  /// The options.
  final LyricsTimelineOptions options;

  /// The lines.
  late final List<LyricsTimelineLine> lines;

  /// The pages.
  late final List<LyricsTimelinePage> pages;

  /// The timed lines, in start order (for locating).
  late final List<LyricsTimelineLine> _timedLines;

  /// The effective timing of [lyrics].
  LyricsTimeline(this.lyrics, {this.options = const LyricsTimelineOptions()}) {
    _build();
  }

  /// True when at least one line is timed.
  bool get isTimed => _timedLines.isNotEmpty;

  void _build() {
    var offset = lyrics.offset;
    int? off(int? ms) => ms == null ? null : max(0, ms + offset);
    var sourceLines = lyrics.lineList;

    // Line starts first: a line end may need the next line start.
    var starts = <int?>[];
    for (var line in sourceLines) {
      var start = line.startMs.v;
      if (start == null) {
        for (var part in line.partList) {
          if (part.startMs.v != null) {
            start = part.startMs.v;
            break;
          }
        }
      }
      starts.add(off(start));
    }
    int? nextStart(int index) {
      for (var i = index + 1; i < starts.length; i++) {
        if (starts[i] != null) {
          return starts[i];
        }
      }
      return null;
    }

    // Pages.
    var explicitPages = sourceLines.skip(1).any((line) => line.isNewPage);
    var pageFirstLines = <int>[];
    for (var i = 0; i < sourceLines.length; i++) {
      if (i == 0) {
        pageFirstLines.add(0);
      } else if (explicitPages) {
        if (sourceLines[i].isNewPage) {
          pageFirstLines.add(i);
        }
      } else if (i % max(1, options.linesPerPage) == 0) {
        pageFirstLines.add(i);
      }
    }
    var pageOfLine = List<int>.filled(sourceLines.length, 0);
    for (var p = 0; p < pageFirstLines.length; p++) {
      var end = p + 1 < pageFirstLines.length
          ? pageFirstLines[p + 1]
          : sourceLines.length;
      for (var i = pageFirstLines[p]; i < end; i++) {
        pageOfLine[i] = p;
      }
    }

    var builtLines = <LyricsTimelineLine>[];
    for (var i = 0; i < sourceLines.length; i++) {
      var line = sourceLines[i];
      var start = starts[i];
      var partList = line.partList;
      // Explicit part ends: the last one may give the line end.
      int? lastPartEnd;
      for (var part in partList.reversed) {
        if (part.endMs.v != null) {
          lastPartEnd = off(part.endMs.v);
          break;
        }
        if (part.startMs.v != null) {
          break;
        }
      }
      var ownEnd = off(line.endMs.v) ?? lastPartEnd;
      var next = nextStart(i);
      var end = ownEnd ?? next;
      if (start == null) {
        end = null;
      }
      // Part starts: explicit, the line start for the first part, estimated
      // in between.
      var partStarts = List<int?>.filled(partList.length, null);
      var estimated = List<bool>.filled(partList.length, false);
      for (var p = 0; p < partList.length; p++) {
        partStarts[p] = off(partList[p].startMs.v);
      }
      if (partList.isNotEmpty && partStarts[0] == null) {
        partStarts[0] = start;
      }
      if (start != null) {
        var anchorIndex = 0;
        var anchorMs = partStarts[0] ?? start;
        for (var p = 1; p <= partList.length; p++) {
          var known = p < partList.length ? partStarts[p] : end;
          if (known == null) {
            continue;
          }
          // Estimate the parts between anchorIndex (excluded) and p.
          if (p - anchorIndex > 1 && known > anchorMs) {
            var weights = <int>[];
            for (var q = anchorIndex; q < p; q++) {
              weights.add(max(1, partList[q].textOrEmpty.length));
            }
            var total = weights.fold<int>(0, (a, b) => a + b);
            var acc = weights[0];
            for (var q = anchorIndex + 1; q < p; q++) {
              partStarts[q] = anchorMs + ((known - anchorMs) * acc) ~/ total;
              estimated[q] = true;
              acc += weights[q - anchorIndex];
            }
          }
          anchorIndex = p;
          anchorMs = known;
        }
      }
      var parts = <LyricsTimelinePart>[];
      for (var p = 0; p < partList.length; p++) {
        var partEnd = off(partList[p].endMs.v);
        if (partEnd == null) {
          for (var q = p + 1; q < partList.length; q++) {
            if (partStarts[q] != null) {
              partEnd = partStarts[q];
              break;
            }
          }
          partEnd ??= end;
        }
        parts.add(
          LyricsTimelinePart(
            index: p,
            part: partList[p],
            startMs: partStarts[p],
            endMs: partStarts[p] == null ? null : partEnd,
            estimated: estimated[p],
          ),
        );
      }
      // Sung end: never across a long break when the end is not known, an
      // estimate from the text left after the last known time instead.
      int? sungEnd;
      if (start != null) {
        if (ownEnd != null) {
          sungEnd = ownEnd;
        } else {
          var lastKnownIndex = 0;
          var lastKnown = start;
          for (var p = partList.length - 1; p > 0; p--) {
            var ms = off(partList[p].startMs.v);
            if (ms != null) {
              lastKnownIndex = p;
              lastKnown = ms;
              break;
            }
          }
          var chars = 0;
          for (var p = lastKnownIndex; p < partList.length; p++) {
            chars += partList[p].textOrEmpty.length + 1;
          }
          var estimate = min(
            max(1000, chars * options.msPerChar),
            max(1000, options.maxImplicitLineMs),
          );
          sungEnd = lastKnown + estimate;
          if (next != null && next < sungEnd) {
            sungEnd = max(lastKnown, next);
          }
        }
      }
      builtLines.add(
        LyricsTimelineLine(
          index: i,
          line: line,
          parts: parts,
          startMs: start,
          endMs: end,
          sungEndMs: sungEnd,
          pageIndex: pageOfLine[i],
        ),
      );
    }
    lines = builtLines;
    _timedLines = builtLines.where((line) => line.isTimed).toList()
      ..sort((a, b) => a.startMs!.compareTo(b.startMs!));

    // Page show times.
    var builtPages = <LyricsTimelinePage>[];
    for (var p = 0; p < pageFirstLines.length; p++) {
      var first = pageFirstLines[p];
      var end = p + 1 < pageFirstLines.length
          ? pageFirstLines[p + 1]
          : sourceLines.length;
      int? show;
      if (p == 0) {
        show = 0;
      } else {
        show = off(sourceLines[first].pageMs.v);
        if (show == null) {
          int? firstStart;
          for (var i = first; i < end; i++) {
            if (builtLines[i].startMs != null) {
              firstStart = builtLines[i].startMs;
              break;
            }
          }
          if (firstStart != null) {
            show = max(0, firstStart - options.pageLeadInMs);
            // Not before the previous page is sung.
            int? previousEnd;
            for (var i = first - 1; i >= pageFirstLines[p - 1]; i--) {
              var line = builtLines[i];
              previousEnd = line.line.endMs.v != null
                  ? line.endMs
                  : line.sungEndMs;
              if (previousEnd != null) {
                break;
              }
            }
            if (previousEnd != null && previousEnd > show) {
              show = min(previousEnd, firstStart);
            }
          }
        }
      }
      builtPages.add(
        LyricsTimelinePage(
          index: p,
          firstLine: first,
          endLine: end,
          showMs: show,
        ),
      );
    }
    pages = builtPages;
  }

  /// The page shown at [ms]: the last page whose show time is reached; a
  /// page without show time follows the previous one.
  int pageAt(int ms) {
    var result = 0;
    for (var page in pages) {
      var show = page.showMs;
      if (show != null && show <= ms) {
        result = page.index;
      } else if (show != null) {
        break;
      }
    }
    return result;
  }

  /// Where [ms] (media time) falls in the lyrics.
  LyricsLocation locate(int ms) {
    var pageIndex = pageAt(ms);
    if (_timedLines.isEmpty) {
      return LyricsLocation.start;
    }
    // Last timed line started at or before ms (binary search).
    var low = 0;
    var high = _timedLines.length - 1;
    var found = -1;
    while (low <= high) {
      var mid = (low + high) >> 1;
      if (_timedLines[mid].startMs! <= ms) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (found < 0) {
      return LyricsLocation(
        pageIndex: pageIndex,
        lineIndex: -1,
        partIndex: -1,
        partProgress: 0,
        lineProgress: 0,
        singing: false,
      );
    }
    var line = _timedLines[found];
    // A line started on a later page than the one shown: show its page.
    if (line.pageIndex > pageIndex) {
      pageIndex = line.pageIndex;
    }
    var start = line.startMs!;
    var end = line.endMs;
    var lineProgress = end == null || end <= start
        ? (end == null ? 0.0 : 1.0)
        : ((ms - start) / (end - start)).clamp(0.0, 1.0);
    var singing = end == null ? true : ms < end;
    var partIndex = -1;
    var partProgress = 0.0;
    for (var part in line.parts) {
      var partStart = part.startMs;
      if (partStart == null || partStart > ms) {
        continue;
      }
      partIndex = part.index;
      var partEnd = part.endMs;
      if (partEnd == null || partEnd <= partStart) {
        partProgress = partEnd == null ? 0 : 1;
      } else {
        partProgress = ((ms - partStart) / (partEnd - partStart)).clamp(
          0.0,
          1.0,
        );
      }
    }
    if (!singing) {
      lineProgress = 1;
      if (partIndex >= 0) {
        partProgress = 1;
      }
    }
    return LyricsLocation(
      pageIndex: pageIndex,
      lineIndex: line.index,
      partIndex: partIndex,
      partProgress: partProgress,
      lineProgress: lineProgress,
      singing: singing,
    );
  }

  /// The ranges of media time where something is sung, extended by
  /// [leadInMs] before and [tailMs] after, merged when less than [gapMinMs]
  /// apart. The first range starts at 0 when the intro is shorter than
  /// [gapMinMs]. Empty when nothing is timed.
  List<MediaRange> sungRanges({
    int leadInMs = 3000,
    int tailMs = 1500,
    int gapMinMs = 8000,
  }) {
    var raw = <MediaRange>[];
    for (var line in lines) {
      var start = line.startMs;
      if (start == null) {
        continue;
      }
      var end = line.sungEndMs ?? start;
      raw.add(MediaRange(max(0, start - leadInMs), max(start, end) + tailMs));
    }
    if (raw.isEmpty) {
      return raw;
    }
    raw.sort((a, b) => a.fromMs.compareTo(b.fromMs));
    var merged = <MediaRange>[];
    for (var range in raw) {
      if (merged.isEmpty) {
        merged.add(range.fromMs < gapMinMs ? MediaRange(0, range.toMs) : range);
        continue;
      }
      var last = merged.last;
      if (range.fromMs - last.toMs! < gapMinMs) {
        merged[merged.length - 1] = MediaRange(
          last.fromMs,
          max(last.toMs!, range.toMs!),
        );
      } else {
        merged.add(range);
      }
    }
    return merged;
  }
}
