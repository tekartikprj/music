// ignore_for_file: avoid_print

import 'package:tekartik_lyrics/example/une_souris_verte_lrc.dart';
import 'package:tekartik_lyrics/lyrics.dart';
import 'package:tekartik_lyrics/src/lrc_parser.dart';

void main() {
  var lyric = parseLyric(lrcUneSourisVerte);
  print('lyric: $lyric');
  var lyricLines = lyric.lines;
  for (var i = 0; i < lyricLines.length; i++) {
    var line = lyricLines[i];

    print('$line');
  }
}
