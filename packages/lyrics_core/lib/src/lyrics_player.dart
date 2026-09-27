/// What the lyrics editor needs from a player: anything that has a media
/// time and can play, pause, seek and change speed, with or without media.
library;

import 'lyrics_clock.dart';

/// A position given by a player.
class LyricsPlayerReport {
  /// The media time, in milliseconds.
  final int positionMs;

  /// True while playing.
  final bool playing;

  /// The playback rate (1 is normal).
  final double rate;

  /// A report.
  const LyricsPlayerReport({
    required this.positionMs,
    required this.playing,
    this.rate = 1,
  });

  @override
  bool operator ==(Object other) =>
      other is LyricsPlayerReport &&
      other.positionMs == positionMs &&
      other.playing == playing &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(positionMs, playing, rate);

  @override
  String toString() =>
      'Report($positionMs ms, ${playing ? 'playing' : 'paused'}, ${rate}x)';
}

/// The playback rates a speed menu offers by default.
const lyricsPlayerDefaultRates = [
  0.5,
  0.6,
  0.7,
  0.75,
  0.8,
  0.9,
  1.0,
  1.1,
  1.2,
  1.25,
  1.5,
  2.0,
];

/// What the lyrics editor needs from a player. Every time is a media time in
/// milliseconds.
///
/// The editor owns the clock: it feeds a [LyricsClock] from [reports] (and
/// calls `clock.seek` on every seek), unless the player is a
/// [LyricsPlayerClock] that hands its own over. Loop and pre-roll are done by
/// the editor on top of [seek].
abstract class LyricsPlayer {
  /// Position reports, as often as the player gives them (every 100 to 250
  /// ms while playing), and on every play, pause, seek and rate change.
  Stream<LyricsPlayerReport> get reports;

  /// The media length, null while unknown or when there is no media.
  int? get durationMs;

  /// The rates the speed menu offers.
  List<double> get rates;

  /// Play.
  Future<void> play();

  /// Pause.
  Future<void> pause();

  /// Seek to [positionMs].
  Future<void> seek(int positionMs);

  /// Set the playback rate (1 is normal).
  Future<void> setRate(double rate);

  /// Stop and release.
  Future<void> dispose();
}

/// A player that already has a smooth clock: the editor reads it instead of
/// smoothing the reports a second time.
abstract class LyricsPlayerClock {
  /// The clock, reported by the player itself.
  LyricsClock get clock;
}

/// A player of documents with several tracks sharing the same timeline
/// (vocals and instrumental): switching keeps the position.
abstract class LyricsPlayerTracks {
  /// The track names.
  List<String> get tracks;

  /// The track playing.
  String? get track;

  /// Switch to the track [name].
  Future<void> selectTrack(String name);
}

/// A player that can be muted (the metronome click plays alone).
abstract class LyricsPlayerMute {
  /// Mute or unmute.
  Future<void> setMuted(bool muted);
}
