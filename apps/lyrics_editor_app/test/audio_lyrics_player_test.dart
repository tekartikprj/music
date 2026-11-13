import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lyrics_editor_app/src/data/lyrics_opener.dart';
import 'package:lyrics_editor_app/src/player/audio_lyrics_player.dart';
import 'package:playlr_audio_player/player.dart';

/// A song player without a platform, telling whether it was disposed.
class _FakeSongPlayer extends SongAudioPlayerImpl with SongAudioPlayerMixin {
  @override
  Future<Duration?> getCurrentPosition() async => Duration.zero;

  @override
  Future<Duration?> getDuration() async => null;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _FakeAppAudioPlayer extends AppAudioPlayer {
  final songPlayers = <_FakeSongPlayer>[];

  @override
  String get name => 'fake';

  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    var player = _FakeSongPlayer();
    songPlayers.add(player);
    return player;
  }
}

void main() {
  test('dispose releases the player of every track', () async {
    var appPlayers = <_FakeAppAudioPlayer>[];
    var player = await AudioLyricsPlayer.open(
      [
        for (var name in ['song', 'vocals'])
          LyricsOpenedTrack(
            name,
            LyricsOpenedFile.bytes('$name.mp3', Uint8List(4)),
          ),
      ],
      createPlayer: () {
        var appPlayer = _FakeAppAudioPlayer();
        appPlayers.add(appPlayer);
        return appPlayer;
      },
    );
    expect(player.tracks, ['song', 'vocals']);
    await player.dispose();
    var songPlayers = [
      for (var appPlayer in appPlayers) ...appPlayer.songPlayers,
    ];
    expect(songPlayers, hasLength(2));
    // The just_audio players (an mpv instance each on Linux) are released.
    expect(songPlayers.map((songPlayer) => songPlayer.disposed), [true, true]);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
