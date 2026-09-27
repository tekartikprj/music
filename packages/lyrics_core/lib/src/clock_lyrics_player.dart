/// A player with no media: a stopwatch that plays, pauses, seeks and changes
/// speed like one.
library;

import 'dart:async';

import 'lyrics_player.dart';

/// The rates of the [ClockLyricsPlayer] speed menu.
const clockLyricsPlayerRates = [0.25, ...lyricsPlayerDefaultRates, 3.0, 4.0];

/// A player with no media, to time lyrics against a live performance or a
/// record playing elsewhere, and to make tests deterministic.
///
/// Its position starts at 0 and goes as far as needed, up to [durationMs]
/// when set (it then pauses there). It reports every [reportInterval] while
/// playing, and on every play, pause, seek and rate change.
class ClockLyricsPlayer implements LyricsPlayer {
  /// The time source, in milliseconds (a monotonic clock by default).
  final int Function() nowMs;

  /// How often the position is reported while playing.
  final Duration reportInterval;

  static final _stopwatch = Stopwatch()..start();

  @override
  int? durationMs;

  @override
  final List<double> rates;

  final _reports = StreamController<LyricsPlayerReport>.broadcast();
  Timer? _timer;
  var _baseMs = 0;
  var _startedAt = 0;
  var _playing = false;
  var _rate = 1.0;

  /// A clock player; [nowMs] can be injected for tests.
  ClockLyricsPlayer({
    int Function()? nowMs,
    this.durationMs,
    this.reportInterval = const Duration(milliseconds: 100),
    List<double>? rates,
  }) : nowMs = nowMs ?? (() => _stopwatch.elapsedMilliseconds),
       rates = rates ?? clockLyricsPlayerRates;

  @override
  Stream<LyricsPlayerReport> get reports => _reports.stream;

  /// True while playing.
  bool get playing => _playing;

  /// The playback rate.
  double get rate => _rate;

  /// The position now, in milliseconds.
  int get positionMs {
    var position = _baseMs;
    if (_playing) {
      position += ((nowMs() - _startedAt) * _rate).round();
    }
    var duration = durationMs;
    if (duration != null && position > duration) {
      position = duration;
    }
    return position;
  }

  /// The last report, what [reports] gives next time.
  LyricsPlayerReport get report => LyricsPlayerReport(
    positionMs: positionMs,
    playing: _playing,
    rate: _rate,
  );

  void _report() {
    if (!_reports.isClosed) {
      _reports.add(report);
    }
  }

  /// Restart the position count from now.
  void _rebase() {
    _baseMs = positionMs;
    _startedAt = nowMs();
  }

  void _onTick() {
    var duration = durationMs;
    if (duration != null && positionMs >= duration) {
      _rebase();
      _playing = false;
      _timer?.cancel();
      _timer = null;
    }
    _report();
  }

  @override
  Future<void> play() async {
    if (_playing) {
      return;
    }
    _startedAt = nowMs();
    _playing = true;
    _timer = Timer.periodic(reportInterval, (_) => _onTick());
    _report();
  }

  @override
  Future<void> pause() async {
    if (!_playing) {
      return;
    }
    _rebase();
    _playing = false;
    _timer?.cancel();
    _timer = null;
    _report();
  }

  @override
  Future<void> seek(int positionMs) async {
    var duration = durationMs;
    if (positionMs < 0) {
      positionMs = 0;
    } else if (duration != null && positionMs > duration) {
      positionMs = duration;
    }
    _baseMs = positionMs;
    _startedAt = nowMs();
    _report();
  }

  @override
  Future<void> setRate(double rate) async {
    _rebase();
    _rate = rate.clamp(0.1, 4.0);
    _report();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _playing = false;
    await _reports.close();
  }

  @override
  String toString() => 'ClockLyricsPlayer($report)';
}
