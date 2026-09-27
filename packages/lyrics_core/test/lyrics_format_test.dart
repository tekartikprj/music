import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

/// The karakelio example: a time per syllable.
const karakelioLrc = '''
[ti:Il en faut peu pour être heureux]
[ar:Baloo]
[00:40.388]<00:40.388>Il <00:40.808>en <00:40.988>faut <00:41.508>peu <00:41.958>pour <00:42.348>ê-<00:42.508>tre <00:42.708>heu-<00:42.958>reux
[00:43.188]<00:43.188>Vrai-<00:43.458>ment <00:43.638>très <00:43.868>peu<00:44.200>
''';

List<String> partTexts(CvLyricsLine line) =>
    line.partList.map((part) => part.textOrEmpty).toList();

List<int?> partStarts(CvLyricsLine line) =>
    line.partList.map((part) => part.startMs.v).toList();

void main() {
  initTekalyLyricsBuilders();
  group('time', () {
    test('format', () {
      expect(formatLyricsTime(0), '0:00.000');
      expect(formatLyricsTime(130789), '2:10.789');
      expect(formatLyricsTime(3723004), '1:02:03.004');
      expect(formatLyricsTime(40388, digits: 2, padMinutes: true), '00:40.38');
      expect(formatLyricsTime(-5), '0:00.000');
      expect(formatLyricsTime(61000, digits: 0), '1:01');
    });
    test('parse', () {
      expect(parseLyricsTime('2:10.789'), 130789);
      expect(parseLyricsTime('00:40.38'), 40380);
      expect(parseLyricsTime('00:40.3'), 40300);
      expect(parseLyricsTime('1:02:03.004'), 3723004);
      expect(parseLyricsTime('00:01:02,345'), 62345);
      expect(parseLyricsTime('0:05'), 5000);
      expect(parseLyricsTime('12.5'), 12500);
      expect(parseLyricsTime('ti:title'), isNull);
      expect(parseLyricsTime('0:75'), isNull);
      expect(parseLyricsTime('C'), isNull);
    });
    test('round trip', () {
      for (var ms in [0, 1, 999, 59999, 60000, 130789, 3599999, 3600000]) {
        expect(parseLyricsTime(formatLyricsTime(ms)), ms);
      }
    });
  });

  group('lrc', () {
    test('enhanced', () {
      var result = parseLrcLyrics(karakelioLrc);
      expect(result.title, 'Il en faut peu pour être heureux');
      expect(result.artist, 'Baloo');
      var lines = result.lyrics.lineList;
      expect(lines, hasLength(2));
      var line = lines[0];
      expect(line.startMs.v, 40388);
      expect(partTexts(line), [
        'Il',
        'en',
        'faut',
        'peu',
        'pour',
        'ê-',
        'tre',
        'heu-',
        'reux',
      ]);
      expect(partStarts(line).first, 40388);
      expect(partStarts(line)[6], 42508);
      expect(line.partList[5].isJoined, isTrue);
      expect(line.partList[4].isJoined, isFalse);
      expect(line.text, 'Il en faut peu pour ê-tre heu-reux');
      expect(lines[1].endMs.v, 44200);
      expect(lines[1].text, 'Vrai-ment très peu');
    });
    test('line timing, repeated lines, offset, ends and pages', () {
      var result = parseLrcLyrics('''
[offset:+100]
[00:10.00]First line
[00:14.50]
[00:20.00][00:40.00]Chorus line

[00:30.00]Verse
''');
      var lyrics = result.lyrics;
      expect(lyrics.offsetMs.v, -100);
      var lines = lyrics.lineList;
      expect(lines.map((line) => line.text), [
        'First line',
        'Chorus line',
        'Verse',
        'Chorus line',
      ]);
      expect(lines.map((line) => line.startMs.v), [10000, 20000, 30000, 40000]);
      expect(lines[0].endMs.v, 14500);
      expect(lines[2].isNewPage, isTrue);
      expect(lines[1].isNewPage, isFalse);
    });
    test('round trip', () {
      var lyrics = parseLrcLyrics(karakelioLrc).lyrics;
      var text = formatLrcLyrics(lyrics);
      expect(text, contains('<00:42.508>tre'));
      expect(text, contains('[00:40.388]'));
      var again = parseLrcLyrics(text).lyrics;
      expect(again.toMap(), lyrics.toMap());
    });
    test('part end in the middle', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of(
          [
            CvLyricsPart.of('Hel', startMs: 1000, endMs: 1200, join: true),
            CvLyricsPart.of('lo', startMs: 1500),
            CvLyricsPart.of('you', startMs: 2000),
          ],
          startMs: 1000,
          endMs: 2500,
        ),
      ]);
      var text = formatLrcLyrics(lyrics);
      expect(
        text.trim(),
        '[00:01.000]<00:01.000>Hel<00:01.200><00:01.500>lo <00:02.000>you'
        '<00:02.500>',
      );
      expect(parseLrcLyrics(text).lyrics.toMap(), lyrics.toMap());
    });
    test('line timing only exports the end as an empty line', () {
      var lyrics = CvLyrics.of([
        CvLyricsLine.of(
          [CvLyricsPart.of('one'), CvLyricsPart.of('two')],
          startMs: 1000,
          endMs: 3000,
        ),
      ], offsetMs: 500);
      expect(formatLrcLyrics(lyrics, title: 'T'), '''
[ti:T]
[00:01.500]one two
[00:03.500]
''');
    });
  });

  group('text', () {
    test('syllables, chords, pages and sections', () {
      var result = parseLyricsText('''
{title: Il en faut peu}
{artist: Baloo}
[Chorus]
Il en faut peu pour [C]ê|tre heu|reux
Vrai|ment très [G7]peu

Il faut se sa|tis|fai|re
[C] [G]
''');
      expect(result.title, 'Il en faut peu');
      expect(result.artist, 'Baloo');
      var lines = result.lyrics.lineList;
      expect(lines, hasLength(4));
      expect(lines[0].section.v, 'Chorus');
      expect(lines[1].section.v, 'Chorus');
      expect(lines[2].section.v, isNull);
      expect(lines[2].isNewPage, isTrue);
      expect(lines[0].text, 'Il en faut peu pour être heureux');
      expect(lines[0].partList[5].chord.v, 'C');
      expect(lines[0].partList[5].textOrEmpty, 'ê');
      expect(lines[0].partList[5].isJoined, isTrue);
      expect(lines[1].partList[3].chord.v, 'G7');
      expect(lines[3].partList.map((part) => part.chord.v), ['C', 'G']);
      expect(lines[3].text, '');
    });
    test('chord inside a word', () {
      var parts = parseLyricsTextLine('hel[G]lo [Am]world');
      expect(parts.map((part) => part.textOrEmpty), ['hel', 'lo', 'world']);
      expect(parts.map((part) => part.chord.v), [null, 'G', 'Am']);
      expect(parts.map((part) => part.isJoined), [true, false, false]);
    });
    test('chords over lyrics', () {
      var lines = parseLyricsText('''
C       G
Hello my friend
Am
''').lyrics.lineList;
      expect(lines, hasLength(2));
      expect(lines[0].partList.map((part) => part.chord.v), ['C', null, 'G']);
      expect(lines[0].text, 'Hello my friend');
      expect(lines[1].partList.single.chord.v, 'Am');
    });
    test('chordpro sections', () {
      var lines = parseLyricsText('''
{soc}
La la
{eoc}
{c: a comment}
Verse
''').lyrics.lineList;
      expect(lines.map((line) => line.section.v), ['chorus', null]);
    });
    test('chord names', () {
      for (var chord in ['C', 'Am', 'F#m7b5', 'Cmaj7', 'Csus4', 'D/F#', 'Bb']) {
        expect(isLyricsChordName(chord), isTrue, reason: chord);
      }
      for (var text in ['Chorus', 'Verse 1', 'Hello', 'c', 'H']) {
        expect(isLyricsChordName(text), isFalse, reason: text);
      }
    });
    test('round trip', () {
      const text = '''
[Chorus]
Il en faut peu pour [C]ê|tre heu|reux
Vrai|ment très [G7]peu

Il faut se sa|tis|fai|re
''';
      var lyrics = parseLyricsText(text).lyrics;
      expect(formatLyricsText(lyrics), text);
      expect(formatLyricsText(lyrics, chords: false, syllables: false), '''
[Chorus]
Il en faut peu pour être heureux
Vraiment très peu

Il faut se satisfaire
''');
    });
  });

  group('subtitles', () {
    test('srt', () {
      var lines = parseSubtitleLyrics('''
1
00:00:01,000 --> 00:00:03,000
Hello <i>world</i>

2
00:00:04,000 --> 00:00:08,000
First
Second line
''').lyrics.lineList;
      expect(lines.map((line) => line.text), [
        'Hello world',
        'First',
        'Second line',
      ]);
      expect(lines[0].startMs.v, 1000);
      expect(lines[0].endMs.v, 3000);
      expect(lines[1].startMs.v, 4000);
      expect(lines[1].isNewPage, isTrue);
      expect(lines[2].isNewPage, isFalse);
      // 4 s split in proportion: 5 and 11 characters.
      expect(lines[1].endMs.v, 5250);
      expect(lines[2].startMs.v, 5250);
      expect(lines[2].endMs.v, 8000);
    });
    test('vtt karaoke timestamps', () {
      var lines = parseSubtitleLyrics('''
WEBVTT

00:01.000 --> 00:03.000 align:start
<00:01.000>Ka<00:01.500>ra<00:02.000>o<00:02.500>ke
''').lyrics.lineList;
      expect(lines.single.partList.map((part) => part.startMs.v), [
        1000,
        1500,
        2000,
        2500,
      ]);
      expect(lines.single.text, 'Karaoke');
    });
  });

  test('detect and import', () {
    expect(detectLyricsFormat(karakelioLrc), LyricsFormat.lrc);
    expect(detectLyricsFormat('a\nb'), LyricsFormat.text);
    expect(detectLyricsFormat('[C]a'), LyricsFormat.text);
    expect(detectLyricsFormat('WEBVTT\n'), LyricsFormat.subtitles);
    expect(
      detectLyricsFormat('1\n00:00:01,000 --> 00:00:02,000\na'),
      LyricsFormat.subtitles,
    );
    expect(detectLyricsFormat('x', fileName: 'song.LRC'), LyricsFormat.lrc);
    expect(detectLyricsFormat('x', fileName: 'song.cho'), LyricsFormat.text);
    expect(importLyrics(karakelioLrc).lyrics.lineList, hasLength(2));
  });

  group('merge', () {
    test('keeps unchanged and changed lines timing', () {
      var previous = CvLyrics.of([
        CvLyricsLine.of([
          CvLyricsPart.of('one', startMs: 1000),
          CvLyricsPart.of('two', startMs: 1500),
        ], endMs: 2000),
        CvLyricsLine.of([CvLyricsPart.of('three', startMs: 3000)]),
        CvLyricsLine.of([CvLyricsPart.of('four', startMs: 4000)]),
        CvLyricsLine.of([CvLyricsPart.of('five', startMs: 5000)]),
      ], offsetMs: 10);
      var edited = parseLyricsText('''
one two
THREE
inserted line
four
five
''').lyrics;
      var merged = mergeLyricsTiming(previous, edited);
      var lines = merged.lineList;
      expect(merged.offsetMs.v, 10);
      expect(partStarts(lines[0]), [1000, 1500]);
      expect(lines[0].endMs.v, 2000);
      // THREE + inserted line replace three: 2 lines for 1, not paired.
      expect(lines[1].isTimed, isFalse);
      expect(lines[2].isTimed, isFalse);
      expect(partStarts(lines[3]), [4000]);
      expect(partStarts(lines[4]), [5000]);
    });
    test('pairs a changed line in place', () {
      var previous = CvLyrics.of([
        CvLyricsLine.of([CvLyricsPart.of('a', startMs: 1000)]),
        CvLyricsLine.of([
          CvLyricsPart.of('b', startMs: 2000),
          CvLyricsPart.of('c', startMs: 2500),
        ], startMs: 2000),
        CvLyricsLine.of([CvLyricsPart.of('d', startMs: 3000)]),
      ]);
      var merged = mergeLyricsTiming(
        previous,
        parseLyricsText('a\nB C\nd').lyrics,
      );
      expect(partStarts(merged.lineList[1]), [2000, 2500]);
      merged = mergeLyricsTiming(
        previous,
        parseLyricsText('a\nb c extra\nd').lyrics,
      );
      expect(merged.lineList[1].startMs.v, 2000);
      expect(partStarts(merged.lineList[1]), [null, null, null]);
    });
  });
}
