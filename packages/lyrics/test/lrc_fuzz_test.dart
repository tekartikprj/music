import 'dart:math';

import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';
import 'package:test/test.dart';

/// Random LRC text: parsed, written back and located without an error, the
/// refs walked to their end.
void main() {
  test('random lrc', () {
    var random = Random(1);
    const alphabet = '[]<>:.0123456789 ab\n\r-';
    for (var n = 0; n < 5000; n++) {
      var lrc = String.fromCharCodes([
        for (var i = 0; i < random.nextInt(60); i++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      var reason = 'lrc ${lrc.replaceAll('\n', r'\n')}';
      var data = parseLyricLrc(lrc);
      data.toLrcLines();
      var times = data.lines.map((line) => line.time).toList();
      expect(times, [...times]..sort(), reason: reason);
      var located = LocatedLyricsData(lyricsData: data);
      for (var ms in [0, 500, 5000, 100000]) {
        located.locateItemInfo(Duration(milliseconds: ms));
      }
      // As a karaoke player lists its items.
      var ref = LocatedLyricsDataItemRef.before();
      var count = 0;
      while (true) {
        located.getItemInfo(ref);
        var next = located.getNextRef(ref);
        if (next == ref) {
          break;
        }
        ref = next;
        expect(++count, lessThan(1000), reason: reason);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
