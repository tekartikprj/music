import 'package:tekartik_lyrics/example/une_souris_verte_lrc.dart';
import 'package:tekartik_lyrics/lyrics.dart';
import 'package:tekartik_lyrics/src/lrc_parser.dart';
import 'package:test/test.dart';

var lrcBasic1 = '''
[ti: Somebody]
[00:00.04]Some body
''';
var lrcWord1 = '''
[ti: Somebody]
[00:00.02] <00:00.04>So<00:00.16>me <00:00.82>body<00:01.29>
''';
void main() {
  group('Lyrics', () {
    test('Parser', () {
      var data = parseLyric(lrcUneSourisVerte);
      expect(data.artist, 'Chanson enfantine traditionnelle');
      expect(data.title, 'Une souris verte (Word Timed)');
      expect(data.lines.length, 9);
    });
    test('lyric basic line', () {
      var data = parseLyric(lrcBasic1);
      expect(data.artist, null);
      expect(data.title, 'Somebody');
      var line = data.lines[0];
      expect(line.time, const Duration(milliseconds: 40));
      var singleContent = line.content as LyricLineSingleContent;
      expect(singleContent.part.content, 'Some body');
    });
    test('lyric word line', () {
      var data = parseLyric(lrcWord1);
      expect(data.artist, null);
      expect(data.title, 'Somebody');
      var line = data.lines[0];
      expect(line.time, const Duration(milliseconds: 20));
      var multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, hasLength(5));
    });
    test('parseMultiSinglePart', () {
      var line = parseLyricLine('00:00.01', '<00:00.02>text');
      expect(line.time, const Duration(milliseconds: 10));
      var multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, [
        LyricPartData(time: const Duration(milliseconds: 10), content: ''),
        LyricPartData(time: const Duration(milliseconds: 20), content: 'text'),
      ]);
      line = parseLyricLine('00:00.01', ' <00:00.01>text');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, [
        LyricPartData(time: const Duration(milliseconds: 10), content: ' '),
        LyricPartData(time: const Duration(milliseconds: 10), content: 'text'),
      ]);
      line = parseLyricLine('00:00.01', '<00:00.01>text');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, [
        LyricPartData(time: const Duration(milliseconds: 10), content: 'text'),
      ]);
      line = parseLyricLine('00:00.01', '<00:00.01>text<00:00.02>');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, [
        LyricPartData(time: const Duration(milliseconds: 10), content: 'text'),
        LyricPartData(time: const Duration(milliseconds: 20), content: ''),
      ]);
      line = parseLyricLine('00:00.01', 'text<00:00.02>');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricLineMultiContent;
      expect(multiContent.parts, [
        LyricPartData(time: const Duration(milliseconds: 10), content: 'text'),
        LyricPartData(time: const Duration(milliseconds: 20), content: ''),
      ]);
    });
    test('findTime', () {
      expect(
        findTime('<01:02.20> nxt'),
        FindTimeResult(
          index: 0,
          time: const Duration(seconds: 2, minutes: 1, milliseconds: 200),
          next: ' nxt',
        ),
      );
    });
  });
}
