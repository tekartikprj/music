/// Lyric data model
class LyricData {
  /// Title of the media
  final String? title;

  /// Artist of the media
  final String? artist;

  /// Song duration
  final Duration? duration;

  /// Lines of the lyric
  final List<LyricLineData> lines;

  /// Constructor
  LyricData({
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
abstract class LyricLineContent {
  /// Duration at which the line should be displayed
  final Duration time;

  /// Constructor
  LyricLineContent({required this.time});
}

/// Lyric line content with a single part
class LyricLineSingleContent extends LyricLineContent {
  /// Content of the line
  final LyricPartData part;

  /// Constructor
  LyricLineSingleContent({required super.time, required this.part});

  @override
  String toString() {
    return '[${formatLyricDuration(part.time)}] ${part.content}';
  }
}

/// Lyric line content with multiple parts
class LyricLineMultiContent extends LyricLineContent {
  /// Content of the line
  final List<LyricPartData> parts;

  /// Constructor
  LyricLineMultiContent({required super.time, required this.parts});

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('[');
    buffer.write(formatLyricDuration(time));
    buffer.write('] ');
    for (var part in parts) {
      buffer.write(part);
    }
    return buffer.toString();
  }
}

/// Lyric line data
class LyricLineData {
  /// Content of the line, if empty means the end of the line
  final LyricLineContent content;

  /// Constructor
  LyricLineData({required this.content});

  /// Duration at which the line should be displayed
  Duration get time => content.time;

  @override
  String toString() => content.toString();
}

/// Lyric part data
String formatLyricDuration(Duration duration) {
  var milliseconds = duration.inMilliseconds;
  var seconds = (milliseconds ~/ 1000) % 60;
  var minutes = (milliseconds ~/ (1000 * 60)) % 60;
  milliseconds = milliseconds % 1000;

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
      '.${((milliseconds ~/ 10) % 100).toString().padLeft(2, '0')}';
}

/// Lyric part data
class LyricPartData {
  /// Duration at which the line should be displayed
  final Duration time;

  /// Text
  final String content;

  /// Constructor
  LyricPartData({required this.time, required this.content});

  @override
  String toString() {
    return '<${formatLyricDuration(time)}>$content';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LyricPartData) return false;
    return time == other.time && content == other.content;
  }

  @override
  int get hashCode => time.hashCode ^ content.hashCode;
}
