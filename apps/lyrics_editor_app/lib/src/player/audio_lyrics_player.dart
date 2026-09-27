/// The audio files of a document, played by just_audio (through playlr):
/// every track loaded, switching keeps the position.
library;

import 'dart:async';

import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import '../data/lyrics_opener.dart';

class _Track {
  final String name;
  final AppAudioPlayer player;
  final subscriptions = <StreamSubscription>[];
  var playing = false;
  Duration? duration;
  var positionMs = 0;

  _Track(this.name, this.player);
}

/// A player of the audio tracks of a document (the song, the vocals, the
/// instrumental), the first one playing first.
class AudioLyricsPlayer
    implements LyricsPlayer, LyricsPlayerTracks, LyricsPlayerMute {
  final List<_Track> _tracks;
  var _current = 0;
  var _rate = 1.0;
  var _muted = false;
  final _reports = StreamController<LyricsPlayerReport>.broadcast();

  AudioLyricsPlayer._(this._tracks) {
    for (var track in _tracks) {
      track.subscriptions
        ..add(
          track.player.positionStream.listen((position) {
            if (position != null) {
              track.positionMs = position.inMilliseconds;
              _emit(track);
            }
          }),
        )
        ..add(
          track.player.stateStream.listen((state) {
            track.playing = state.playing;
            track.duration = state.duration ?? track.duration;
            _emit(track);
          }),
        );
    }
  }

  /// Load every track of [tracks] (their whole content, in memory);
  /// [createPlayer] defaults to just_audio.
  static Future<AudioLyricsPlayer> open(
    List<LyricsOpenedTrack> tracks, {
    AppAudioPlayer Function()? createPlayer,
  }) async {
    var loaded = <_Track>[];
    for (var track in tracks) {
      var bytes = await track.file.readAsBytes();
      var player = createPlayer?.call() ?? AppAudioPlayerJustAudio();
      player.loadBytes(bytes);
      loaded.add(_Track(track.name, player));
    }
    return AudioLyricsPlayer._(loaded);
  }

  _Track get _track => _tracks[_current];

  void _emit(_Track track) {
    if (!identical(track, _track) || _reports.isClosed) {
      return;
    }
    _reports.add(
      LyricsPlayerReport(
        positionMs: track.positionMs,
        playing: track.playing,
        rate: _rate,
      ),
    );
  }

  @override
  Stream<LyricsPlayerReport> get reports => _reports.stream;

  @override
  int? get durationMs => _track.duration?.inMilliseconds;

  @override
  List<double> get rates => lyricsPlayerDefaultRates;

  @override
  List<String> get tracks => [for (var track in _tracks) track.name];

  @override
  String? get track => _track.name;

  @override
  Future<void> play() async {
    // Completes when the playback stops: not awaited.
    unawaited(_track.player.play());
  }

  @override
  Future<void> pause() => _track.player.pause();

  @override
  Future<void> seek(int positionMs) async {
    var track = _track;
    track.positionMs = positionMs;
    _emit(track);
    await track.player.seek(Duration(milliseconds: positionMs));
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    for (var track in _tracks) {
      await track.player.setPlaybackRate(rate);
    }
    _emit(_track);
  }

  @override
  Future<void> selectTrack(String name) async {
    var index = _tracks.indexWhere((track) => track.name == name);
    if (index < 0 || index == _current) {
      return;
    }
    var from = _track;
    var playing = from.playing;
    var positionMs = from.positionMs;
    await from.player.pause();
    _current = index;
    var to = _track;
    await to.player.setVolume(_muted ? 0 : 1);
    await seek(positionMs);
    if (playing) {
      await play();
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _track.player.setVolume(muted ? 0 : 1);
  }

  @override
  Future<void> dispose() async {
    for (var track in _tracks) {
      for (var subscription in track.subscriptions) {
        await subscription.cancel();
      }
      try {
        await track.player.stop();
      } catch (_) {}
    }
    await _reports.close();
  }
}
