import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/src/lrc_parser.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:test/test.dart';

var lrcBasic1 = '''
[ti: Somebody]
[00:00.04]Some body
''';
var lrcWord1 = '''
[ti: Somebody]
[00:00.02] <00:00.04>So<00:00.16>me <00:00.82> body<00:01.29>
''';

void main() {
  group('Lyrics', () {
    test('time parser', () {
      expect(parseLyricDurationLrc('00.10'), 100.ms);
      expect(parseLyricDurationLrc('00:41.50'), 41500.ms);
      expect(parseLyricDurationLrc('00:41'), 41.s);
      expect(parseLyricDurationLrc('00:41.508'), 41508.ms);
    });
    test('Parser', () {
      var data = parseLyricLrc(lrcUneSourisVerte);
      expect(data.artist, 'Chanson enfantine traditionnelle');
      expect(data.title, 'Une souris verte (Word Timed)');
      expect(data.lines.length, 9);
    });

    test('lyric basic line', () {
      var data = parseLyricLrc(lrcBasic1);
      expect(data.artist, null);
      expect(data.title, 'Somebody');
      var line = data.lines[0];
      expect(line.time, const Duration(milliseconds: 40));
      var singleContent = line.content as LyricsLineSingleContent;
      expect(singleContent.part.text, 'Some body');
    });
    test('lyric word line', () {
      var data = parseLyricLrc(lrcWord1);
      expect(data.artist, null);
      expect(data.title, 'Somebody');
      var line = data.lines[0];
      expect(line.time, 20.ms);
      var multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.text, 'Some body');
      var parts = multiContent.parts;
      expect(parts, hasLength(4));
      expect(parts[1].text, 'me');
      expect(parts[2].text, ' body');
    });
    test('Parse line basic', () {
      var content = parseLyricLineContent(1.s, 'Hey');
      expect(content.time, 1.s);
      expect(content.text, 'Hey');
      var parts = content.parts;
      expect(parts, isEmpty);
    });
    test('Parse line timing', () {
      var content = parseLyricLineContent(1.s, '<00:02>Hey');
      expect(content.time, 1.s);
      expect(content.text, 'Hey');
      var parts = content.parts;
      expect(parts, hasLength(1));
      var part = parts.first;
      expect(part.time, 2.s);
      expect(part.text, 'Hey');
    });
    test('Parse end timing', () {
      var content = parseLyricLineContent(1.s, 'Hey<00:02>');
      expect(content.time, 1.s);
      expect(content.text, 'Hey');
      var parts = content.parts;
      expect(parts, hasLength(2));
      var part = parts.first;
      expect(part.time, 1.s);
      expect(part.text, 'Hey');
      part = parts.last;
      expect(part.time, 2.s);
      expect(part.text, '');
    });
    test('parseSinglePart1', () {
      var line = parseLyricLine('00:00.01', 'text');
      expect(line.time, 10.ms);

      var singleContent = line.content as LyricsLineSingleContent;
      expect(singleContent.time, 10.ms);
      expect(singleContent.text, 'text');
    });
    test('parseSinglePart2', () {
      var result = parseLyricLineContent(20.ms, 'text');
      expect(result.time, 20.ms);
      expect(result.text, 'text');

      var parts = result.parts;
      expect(parts, isEmpty);
    });
    test('parseMultiPart1', () {
      var line = parseLyricLine('00:00.01', '<00:00.02>text');
      expect(line.time, const Duration(milliseconds: 10));
      var multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.text, 'text');
      expect(multiContent.parts, [LyricsPartData(time: 20.ms, text: 'text')]);
      line = parseLyricLine('00:00.01', ' <00:00.01>text');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.parts, [
        LyricsPartData(time: const Duration(milliseconds: 10), text: 'text'),
      ]);
      line = parseLyricLine('00:00.01', '<00:00.01>text');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.parts, [
        LyricsPartData(time: const Duration(milliseconds: 10), text: 'text'),
      ]);
      line = parseLyricLine('00:00.01', '<00:00.01>text<00:00.02>');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.parts, [
        LyricsPartData(time: const Duration(milliseconds: 10), text: 'text'),
        LyricsPartData(time: const Duration(milliseconds: 20), text: ''),
      ]);
      line = parseLyricLine('00:00.01', 'text<00:00.02>');
      expect(line.time, const Duration(milliseconds: 10));
      multiContent = line.content as LyricsLineMultiContent;
      expect(multiContent.parts, [
        LyricsPartData(time: const Duration(milliseconds: 10), text: 'text'),
        LyricsPartData(time: const Duration(milliseconds: 20), text: ''),
      ]);
    });
    test('parseMultiPart2', () {
      var result = parseLyricLineContent(10.ms, '<00:00.02>text');

      expect(result.time, 10.ms);
      expect(result.text, 'text');
      expect(result.parts, [
        //LyricsPartData(time: 10.ms, text: ''),
        LyricsPartData(time: 20.ms, text: 'text'),
      ]);
      result = parseLyricLineContent(10.ms, '<00:00.01>text');
      expect(result.time, 10.ms);
      expect(result.text, 'text');
      expect(result.parts, [LyricsPartData(time: 10.ms, text: 'text')]);
      result = parseLyricLineContent(10.ms, ' <00:00.01>text');
      expect(result.time, 10.ms);
      expect(result.text, 'text');
      expect(result.parts, [LyricsPartData(time: 10.ms, text: 'text')]);

      result = parseLyricLineContent(10.ms, '<00:00.01>text<00:00.02>');
      expect(result.time, 10.ms);
      expect(result.text, 'text');
      expect(result.parts, [
        LyricsPartData(time: 10.ms, text: 'text'),
        LyricsPartData(time: 20.ms, text: ''),
      ]);
      result = parseLyricLineContent(10.ms, 'text<00:00.02>');
      expect(result.time, 10.ms);
      expect(result.text, 'text');
      expect(result.parts, [
        LyricsPartData(time: 10.ms, text: 'text'),
        LyricsPartData(time: 20.ms, text: ''),
      ]);
    });
    test('parse spaces', () {
      var result = parseLyricLineContent(
        10.ms,
        ' <00:00.04> When  <00:00.16>   the  ',
      );
      expect(result.time, 10.ms);
      expect(result.text, 'When the');
      expect(result.parts, [
        LyricsPartData(time: 40.ms, text: 'When'),
        LyricsPartData(time: 160.ms, text: ' the'),
      ]);
    });
    test('parse endings', () {
      var result = parseLyricLineContent(10.ms, 'the<00:00.04> <00:00.05>');
      expect(result.time, 10.ms);
      expect(result.text, 'the');
      expect(result.parts, [
        LyricsPartData(time: 10.ms, text: 'the'),
        LyricsPartData(time: 40.ms, text: ''),
        LyricsPartData(time: 50.ms, text: ''),
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
