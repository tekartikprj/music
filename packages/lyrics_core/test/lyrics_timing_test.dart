import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

CvLyricsLine line(List<String> words, {int? startMs, int? endMs}) =>
    CvLyricsLine.of(
      words.map((word) => CvLyricsPart.of(word)).toList(),
      startMs: startMs,
      endMs: endMs,
    );

void main() {
  initTekalyLyricsBuilders();

  group('timeline', () {
    test('derived and estimated times', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('aa', startMs: 1000),
          CvLyricsPart.of('bb'),
          CvLyricsPart.of('cccc'),
          CvLyricsPart.of('d', startMs: 2600),
        ]),
        line(['next'], startMs: 3000),
      ]);
      var timeline = LyricsTimeline(lyrics);
      var first = timeline.lines[0];
      expect(first.startMs, 1000);
      expect(first.endMs, 3000);
      // 1600 ms over 2+2+4 characters.
      expect(first.parts.map((part) => part.startMs), [1000, 1400, 1800, 2600]);
      expect(first.parts.map((part) => part.estimated), [
        false,
        true,
        true,
        false,
      ]);
      expect(first.parts.map((part) => part.endMs), [1400, 1800, 2600, 3000]);
      expect(timeline.lines[1].endMs, isNull);
    });
    test('offset', () {
      var lyrics = CvLyrics.of([
        line(['a'], startMs: 1000),
      ], offsetMs: 500);
      expect(LyricsTimeline(lyrics).lines.single.startMs, 1500);
      lyrics.offsetMs.v = -2000;
      expect(LyricsTimeline(lyrics).lines.single.startMs, 0);
    });
    test('automatic pages', () {
      var lyrics = CvLyrics.of([
        line(['one'], startMs: 10000, endMs: 11000),
        line(['two'], startMs: 12000, endMs: 13000),
        line(['three'], startMs: 20000),
        line(['four'], startMs: 22000),
        line(['five'], startMs: 30000),
      ]);
      var timeline = LyricsTimeline(lyrics);
      expect(timeline.pages.map((page) => page.firstLine), [0, 2, 4]);
      expect(timeline.lines.map((line) => line.pageIndex), [0, 0, 1, 1, 2]);
      // Shown 2 s before the first line, the previous page being sung.
      expect(timeline.pages.map((page) => page.showMs), [0, 18000, 28000]);
      expect(timeline.pageAt(17999), 0);
      expect(timeline.pageAt(18000), 1);
    });
    test('explicit pages and page times', () {
      var lyrics = CvLyrics.of([
        line(['one'], startMs: 10000),
        line(['two'], startMs: 12000),
        CvLyricsLine.of(
          [CvLyricsPart.of('three')],
          startMs: 14000,
          newPage: true,
          pageMs: 13500,
        ),
      ]);
      var timeline = LyricsTimeline(lyrics);
      expect(timeline.pages.map((page) => page.lineCount), [2, 1]);
      expect(timeline.pages[1].showMs, 13500);
    });
    test('a page is not shown before the previous one is sung', () {
      var lyrics = CvLyrics.of([
        line(['one'], startMs: 10000, endMs: 13500),
        CvLyricsLine.of(
          [CvLyricsPart.of('two')],
          startMs: 14000,
          newPage: true,
        ),
      ]);
      expect(LyricsTimeline(lyrics).pages[1].showMs, 13500);
    });
    test('locate', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('a', startMs: 1000),
          CvLyricsPart.of('b', startMs: 2000),
        ], endMs: 3000),
        line(['c'], startMs: 5000),
      ]);
      var timeline = LyricsTimeline(lyrics);
      expect(timeline.locate(500).lineIndex, -1);
      var location = timeline.locate(1500);
      expect(location.lineIndex, 0);
      expect(location.partIndex, 0);
      expect(location.partProgress, 0.5);
      expect(location.lineProgress, 0.25);
      expect(location.singing, isTrue);
      location = timeline.locate(4000);
      expect(location.lineIndex, 0);
      expect(location.singing, isFalse);
      expect(location.partProgress, 1);
      expect(timeline.locate(6000).lineIndex, 1);
    });
    test('untimed', () {
      var timeline = LyricsTimeline(
        CvLyrics.of([
          line(['a']),
        ]),
      );
      expect(timeline.isTimed, isFalse);
      expect(timeline.locate(1000), LyricsLocation.start);
      expect(timeline.sungRanges(), isEmpty);
    });
    test('sung ranges', () {
      var lyrics = CvLyrics.of([
        line(['intro'], startMs: 20000, endMs: 24000),
        line(['close'], startMs: 26000, endMs: 30000),
        line(['after', 'break'], startMs: 60000),
      ]);
      var ranges = LyricsTimeline(
        lyrics,
      ).sungRanges(leadInMs: 3000, tailMs: 1000, gapMinMs: 8000);
      // The last line has no end: 12 characters at 120 ms.
      expect(ranges, [
        const MediaRange(17000, 31000),
        const MediaRange(57000, 62440),
      ]);
      // A short intro is kept.
      lyrics.lineList.first.startMs.v = 5000;
      ranges = LyricsTimeline(lyrics).sungRanges(leadInMs: 3000);
      expect(ranges.first.fromMs, 0);
    });
    test('sung range of a line without end stops at the next line', () {
      var lyrics = CvLyrics.of([
        line(['a', 'long', 'line', 'of', 'words'], startMs: 1000),
        line(['b'], startMs: 2000),
      ]);
      var timeline = LyricsTimeline(lyrics);
      expect(timeline.lines[0].sungEndMs, 2000);
    });
  });

  group('play ranges', () {
    test('clips only', () {
      expect(computePlayRanges(), [MediaRange.whole]);
      var clips = [const MediaRange(1000, 2000), const MediaRange(500, 800)];
      expect(computePlayRanges(clips: clips), clips);
      expect(computePlayRanges(clips: clips, sung: []), clips);
    });
    test('skip gaps', () {
      var sung = [const MediaRange(0, 10000), const MediaRange(30000, 40000)];
      expect(computePlayRanges(sung: sung), sung);
      expect(
        computePlayRanges(
          clips: [const MediaRange(5000, 35000), const MediaRange(38000)],
          sung: sung,
        ),
        [
          const MediaRange(5000, 10000),
          const MediaRange(30000, 35000),
          const MediaRange(38000, 40000),
        ],
      );
    });
    test('next range', () {
      var ranges = [const MediaRange(1000, 2000), const MediaRange(5000)];
      expect(nextPlayRangeIndex(ranges, 0, 1500), isNull);
      expect(nextPlayRangeIndex(ranges, 0, 2000), 1);
      expect(nextPlayRangeIndex(ranges, 1, 9000), isNull);
      expect(nextPlayRangeIndex(ranges, 1, 9000, durationMs: 9000), 2);
    });
    test('intersect', () {
      expect(
        const MediaRange(0, 10).intersect(const MediaRange(5)),
        const MediaRange(5, 10),
      );
      expect(
        const MediaRange(0, 10).intersect(const MediaRange(10, 20)),
        isNull,
      );
      expect(
        const MediaRange(3).intersect(const MediaRange(1)),
        const MediaRange(3),
      );
    });
  });

  group('clock', () {
    test('interpolates and follows the rate', () {
      var now = 0;
      var clock = LyricsClock(nowMs: () => now);
      clock.report(1000, playing: true, rate: 1);
      now = 100;
      expect(clock.positionMs, 1100);
      clock.setRate(2);
      now = 200;
      expect(clock.positionMs, 1300);
      clock.report(1250, playing: true);
      // Jitter: not backwards.
      expect(clock.positionMs, 1300);
      now = 300;
      expect(clock.positionMs, 1500);
    });
    test('pause, seek, stall', () {
      var now = 0;
      var clock = LyricsClock(nowMs: () => now, maxExtrapolationMs: 500);
      clock.report(1000, playing: false);
      now = 1000;
      expect(clock.positionMs, 1000);
      clock.seek(200);
      expect(clock.positionMs, 200);
      clock.report(200, playing: true);
      now = 5000;
      expect(clock.positionMs, 700);
    });
  });

  group('tap editor', () {
    CvLyrics sample() => parseLyricsText('''
Il en faut peu pour ê|tre heu|reux
Vrai|ment très peu
Il faut se sa|tis|fai|re
''').lyrics;

    test('syllables', () {
      var editor = LyricsTapEditor(sample(), tapLatencyMs: 100)
        ..lyrics.offsetMs.v = 1000;
      expect(editor.cursorUnit, const LyricsUnitRef(0, 0));
      editor.tap(5100);
      editor.tap(5600);
      var line = editor.lyrics.lineList[0];
      expect(line.startMs.v, 4000);
      expect(line.partList[0].startMs.v, 4000);
      expect(line.partList[1].startMs.v, 4500);
      expect(editor.cursorUnit, const LyricsUnitRef(0, 2));
      expect(editor.undo(), isTrue);
      expect(line.partList[1].startMs.v, 4500);
      expect(editor.lyrics.lineList[0].partList[1].startMs.v, isNull);
      expect(editor.cursorUnit, const LyricsUnitRef(0, 1));
    });
    test('hold mode, end of line, page here', () {
      var editor = LyricsTapEditor(sample());
      editor.tap(1000);
      editor.release(1400);
      expect(editor.lyrics.lineList[0].partList[0].endMs.v, 1400);
      editor.tap(1500);
      editor.endLine(2000);
      expect(editor.lyrics.lineList[0].endMs.v, 2000);
      expect(editor.cursorUnit, const LyricsUnitRef(1, 0));
      editor.pageHere(2500);
      var lines = editor.lyrics.lineList;
      expect(lines[1].isNewPage, isTrue);
      expect(lines[1].pageMs.v, 2500);
    });
    test('words', () {
      var editor = LyricsTapEditor(
        sample(),
        granularity: LyricsTimingGranularity.word,
      );
      // Il en faut peu pour être heureux: 7 words.
      expect(editor.units.where((unit) => unit.line == 0), hasLength(7));
      for (var i = 0; i < 6; i++) {
        editor.tap(1000 + i * 100);
      }
      var parts = editor.lyrics.lineList[0].partList;
      expect(parts[5].startMs.v, 1500);
      expect(parts[6].startMs.v, isNull);
      expect(editor.cursorUnit, const LyricsUnitRef(0, 7));
    });
    test('lines move their syllables along', () {
      var editor = LyricsTapEditor(sample());
      editor.tap(1000);
      editor.tap(1200);
      editor.setGranularity(LyricsTimingGranularity.line);
      editor.moveCursorToLine(0);
      editor.tap(3000);
      var line = editor.lyrics.lineList[0];
      expect(line.startMs.v, 3000);
      expect(line.partList[1].startMs.v, 3200);
      expect(editor.cursorUnit, const LyricsUnitRef(1));
    });
    test('pages', () {
      var editor = LyricsTapEditor(
        sample(),
        granularity: LyricsTimingGranularity.page,
      );
      // 3 lines, 2 per page: one page change to time.
      expect(editor.units, [const LyricsUnitRef(2)]);
      editor.tap(9000);
      var lines = editor.lyrics.lineList;
      expect(lines[2].isNewPage, isTrue);
      expect(lines[2].pageMs.v, 9000);
    });
    test('nudge, set, shift, clear, estimate, validate', () {
      var editor = LyricsTapEditor(sample());
      editor.tap(1000);
      editor.tap(2000);
      editor.nudge(const LyricsUnitRef(0, 1), -50);
      expect(editor.timeOf(const LyricsUnitRef(0, 1)), 1950);
      editor.setTime(const LyricsUnitRef(0, 1), 500);
      expect(editor.validate(), [
        isA<LyricsTimingIssue>().having(
          (issue) => issue.ref,
          'ref',
          const LyricsUnitRef(0, 1),
        ),
      ]);
      editor.setTime(const LyricsUnitRef(0, 1), 1500);
      expect(editor.validate(), isEmpty);
      editor.shiftFrom(0, 100);
      expect(editor.timeOf(const LyricsUnitRef(0, 0)), 1100);
      editor.endLine(4000);
      editor.estimateParts(0);
      var parts = editor.lyrics.lineList[0].partList;
      expect(parts.every((part) => part.startMs.v != null), isTrue);
      editor.clearFrom(0);
      expect(editor.lyrics.isTimed, isFalse);
      expect(editor.cursorUnit, const LyricsUnitRef(0, 0));
    });
  });
}
