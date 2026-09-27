/// Writes the sample songs to `assets/samples/`: the lyrics files, and the
/// audio encoded to mp3 (128 kbps mono) with ffmpeg (libmp3lame).
///
/// ```sh
/// dart run tool/generate_samples.dart
/// ```
library;

import 'dart:io';

import 'package:lyrics_editor_app/src/samples/lyrics_sample_songs.dart';
import 'package:path/path.dart';

Future<void> main() async {
  var dir = Directory(join('assets', 'samples'));
  await dir.create(recursive: true);
  var temp = await Directory.systemTemp.createTemp('lyrics_samples');
  try {
    for (var song in lyricsSampleSongs) {
      var lyrics = File(join(dir.path, song.lyricsFileName));
      await lyrics.writeAsBytes(song.lyricsFileBytes());
      stdout.writeln('${lyrics.path} ${await lyrics.length()} bytes');
      for (var name in song.audioFileNames) {
        var wav = File(
          join(temp.path, '${basenameWithoutExtension(name)}.wav'),
        );
        await wav.writeAsBytes(song.audioWavContent(name));
        var mp3 = File(join(dir.path, name));
        var result = await Process.run('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-y',
          '-i',
          wav.path,
          '-codec:a',
          'libmp3lame',
          '-b:a',
          lyricsSampleMp3Bitrate,
          '-ac',
          '1',
          '-ar',
          '$lyricsSampleRate',
          // No encoder version: the same file every time.
          '-fflags',
          '+bitexact',
          '-flags:a',
          '+bitexact',
          '-metadata',
          'title=${song.title}',
          '-metadata',
          'artist=${song.artist}',
          mp3.path,
        ]);
        if (result.exitCode != 0) {
          throw StateError('ffmpeg ${mp3.path}: ${result.stderr}');
        }
        stdout.writeln('${mp3.path} ${await mp3.length()} bytes');
      }
    }
    // The older wav samples.
    await for (var entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.wav')) {
        await entity.delete();
        stdout.writeln('${entity.path} deleted');
      }
    }
  } finally {
    await temp.delete(recursive: true);
  }
}
