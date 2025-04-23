import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:tekaly_lyrics/src/lyrics.dart';
import 'package:tekartik_common_utils/string_utils.dart';

/// Parses a LRC lyric duration string and returns a [Duration] object.
Duration? tryParseLyricDuration(String token) {
  var filtered = token.split(']').first.split('>').first;
  var minutes = filtered.split(':').first;
  var secondsAndMillis = filtered.substring(minutes.length + 1);
  var parts = secondsAndMillis.split('.');
  var seconds = parts.first;
  var millis = 0;
  if (parts.length > 1) {
    var millisString = parts[1].trim();
    var number = millisString.tryParseInt();
    if (number != null) {
      if (millisString.length == 1) {
        millis = number * 100;
      } else if (millisString.length == 2) {
        millis = number * 10;
      } else if (millisString.length == 3) {
        millis = number;
      }
    }
  }
  var minutesInt = minutes.tryParseInt();
  var secondsInt = seconds.tryParseInt();
  if (minutesInt == null || secondsInt == null) {
    return null;
  }
  return Duration(
    minutes: minutesInt,
    seconds: secondsInt,
    milliseconds: millis,
  );
}

/// Parses a LRC lyric duration string and returns a [Duration] object.
Duration parseLyricDurationLrc(String token) {
  return tryParseLyricDuration(token) ?? Duration.zero;
}

/// Parses a LRC lyric string and returns a [LyricsData] object.
LyricsData parseLyricLrc(String input) {
  var lines = LineSplitter.split(input).toList();
  String? author;
  String? title;
  var lyricLines = <LyricsLineData>[];
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

  final lyricData = LyricsData(artist: author, title: title, lines: lyricLines);
  return lyricData;
}

/// Parses a LRC lyric line and returns a [LyricsLineData] object.
@visibleForTesting
LyricsLineData parseLyricLine(String durationToken, String line) {
  var parseResult = parseLyricLineContent(
    parseLyricDurationLrc(durationToken),
    line,
  );
  if (parseResult.parts.isEmpty) {
    return LyricsLineData(
      content: LyricsLineSingleContent(
        time: parseResult.time,
        part: LyricsPartData(time: parseResult.time, text: parseResult.text),
      ),
    );
  } else {
    return LyricsLineData(
      content: LyricsLineMultiContent(
        time: parseResult.time,
        parts: parseResult.parts,
        text: parseResult.text,
      ),
    );
  }
}

/// Parser result
class LyricsLineContentParserResult {
  /// Empty for line without time info
  final List<LyricsPartData> parts;

  /// The text of the line
  final String text;

  /// The time of the line
  final Duration time;

  /// Constructor
  LyricsLineContentParserResult({
    required this.parts,
    required this.text,
    required this.time,
  });
}

class _LyricsLineParser {
  LyricsLineContentParserResult parseLyricLineContent(
    Duration time,
    String line,
  ) {
    var lineTime = time;
    var current = line.trim();
    var fullLineSb = StringBuffer();
    var parts = <LyricsPartData>[];
    var needSpaceBefore = false;
    var hasParts = false;
    while (true) {
      var result = findTime(current);
      var index = result.index;

      void add(String text) {
        if (text.isNotEmpty) {
          if (text.trim().isEmpty) {
            needSpaceBefore = true;
          } else {
            text = text.trimLeft();
            if (needSpaceBefore) {
              text = ' $text';
            }

            /// next need space?
            needSpaceBefore = text.endsWithWhitespaces();
            text = text.trimRight();
            fullLineSb.write(text);
            parts.add(LyricsPartData(time: time, text: text));
            return;
          }
        }

        /// Don't add if same time than the line time
        if (time != lineTime) {
          parts.add(LyricsPartData(time: time, text: text.trim()));
        }
      }

      if (index == null) {
        if (!hasParts) {
          return LyricsLineContentParserResult(
            time: time,
            parts: parts,
            text: current,
          );
        } else {
          add(current);
        }
        break;
      }
      hasParts = true;
      var before = current.substring(0, index);
      add(before);

      time = result.time!;
      current = result.next!;
    }
    return LyricsLineContentParserResult(
      time: lineTime,
      parts: parts,
      text: fullLineSb.toString(),
    );
  }
}

/// Parses a LRC lyric line and returns a [LyricsLineData] object.
@visibleForTesting
LyricsLineContentParserResult parseLyricLineContent(
  Duration time,
  String line,
) {
  var parser = _LyricsLineParser();
  return parser.parseLyricLineContent(time, line);
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
