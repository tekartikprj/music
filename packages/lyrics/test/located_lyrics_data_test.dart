import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';
import 'package:test/test.dart';

void main() {
  group('located', () {
    test('ref', () {
      expect(LocatedLyricsDataItemRef(1, 2).toString(), 'Ref(1, 2)');
      expect(LocatedLyricsDataItemRef(1, 2), LocatedLyricsDataItemRef(1, 2));
      expect(
        LocatedLyricsDataItemRef(1, 2),
        isNot(LocatedLyricsDataItemRef(3, 2)),
      );
      expect(
        LocatedLyricsDataItemRef(1, 2),
        isNot(LocatedLyricsDataItemRef(1, 3)),
      );
    });
    test('basic', () {
      var data = parseLyricLrc('[00:00.04]Hey');
      var locatedData = LocatedLyricsData(lyricsData: data);
      expect(locatedData.lines.length, 1);
      var line = locatedData.lines[0];
      expect(line.lineData.time, 40.ms);
      var parts = line.parts;
      expect(parts.length, 1);
      var part = parts[0];
      expect(part.start, 0);
      expect(part.end, 3);
      expect(part.time, 40.ms);
      var info = locatedData.locateItemInfo(39.ms);
      expect(info.ref.lineIndex, -1);
      expect(info.ref.partIndex, -1);
      info = locatedData.locateItemInfo(40.ms);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Hey');
    });
    test('end', () {
      var data = parseLyricLrc('[00:01]Hey<00:02>');
      var locatedData = LocatedLyricsData(lyricsData: data);
      expect(locatedData.lines, hasLength(1));
      var info = locatedData.locateItemInfo(999.ms);
      expect(info.ref.lineIndex, -1);
      expect(info.ref.partIndex, -1);
      info = locatedData.locateItemInfo(1.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Hey');
      info = locatedData.locateItemInfo(2.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 1);
      expect(info.text, '');
      info = locatedData.locateItemInfo(3.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 1);
      expect(info.text, '');
    });
    test('first part', () {
      var data = parseLyricLrc('[00:01]<00:02>Hey');
      var locatedData = LocatedLyricsData(lyricsData: data);
      expect(locatedData.lines.length, 1);
      var line = locatedData.lines[0];
      expect(line.lineData.time, 1.s);
      var parts = line.parts;
      expect(parts.length, 1);
      var part = parts[0];
      expect(part.start, 0);
      expect(part.end, 3);
      expect(part.time, 2.s);
    });
    test('3 parts', () {
      var data = parseLyricLrc('[00:01]Hey<00:02>Joe<00:03>');
      var locatedData = LocatedLyricsData(lyricsData: data);
      expect(locatedData.lines.length, 1);
      var line = locatedData.lines[0];
      expect(line.lineData.time, 1.s);
      var parts = line.parts;
      expect(parts.length, 3);
      var part = parts[0];
      expect(part.start, 0);
      expect(part.end, 3);
      expect(part.time, 1.s);
      part = parts[1];
      expect(part.start, 3);
      expect(part.end, 6);
      expect(part.time, 2.s);
      part = parts[2];
      expect(part.start, 6);
      expect(part.end, 6);
      expect(part.time, 3.s);
    });
    test('2 lines', () {
      var data = parseLyricLrc(
        '[00:01]Hey<00:03>\n'
        '[00:05]Joe',
      );
      var locatedData = LocatedLyricsData(lyricsData: data);
      //locatedData.devDump();
      expect(locatedData.lines, hasLength(2));
      var info = locatedData.locateItemInfo(999.ms);
      expect(info.ref.lineIndex, -1);
      expect(info.ref.partIndex, -1);
      info = locatedData.locateItemInfo(1.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Hey');
      info = locatedData.locateItemInfo(2.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Hey');
      info = locatedData.locateItemInfo(3.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 1);
      expect(info.text, '');
      info = locatedData.locateItemInfo(4.s);
      expect(info.ref.lineIndex, 0);
      expect(info.ref.partIndex, 1);
      expect(info.text, '');
      info = locatedData.locateItemInfo(5.s);
      expect(info.ref.lineIndex, 1);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Joe');
      info = locatedData.locateItemInfo(6.s);
      expect(info.ref.lineIndex, 1);
      expect(info.ref.partIndex, 0);
      expect(info.text, 'Joe');
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef.before()),
        LocatedLyricsDataItemRef.before(),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef.before()),
        LocatedLyricsDataItemRef.lineBefore(0),
      );
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef.lineBefore(0)),
        LocatedLyricsDataItemRef.before(),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef.lineBefore(0)),
        LocatedLyricsDataItemRef(0, 0),
      );
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef(0, 0)),
        LocatedLyricsDataItemRef.lineBefore(0),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef(0, 0)),
        LocatedLyricsDataItemRef(0, 1),
      );
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef(0, 1)),
        LocatedLyricsDataItemRef(0, 0),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef(0, 1)),
        LocatedLyricsDataItemRef.lineBefore(1),
      );
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef.lineBefore(1)),
        LocatedLyricsDataItemRef(0, 1),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef.lineBefore(1)),
        LocatedLyricsDataItemRef(1, 0),
      );
      expect(
        locatedData.getPreviousRef(LocatedLyricsDataItemRef(1, 0)),
        LocatedLyricsDataItemRef.lineBefore(1),
      );
      expect(
        locatedData.getNextRef(LocatedLyricsDataItemRef(1, 0)),
        LocatedLyricsDataItemRef(1, 0),
      );
    });
    test('2 lines 2 parts each', () {
      var data = parseLyricLrc('''
      [00:00.00]Zero<00:01.00>One
      [00:02.00]Two<00:03.00>Three  
      ''');
      var locatedData = LocatedLyricsData(lyricsData: data);
      //locatedData.devDump();
      expect(locatedData.lines, hasLength(2));
      var info = locatedData.locateItemInfo(2.s);
      expect(info.ref.lineIndex, 1);
      expect(info.ref.partIndex, 0);
      info = locatedData.locateItemInfo(2.1.s);
      expect(info.ref.lineIndex, 1);
      expect(info.ref.partIndex, 0);
      info = locatedData.locateItemInfo(3.1.s);
      expect(info.ref.lineIndex, 1);
      expect(info.ref.partIndex, 1);
    });
  });
}
