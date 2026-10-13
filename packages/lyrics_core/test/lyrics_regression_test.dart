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
  });
}
