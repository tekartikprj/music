import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

void main() {
  initTekalyLyricsBuilders();
  var lyrics = parseLrcLyrics('''
[00:01.000]<00:01.000>Ka<00:01.500>ra<00:02.000>o<00:02.500>ke<00:03.000>
[00:04.000]Second line
[00:20.000]After a long break
''').lyrics;

  Future<void> pump(
    WidgetTester tester,
    int Function() position, {
    KaraokeLyricsLayout layout = KaraokeLyricsLayout.page,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: KaraokeLyricsView(
              lyrics: lyrics,
              positionMs: position,
              layout: layout,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('pages follow the position', (tester) async {
    var ms = 0;
    await pump(tester, () => ms);
    expect(find.bySemanticsLabel('Karaoke'), findsOneWidget);
    expect(find.bySemanticsLabel('Second line'), findsOneWidget);
    expect(find.bySemanticsLabel('After a long break'), findsNothing);
    ms = 1700;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('Karaoke'), findsOneWidget);
    // The last page shows 2 s before its line.
    ms = 18500;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('Karaoke'), findsNothing);
    expect(find.bySemanticsLabel('After a long break'), findsOneWidget);
  });

  testWidgets('scroll shows every line', (tester) async {
    var ms = 0;
    await pump(tester, () => ms, layout: KaraokeLyricsLayout.scroll);
    expect(find.bySemanticsLabel('Karaoke'), findsOneWidget);
    expect(find.bySemanticsLabel('After a long break'), findsOneWidget);
    ms = 20500;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('After a long break'), findsOneWidget);
  });

  testWidgets('new lyrics while paused show the page of the position', (
    tester,
  ) async {
    Widget view(CvLyrics lyrics) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: KaraokeLyricsView(lyrics: lyrics, positionMs: () => 19000),
        ),
      ),
    );
    await tester.pumpWidget(view(lyrics));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('After a long break'), findsOneWidget);
    // Edited (or synced) while the player is paused: the position does not
    // move, the new lyrics are still located.
    var edited = lyrics.copy();
    edited.lineList.last.partList.last.text.v = 'pause';
    await tester.pumpWidget(view(edited));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('Karaoke'), findsNothing);
    expect(find.bySemanticsLabel('After a long pause'), findsOneWidget);
  });

  testWidgets('paused at 0, the lead-in dots before the first line', (
    tester,
  ) async {
    const style = KaraokeLyricsStyle.dark;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KaraokeLyricsView(
            lyrics: parseLrcLyrics('[00:02.000]Hello\n').lyrics,
            positionMs: () => 0,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    // 2 s before the line: 2 dots of 3.
    var dots = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == style.leadInColor,
    );
    expect(dots, findsNWidgets(2));
  });

  testWidgets('a page fits a short box', (tester) async {
    var long = parseLrcLyrics('''
[00:01.000]We met when we were in school, never took no shit from no one
[00:04.000]We weren't fools, the teacher says we're dumb, we're only having fun
''').lyrics;
    Future<void> pumpIn(double height) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: height,
              child: KaraokeLyricsView(lyrics: long, positionMs: () => 0),
            ),
          ),
        ),
      ),
    );
    Rect lineRect(String start) =>
        tester.getRect(find.bySemanticsLabel(RegExp('^$start')));
    await pumpIn(400);
    var box = tester.getRect(find.byType(KaraokeLyricsView));
    // Room enough: the width decides the font (33 px, wrapped lines).
    var tall = lineRect('We met').height;
    expect(tall, greaterThan(60));
    expect(lineRect('We weren').bottom, lessThanOrEqualTo(box.bottom));

    await pumpIn(100);
    box = tester.getRect(find.byType(KaraokeLyricsView));
    expect(box.height, 100);
    // Shrunk to fit: both lines whole, inside the box.
    var first = lineRect('We met');
    var second = lineRect('We weren');
    expect(first.height, lessThan(tall));
    expect(first.top, greaterThanOrEqualTo(box.top));
    expect(second.bottom, lessThanOrEqualTo(box.bottom));
  });

  testWidgets('songbook text with chords', (tester) async {
    var songbook = parseLyricsText('''
[Chorus]
Il en faut [C]peu
[G]Vrai|ment
''').lyrics;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SongbookLyricsView(lyrics: songbook, transpose: 2),
          ),
        ),
      ),
    );
    expect(find.text('Chorus'), findsOneWidget);
    expect(find.text('D '), findsOneWidget);
    expect(find.text('A '), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongbookLyricsView(lyrics: songbook, showChords: false),
        ),
      ),
    );
    expect(find.text('Il en faut peu'), findsOneWidget);
    expect(find.text('Vraiment'), findsOneWidget);
  });

  testWidgets('songbook: a chorus sung twice is labelled twice', (
    tester,
  ) async {
    var text = '''
[Chorus]
La la

[Chorus]
La la
''';
    var songbook = parseLyricsText(text).lyrics;
    // As the text format writes it.
    expect(formatLyricsText(songbook), text);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SongbookLyricsView(lyrics: songbook)),
      ),
    );
    expect(find.text('Chorus'), findsNWidgets(2));
  });
}
