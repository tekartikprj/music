import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

void main() {
  group('ClockLyricsPlayer', () {
    late int now;
    late ClockLyricsPlayer player;
    late List<LyricsPlayerReport> reports;

    setUp(() {
      now = 1000;
      player = ClockLyricsPlayer(nowMs: () => now);
      reports = [];
      player.reports.listen(reports.add);
    });

    tearDown(() => player.dispose());

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    test('play, pause, seek', () async {
      expect(player.positionMs, 0);
      await player.play();
      now += 1500;
      expect(player.positionMs, 1500);
      await player.pause();
      now += 1000;
      expect(player.positionMs, 1500);
      await player.seek(4000);
      expect(player.positionMs, 4000);
      await player.seek(-10);
      expect(player.positionMs, 0);
      await flush();
      expect(reports, const [
        LyricsPlayerReport(positionMs: 0, playing: true),
        LyricsPlayerReport(positionMs: 1500, playing: false),
        LyricsPlayerReport(positionMs: 4000, playing: false),
        LyricsPlayerReport(positionMs: 0, playing: false),
      ]);
    });

    test('rate', () async {
      await player.play();
      now += 1000;
      await player.setRate(0.5);
      now += 1000;
      expect(player.positionMs, 1500);
      await player.setRate(10);
      expect(player.rate, 4);
      await flush();
      expect(reports.last.rate, 4);
    });

    test('duration', () async {
      player.durationMs = 2000;
      await player.play();
      now += 5000;
      expect(player.positionMs, 2000);
      await player.seek(3000);
      expect(player.positionMs, 2000);
    });

    test('reports while playing, pauses at the end', () async {
      var clock = 0;
      var ticking = ClockLyricsPlayer(
        nowMs: () => clock,
        durationMs: 300,
        reportInterval: const Duration(milliseconds: 5),
      );
      var ticks = <LyricsPlayerReport>[];
      ticking.reports.listen(ticks.add);
      await ticking.play();
      clock = 100;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        ticks.last,
        const LyricsPlayerReport(positionMs: 100, playing: true),
      );
      clock = 400;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        ticks.last,
        const LyricsPlayerReport(positionMs: 300, playing: false),
      );
      expect(ticking.playing, isFalse);
      await ticking.dispose();
    });
  });

  test('LyricsClock follows the clock player', () async {
    var now = 0;
    var player = ClockLyricsPlayer(nowMs: () => now);
    var clock = LyricsClock(nowMs: () => now);
    player.reports.listen(
      (report) => clock.report(
        report.positionMs,
        playing: report.playing,
        rate: report.rate,
      ),
    );
    await player.play();
    await Future<void>.delayed(Duration.zero);
    now = 750;
    expect(clock.positionMs, 750);
    await player.dispose();
  });
}
