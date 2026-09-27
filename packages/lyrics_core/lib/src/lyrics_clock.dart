/// A smooth media position for the lyrics display, from the coarse
/// positions a player reports.
library;

/// Interpolates the media position between the reports of a player.
///
/// Players report their position every 100 to 250 ms (a youtube iframe is
/// polled), a syllable wipe needs it every frame:
/// `position = reported + (now − reportedAt) × rate` while playing, reset by
/// every report, seek, pause and rate change. A report slightly behind the
/// interpolated position (jitter) does not move the display backwards; a
/// bigger jump (a seek) does. The extrapolation stops [maxExtrapolationMs]
/// after the last report (a stalled player).
class LyricsClock {
  /// The time source, in milliseconds (a monotonic clock by default).
  final int Function() nowMs;

  /// How far behind the displayed position a report may be and still be
  /// taken as jitter.
  final int jitterMs;

  /// How long after a report the position keeps advancing on its own.
  final int maxExtrapolationMs;

  static final _stopwatch = Stopwatch()..start();

  int _reportedMs = 0;
  int _reportedAt = 0;
  var _playing = false;
  var _rate = 1.0;
  int _lastShownMs = 0;

  /// A clock.
  LyricsClock({
    int Function()? nowMs,
    this.jitterMs = 250,
    this.maxExtrapolationMs = 2000,
  }) : nowMs = nowMs ?? (() => _stopwatch.elapsedMilliseconds);

  /// True while playing.
  bool get playing => _playing;

  /// The playback rate.
  double get rate => _rate;

  /// A position report from the player.
  void report(int positionMs, {required bool playing, double? rate}) {
    var now = nowMs();
    var wasPlaying = _playing;
    var predicted = _predict(now);
    _reportedMs = positionMs;
    _reportedAt = now;
    _playing = playing;
    if (rate != null) {
      _rate = rate;
    }
    // Jitter: keep going forward from where the display is.
    if (playing &&
        wasPlaying &&
        positionMs < predicted &&
        predicted - positionMs <= jitterMs) {
      _reportedMs = predicted;
    }
  }

  /// A seek (or a new media): the position jumps, whatever the jitter rule.
  void seek(int positionMs) {
    _reportedMs = positionMs;
    _reportedAt = nowMs();
    _lastShownMs = positionMs;
  }

  /// Change the rate, the position so far is kept.
  void setRate(double rate) {
    var now = nowMs();
    _reportedMs = _predict(now);
    _reportedAt = now;
    _rate = rate;
  }

  int _predict(int now) {
    if (!_playing) {
      return _reportedMs;
    }
    var elapsed = now - _reportedAt;
    if (elapsed > maxExtrapolationMs) {
      elapsed = maxExtrapolationMs;
    }
    if (elapsed < 0) {
      elapsed = 0;
    }
    return _reportedMs + (elapsed * _rate).round();
  }

  /// The media position now, in milliseconds, never going backwards by less
  /// than [jitterMs] while playing.
  int get positionMs {
    var position = _predict(nowMs());
    if (_playing &&
        position < _lastShownMs &&
        _lastShownMs - position <= jitterMs) {
      return _lastShownMs;
    }
    _lastShownMs = position;
    return position;
  }
}
