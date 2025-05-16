import 'package:tekaly_lyrics/src/lyrics.dart';

export 'package:tekaly_lyrics/src/duration_helper.dart'
    show TekartikLyricsIntExt;

export 'package:tekartik_common_utils/duration_utils.dart';

/// Formats a duration to a string in the LRC format
String lrcFormatDuration(Duration duration) {
  return formatLyricsDuration(duration);
}
