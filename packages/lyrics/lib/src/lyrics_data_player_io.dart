import 'dart:io';

import 'lyrics_data_player.dart';

/// A [LyricsDataPlayer] implementation that prints the lyrics to the console.
class LyricsDataPlayerIo extends LyricsDataPlayerBase {
  @override
  void onPlayText(String text) {
    stdout.write(text);
  }
}
