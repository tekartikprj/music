/// The sample songs bundled with the app (`assets/samples/`).
library;

import 'package:flutter/services.dart';

import '../data/lyrics_opener.dart';
import 'lyrics_sample_songs.dart';

export 'lyrics_sample_songs.dart' show LyricsSampleSong, lyricsSampleSongs;

/// The asset folder of the samples.
const lyricsSamplesAssetDir = 'assets/samples';

/// The files of [song], read from the app assets: opened together, they pair
/// by name like files next to each other.
Future<List<LyricsOpenedFile>> loadLyricsSampleFiles(
  LyricsSampleSong song, {
  AssetBundle? bundle,
}) async {
  bundle ??= rootBundle;
  return [
    for (var name in song.fileNames)
      LyricsOpenedFile.bytes(
        name,
        (await bundle.load(
          '$lyricsSamplesAssetDir/$name',
        )).buffer.asUint8List(),
      ),
  ];
}
