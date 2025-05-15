/// Lyric data model
class LyricsData {
  /// Title of the media
  final String? title;

  /// Artist of the media
  final String? artist;

  /// Song duration
  final Duration? duration;

  /// Lines of the lyric
  final List<LyricsLineData> lines;

  /// Constructor
  LyricsData({
    required this.title,
    required this.artist,
    required this.lines,
    this.duration,
  });

  @override
  String toString() {
    return 'LyricData{title: $title, artist: $artist, duration: $duration, lines: ${lines.length}}';
  }
}

/// Lyric line content
abstract class LyricsLineContent {
  /// Duration at which the line should be displayed
  final Duration time;

  /// The text of the line
  String get text;

  /// Constructor
  LyricsLineContent({required this.time});
}

/// Lyric line content with a single part
class LyricsLineSingleContent extends LyricsLineContent {
  /// Content of the line
  final LyricsPartData part;

  /// Text
  @override
  String get text => part.text;

  /// Constructor
  LyricsLineSingleContent({required super.time, required this.part});

  @override
  String toString() {
    return '[${formatLyricsDuration(part.time)}] ${part.text}';
  }
}

/// Lyric line content with multiple parts
class LyricsLineMultiContent extends LyricsLineContent {
  /// Content of the line
  final List<LyricsPartData> parts;

  /// Constructor
  LyricsLineMultiContent({
    required super.time,
    required this.parts,
    required this.text,
  });

  @override
  final String text;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('[');
    buffer.write(formatLyricsDuration(time));
    buffer.write('] ');
    for (var part in parts) {
      buffer.write(part);
    }
    return buffer.toString();
  }
}

/// Lyric line data
class LyricsLineData {
  /// Parts of the line
  List<LyricsPartData> get parts {
    if (content is LyricsLineSingleContent) {
      return [(content as LyricsLineSingleContent).part];
    } else if (content is LyricsLineMultiContent) {
      return (content as LyricsLineMultiContent).parts;
    } else {
      throw 'Unknown content type ${content.runtimeType}';
    }
  }

  /// Content of the line, if empty means the end of the line
  final LyricsLineContent content;

  /// Constructor
  LyricsLineData({required this.content});

  /// Duration at which the line should be displayed
  Duration get time => content.time;

  /// Text
  String get text => content.text;

  @override
  String toString() => content.toString();
}

/// Lyric part data
String formatLyricsDuration(Duration duration) {
  var milliseconds = duration.inMilliseconds;
  var seconds = (milliseconds ~/ 1000) % 60;
  var minutes = (milliseconds ~/ (1000 * 60)) % 60;
  milliseconds = milliseconds % 1000;

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
      '.${((milliseconds ~/ 10) % 100).toString().padLeft(2, '0')}';
}

/// Lyric part data
class LyricsPartData {
  /// Duration at which the line should be displayed
  final Duration time;

  /// Text
  final String text;

  /// Constructor
  LyricsPartData({required this.time, required this.text});

  @override
  String toString() {
    return '<${formatLyricsDuration(time)}>"$text"';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LyricsPartData) return false;
    return time == other.time && text == other.text;
  }

  @override
  int get hashCode => time.hashCode ^ text.hashCode;
}

/// Lyrics data extension
extension LyricsDataExt on LyricsData {
  /// Convert the lyrics data to LRC format
  List<String> toLrcLines() {
    var lines = <String>[];
    for (var line in this.lines) {
      lines.add(line.toLrcLine());
    }
    return lines;
  }
}

/// Lyrics line data extension
extension LyricsLineDataExt on LyricsLineData {
  /// Convert the line to LRC format
  String toLrcLine() {
    var sb = StringBuffer();
    sb.write('[${formatLyricsDuration(time)}]');
    var first = true;
    for (var part in parts) {
      var partTime = part.time;
      var skipTime = false;
      if (first) {
        if (partTime == time) {
          skipTime = true;
        }
        first = false;
      }
      if (!skipTime) {
        sb.write('<${formatLyricsDuration(partTime)}>');
      }
      sb.write(part.text);
    }
    return sb.toString();
  }
}
