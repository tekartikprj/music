// ignore_for_file: avoid_print

import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/lyrics_io.dart';
import 'package:tekaly_lyrics/src/lrc_parser.dart';

Future<void> main() async {
  var lyric = parseLyricLrc(lrcDemo1);
  var player = LyricsDataPlayerIo();
  player.load(lyric);
  player.resume();
  await player.done;
}
