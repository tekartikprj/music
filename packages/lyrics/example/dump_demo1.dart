// ignore_for_file: avoid_print

import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';

void main() {
  var lyric = parseLyricLrc(lrcDemo1);
  print('lyric: $lyric');
  var lyricLines = lyric.lines;
  for (var i = 0; i < lyricLines.length; i++) {
    var line = lyricLines[i];
    var content = line.content;
    if (content is LyricsLineSingleContent) {
      print('single content: $content');
    } else if (content is LyricsLineMultiContent) {
      var parts = content.parts;
      print('multi content:');
      for (var j = 0; j < parts.length; j++) {
        var part = parts[j];
        print('  part: $part');
      }
    }
  }
}
