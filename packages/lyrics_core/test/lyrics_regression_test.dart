import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

void main() {
  group('lyrics regression', () {
    test('hold mode: a press after the last unit changes nothing', () {
      var editor = LyricsTapEditor(parseLyricsText('Hel|lo you').lyrics);
      for (var ms in [1000, 1500, 2000]) {
        expect(editor.tap(ms), isTrue);
        editor.release(ms + 200);
      }
      var parts = editor.lyrics.lineList.first.partList;
      expect(parts.last.startMs.v, 2000);
      expect(parts.last.endMs.v, 2200);
      expect(editor.tap(9000), isFalse);
      editor.release(9500);
      expect(parts.last.endMs.v, 2200);
      // A second release of the same press does nothing either.
      editor.release(9600);
      expect(parts.last.endMs.v, 2200);
    });
    test('merge keeps a line start from its first timed part', () {
      var previous = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('so'),
          CvLyricsPart.of('long', startMs: 2000),
        ]),
      ]);
      var edited = parseLyricsText('so long now').lyrics;
      var merged = mergeLyricsTiming(previous, edited);
      expect(merged.lineList.first.startMs.v, 2000);
    });
    test('line start from the first timed part (lrc, timeline)', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('so'),
          CvLyricsPart.of('long', startMs: 2000),
        ]),
      ]);
      expect(LyricsTimeline(lyrics).lines.first.startMs, 2000);
      expect(formatLrcLyrics(lyrics), '[00:02.000]so <00:02.000>long\n');
    });
    test('lrc: a part end before an untimed part does not time it', () {
      // Hold mode: "Hello" pressed and released, "world" not timed yet.
      var lyrics = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('Hello', startMs: 1000, endMs: 1400),
          CvLyricsPart.of('world'),
        ], startMs: 1000),
      ]);
      var lrc = formatLrcLyrics(lyrics, syllables: true);
      expect(lrc, '[00:01.000]<00:01.000>Hello world\n');
      var parts = parseLrcLyrics(lrc).lyrics.lineList.single.partList;
      expect(parts.map((part) => part.startMs.v), [1000, null]);
      // Before a timed part, the end is still written.
      lyrics.lineList.single.partList[1].startMs.v = 1600;
      lrc = formatLrcLyrics(lyrics);
      expect(lrc, '[00:01.000]<00:01.000>Hello <00:01.400><00:01.600>world\n');
      parts = parseLrcLyrics(lrc).lyrics.lineList.single.partList;
      expect(parts.map((part) => part.endMs.v), [1400, null]);
    });
    test('lrc edit: the page times follow the offset written in', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of([CvLyricsPart.of('one')], startMs: 1000, endMs: 2000),
        CvLyricsLine.of(
          [CvLyricsPart.of('two')],
          startMs: 5000,
          endMs: 6000,
          newPage: true,
          pageMs: 4500,
        ),
      ], offsetMs: 1000);
      expect(LyricsTimeline(lyrics).pages[1].showMs, 5500);
      // The LRC has the offset applied, no offset tag.
      var edited = parseLrcLyrics(formatLrcLyrics(lyrics)).lyrics;
      expect(edited.offsetMs.v, isNull);
      var merged = mergeLyricsExtras(lyrics, edited);
      expect(merged.lineList[1].startMs.v, 6000);
      expect(merged.lineList[1].pageMs.v, 5500);
      expect(LyricsTimeline(merged).pages[1].showMs, 5500);
    });
  });
}
