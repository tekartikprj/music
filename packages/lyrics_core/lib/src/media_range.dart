/// Ranges of media time: the clips of a song, the sung parts of its lyrics,
/// and what a player actually plays out of both.
library;

import 'dart:math';

/// A range of media time in milliseconds, `[fromMs, toMs)`; a null [toMs]
/// runs to the end of the media.
class MediaRange {
  /// Start, inclusive.
  final int fromMs;

  /// End, exclusive, null for the end of the media.
  final int? toMs;

  /// A range.
  const MediaRange(this.fromMs, [this.toMs]);

  /// The whole media.
  static const whole = MediaRange(0);

  /// True when [ms] is within the range.
  bool contains(int ms) => ms >= fromMs && (toMs == null || ms < toMs!);

  /// Length, null when running to an unknown end.
  int? get lengthMs => toMs == null ? null : toMs! - fromMs;

  /// The intersection with [other], null when empty.
  MediaRange? intersect(MediaRange other) {
    var from = max(fromMs, other.fromMs);
    int? to;
    if (toMs == null) {
      to = other.toMs;
    } else if (other.toMs == null) {
      to = toMs;
    } else {
      to = min(toMs!, other.toMs!);
    }
    if (to != null && to <= from) {
      return null;
    }
    return MediaRange(from, to);
  }

  @override
  bool operator ==(Object other) =>
      other is MediaRange && other.fromMs == fromMs && other.toMs == toMs;

  @override
  int get hashCode => Object.hash(fromMs, toMs);

  @override
  String toString() => 'MediaRange($fromMs, $toMs)';
}

/// What a player plays of a song, in order.
///
/// [clips] are the song's clips in their play order (they may repeat or go
/// back in time); empty means the whole media. When [sung] is given (the
/// sung ranges of the lyrics, sorted, see `LyricsTimeline.sungRanges`), each
/// clip only keeps its sung parts: the gaps are skipped. An empty [sung]
/// (untimed lyrics) skips nothing.
///
/// A range shorter than [minRangeMs] is dropped, it would only stutter.
List<MediaRange> computePlayRanges({
  List<MediaRange> clips = const [],
  List<MediaRange>? sung,
  int minRangeMs = 200,
}) {
  var base = clips.isEmpty ? const [MediaRange.whole] : clips;
  if (sung == null || sung.isEmpty) {
    return List.of(base);
  }
  var result = <MediaRange>[];
  for (var clip in base) {
    for (var range in sung) {
      var piece = clip.intersect(range);
      if (piece == null) {
        continue;
      }
      var length = piece.lengthMs;
      if (length != null && length < minRangeMs) {
        continue;
      }
      result.add(piece);
    }
  }
  return result;
}

/// Where to go from [positionMs] when playing [ranges] (the current range is
/// [rangeIndex]): null to keep playing, the index of the range to seek to,
/// or `ranges.length` when the last range is done (next song).
///
/// [durationMs] ends a range running to the end of the media.
int? nextPlayRangeIndex(
  List<MediaRange> ranges,
  int rangeIndex,
  int positionMs, {
  int? durationMs,
}) {
  if (rangeIndex < 0 || rangeIndex >= ranges.length) {
    return null;
  }
  var range = ranges[rangeIndex];
  var end = range.toMs ?? durationMs;
  if (end == null || positionMs < end) {
    return null;
  }
  return rangeIndex + 1;
}
