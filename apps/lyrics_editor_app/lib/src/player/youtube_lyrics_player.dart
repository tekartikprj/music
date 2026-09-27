/// A YouTube video, played by the festenao backend (the iframe on the web,
/// media_kit elsewhere), shown by the editor.
library;

import 'dart:async';

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter/widgets.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

/// The rates a YouTube video plays at (the iframe: 0.25 to 2).
const youtubeLyricsPlayerRates = [
  0.25,
  0.5,
  0.75,
  0.8,
  0.9,
  1.0,
  1.1,
  1.25,
  1.5,
  2.0,
];

/// A YouTube video.
class YoutubeLyricsPlayer
    implements LyricsPlayer, LyricsPlayerView, LyricsPlayerMute {
  /// The backend.
  final YtPlayerBackend backend;

  final _reports = StreamController<LyricsPlayerReport>.broadcast();

  YoutubeLyricsPlayer._(this.backend) {
    backend.playback.addListener(_emit);
  }

  /// Open [source], ready to play (not playing); [backend] defaults to the
  /// platform one.
  static Future<YoutubeLyricsPlayer> open(
    YtVideoSource source, {
    YtPlayerBackend? backend,
  }) async {
    backend ??= createYtPlayerBackend();
    await backend.initialize();
    await backend.open(
      YtPlaylistEntry(videoId: source.videoId),
      autoPlay: false,
      start: source.start,
    );
    return YoutubeLyricsPlayer._(backend);
  }

  void _emit() {
    if (_reports.isClosed) {
      return;
    }
    var state = backend.playback.value;
    _reports.add(
      LyricsPlayerReport(
        positionMs: state.position.inMilliseconds,
        playing: state.playing,
        // The rate that took effect (the iframe rounds it).
        rate: state.playbackRate,
      ),
    );
  }

  @override
  Stream<LyricsPlayerReport> get reports => _reports.stream;

  @override
  int? get durationMs {
    var duration = backend.playback.value.duration;
    return duration == Duration.zero ? null : duration.inMilliseconds;
  }

  @override
  List<double> get rates => youtubeLyricsPlayerRates;

  @override
  Future<void> play() => backend.play();

  @override
  Future<void> pause() => backend.pause();

  @override
  Future<void> seek(int positionMs) =>
      backend.seek(Duration(milliseconds: positionMs));

  @override
  Future<void> setRate(double rate) => backend.setPlaybackRate(rate);

  @override
  Future<void> setMuted(bool muted) => backend.setMuted(muted);

  @override
  Widget buildView(BuildContext context) => backend.buildVideoView(context);

  @override
  Future<void> dispose() async {
    backend.playback.removeListener(_emit);
    await _reports.close();
    await backend.dispose();
  }
}
