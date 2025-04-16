import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tekartik_lyrics/src/lyric.dart';

/// Parses a LRC lyric duration string and returns a [Duration] object.
Duration? tryParseLyricDuration(String token) {
  var filtered = token.split(']').first.split('>').first;
  var minutes = filtered.split(':').first;
  var secondsAndMillis = filtered.substring(minutes.length + 1);
  var parts = secondsAndMillis.split('.');
  var seconds = parts.first;
  var centiseconds = parts.length > 1 ? parts[1] : '0';
  var minutesInt = minutes.tryParseInt();
  var secondsInt = seconds.tryParseInt();
  var centisecondsInt = centiseconds.tryParseInt();
  if (minutesInt == null || secondsInt == null) {
    return null;
  }
  return Duration(
    minutes: minutesInt,
    seconds: secondsInt,
    milliseconds: (centisecondsInt ?? 0) * 10,
  );
}

/// Parses a LRC lyric duration string and returns a [Duration] object.
Duration parseLyricDuration(String token) {
  return tryParseLyricDuration(token) ?? Duration.zero;
}

/// Parses a LRC lyric string and returns a [LyricData] object.
LyricData parseLyric(String input) {
  var lines = LineSplitter.split(input).toList();
  String? author;
  String? title;
  var lyricLines = <LyricLineData>[];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isNotEmpty) {
      if (line.startsWith('[')) {
        var token = line.substring(1).split(']').first;
        var remaining = line.substring(token.length + 2).trim();
        var parts = token.split(':');
        var key = parts.first;
        String getValue() {
          return token.substring(key.length + 1).trim();
        }

        if (key == 'ar') {
          author = getValue();
          continue;
        } else if (key == 'ti') {
          title = getValue();
          continue;
        } else if (key.tryParseInt() != null) {
          // This is a time tag

          var text = remaining;
          var lyricLine = parseLyricLine(token, text);

          lyricLines.add(lyricLine);
        } else {
          // print('discarding unknown tag: $line');
        }
      }
    }
  }

  final lyricData = LyricData(artist: author, title: title, lines: lyricLines);
  return lyricData;
}

/// Parses a LRC lyric line and returns a [LyricLineData] object.
@visibleForTesting
LyricLineData parseLyricLine(String durationToken, String line) {
  var current = line;
  var result = findTime(current);
  var index = result.index;
  var lineTime = parseLyricDuration(durationToken);
  if (index == null) {
    var lyricLine = LyricLineData(
      content: LyricLineSingleContent(
        time: lineTime,
        part: LyricPartData(time: lineTime, content: line),
      ),
    );
    return lyricLine;
  } else {
    var time = lineTime;
    var exitNext = false;
    var parts = <LyricPartData>[];
    while (true) {
      var before = current.substring(0, index);

      var partData = LyricPartData(time: time, content: before);

      /// set for the next iteration
      time = result.time!;

      /// Special case if the first one is empty and matches the line time
      if (parts.isEmpty && partData.time == time && partData.content.isEmpty) {
        // skip
      } else {
        parts.add(partData);
      }

      if (exitNext) {
        break;
      }
      current = result.next!;

      /// set for the next iteration
      time = result.time!;

      result = findTime(current);
      index = result.index;

      if (index == null) {
        exitNext = true;
        // Special trick to handle the last part
        result = FindTimeResult(index: current.length, next: '', time: time);
      }
    }
    return LyricLineData(
      content: LyricLineMultiContent(time: lineTime, parts: parts),
    );
  }
}

/// Finds the time tag in a LRC lyric line and returns a [FindTimeResult] object.
@visibleForTesting
FindTimeResult findTime(String content) {
  var index = content.indexOf('<');
  if (index == -1) {
    return FindTimeResult();
  }
  var endIndex = content.indexOf('>', index);
  var token = content.substring(index + 1, endIndex).trim();
  var duration = tryParseLyricDuration(token);
  if (duration == null) {
    return FindTimeResult();
  }
  var result = FindTimeResult(
    index: index,
    next: content.substring(endIndex + 1),
    time: duration,
  );
  return result;
}

@visibleForTesting
/// A class to hold the result of the findTime function.
class FindTimeResult {
  /// The index of the start of the time tag.
  final int? index;

  /// The time
  final Duration? time;

  /// The remaining content after the time tag.
  final String? next;

  /// Constructor
  FindTimeResult({this.index, this.next, this.time});

  @override
  String toString() {
    return 'FindTimeResult{index: $index, duration: $time, next: $next}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FindTimeResult) return false;
    return index == other.index && time == other.time && next == other.next;
  }

  @override
  int get hashCode => index.hashCode ^ time.hashCode ^ next.hashCode;
}
