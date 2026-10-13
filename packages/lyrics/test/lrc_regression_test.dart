import 'package:tekaly_lyrics/src/lrc_parser.dart';
import 'package:tekaly_lyrics/utils/duration_helper.dart';
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
    test('lrcFormatDuration past one hour', () {
      var duration = const Duration(minutes: 65, seconds: 3);
      expect(lrcFormatDuration(duration), '65:03.00');
      expect(parseLyricDurationLrc(lrcFormatDuration(duration)), duration);
    });
  });
}
