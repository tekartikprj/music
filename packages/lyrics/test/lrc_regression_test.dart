import 'package:tekaly_lyrics/src/lrc_parser.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';
import 'package:test/test.dart';

void main() {
  group('lrc regression', () {
    test('malformed tags do not throw', () {
      var data = parseLyricLrc('''
[ar: Foo
[
[ar]
[ti]
[00:01.00]I <3 you
[00:02.00]Next
''');
      expect(data.artist, isNull);
      expect(data.title, isNull);
      expect(data.lines.map((line) => line.text), ['I <3 you', 'Next']);
      expect(data.lines.map((line) => line.time), [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });
    test('findTime without closing >', () {
      expect(findTime('I <3 you'), FindTimeResult());
    });
    test('a line with several time tags', () {
      var data = parseLyricLrc('''
[00:12.00][00:45.00]Chorus
[00:20.00]Verse
''');
      expect(data.lines.map((line) => line.text), [
        'Chorus',
        'Verse',
        'Chorus',
      ]);
      expect(data.lines.map((line) => line.time), [
        const Duration(seconds: 12),
        const Duration(seconds: 20),
        const Duration(seconds: 45),
      ]);
    });
    test('lines sorted by time', () {
      var data = parseLyricLrc('''
[00:20.00]B
[00:10.00]A
[00:20.00]C
''');
      // The same time kept in the file order.
      expect(data.lines.map((line) => line.text), ['A', 'B', 'C']);
      var located = LocatedLyricsData(lyricsData: data);
      expect(located.locateItemInfo(const Duration(seconds: 15)).text, 'A');
    });
    test('a < before a word time tag', () {
      var data = parseLyricLrc('[00:01.00]Love <3 <00:02.00>you');
      var line = data.lines.single;
      expect(line.text, 'Love <3 you');
      expect(line.parts, [
        LyricsPartData(time: const Duration(seconds: 1), text: 'Love <3 '),
        LyricsPartData(time: const Duration(seconds: 2), text: 'you'),
      ]);
      expect(parseLyricDurationLrc('3 <00:02.00'), Duration.zero);
    });
    test('no timed line', () {
      for (var lrc in ['', '[ti:Title]', 'Plain lyrics']) {
        var located = LocatedLyricsData(lyricsData: parseLyricLrc(lrc));
        var before = LocatedLyricsDataItemRef.before();
        // The end: what a player walking the refs stops on.
        expect(located.getNextRef(before), before);
        expect(located.locateItemInfo(Duration.zero).ref, before);
      }
    });
    test('lrcFormatDuration past one hour', () {
      var duration = const Duration(minutes: 65, seconds: 3);
      expect(lrcFormatDuration(duration), '65:03.00');
      expect(parseLyricDurationLrc(lrcFormatDuration(duration)), duration);
    });
  });
}
