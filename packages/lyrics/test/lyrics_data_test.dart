import 'dart:convert';

import 'package:tekaly_lyrics/lyrics.dart';
import 'package:test/test.dart';

void main() {
  group('LyricsData', () {
    test('toLrcLines', () {
      void testRoundTrip(String lrc) {
        var lines = LineSplitter.split(lrc);
        var data = parseLyricLrc(lrc);
        expect(data.toLrcLines(), lines);
      }

      testRoundTrip('[00:00.04]Some body');
      testRoundTrip('[00:00.00]Zero<00:01.00>One');
      testRoundTrip('[00:00.00]<00:01.00>One<00:02.00>');
    });
  });
}
