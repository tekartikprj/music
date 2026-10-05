import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

/// The editor of [lyrics] on a clock player at [now] (no latency).
class _Harness {
  var now = 0;
  late final player = ClockLyricsPlayer(nowMs: () => now);
  final store = LyricsEditorStoreMemory();
  final settings = LyricsEditorSettingsMemory(tapLatencyMs: 0);
  late final LyricsEditorController controller;

  _Harness(String lyrics) {
    initTekalyLyricsBuilders();
    controller = LyricsEditorController(
      document: CvLyricsDocument.of(
        parseLyricsText(lyrics).lyrics,
        title: 'Karaoke',
      ),
      player: player,
      settings: settings,
      store: store,
    );
  }

  Widget app() => MaterialApp(
    home: LyricsTimingKeys(
      controller: controller,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            LyricsEditorSaveButton(controller: controller),
            LyricsTimingMenuButton(controller: controller),
          ],
        ),
        body: LyricsTimingEditor(controller: controller),
      ),
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await player.dispose();
    await store.close();
  }
}

void main() {
  testWidgets('timing editor taps syllables', (tester) async {
    var harness = _Harness('Ka|ra|o|ke');
    await tester.pumpWidget(harness.app());
    await tester.pump();
    expect(find.text('TAP (space)'), findsOneWidget);
    expect(find.text('Next: Ka'), findsOneWidget);
    await tester.tap(find.text('TAP (space)'));
    await tester.pump();
    await tester.tap(find.text('TAP (space)'));
    await tester.pump();
    expect(find.text('Next: o'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text('Next: ra'), findsOneWidget);
    await tester.tap(find.byTooltip('Save now'));
    await tester.pump();
    var parts = harness.store.saved!.lyricsOrEmpty.lineList.first.partList;
    expect(parts.first.startMs.v, 0);
    expect(parts[1].startMs.v, isNull);
    expect(harness.store.saved!.title.v, 'Karaoke');
    expect(find.byTooltip('Save now'), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('space held in hold mode gives the start and the end', (
    tester,
  ) async {
    var harness = _Harness('Hel|lo world');
    var controller = harness.controller;
    await tester.pumpWidget(harness.app());
    await tester.pump();
    await tester.tap(find.text('Hold mode'));
    await tester.pump();
    await harness.player.seek(1000);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await harness.player.seek(1400);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    var part = controller.lyrics.lineList.first.partList.first;
    expect(part.startMs.v, 1000);
    expect(part.endMs.v, 1400);
    expect(find.text('Next: lo'), findsOneWidget);
    // Mixed granularities: the line end, now.
    await harness.player.seek(2500);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.lyrics.lineList.first.endMs.v, 2500);
    await harness.dispose(tester);
  });

  testWidgets('changes made elsewhere: reload or keep mine', (tester) async {
    var harness = _Harness('Ka|ra|o|ke');
    await tester.pumpWidget(harness.app());
    await tester.pump();
    harness.store.changeRemotely(
      CvLyricsDocument.of(parseLyricsText('Other words').lyrics),
    );
    await tester.pump();
    expect(
      find.text('These lyrics were changed elsewhere meanwhile.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reload'));
    await tester.pump();
    expect(find.text('Next: Other'), findsOneWidget);
    expect(harness.controller.remoteChanged, isFalse);

    harness.store.changeRemotely(
      CvLyricsDocument.of(parseLyricsText('Third one').lyrics),
    );
    await tester.pump();
    await tester.tap(find.text('Keep mine'));
    await tester.pump();
    expect(find.text('Next: Other'), findsOneWidget);
    await harness.controller.save();
    expect(harness.store.saved!.lyricsOrEmpty.text, 'Other words');
    await harness.dispose(tester);
  });

  test('one undo history for a tap and a text edit', () async {
    var harness = _Harness('Ka|ra|o|ke');
    var controller = harness.controller;
    await harness.player.seek(1000);
    controller.tap();
    var tapped = controller.lyrics.copy();
    expect(tapped.lineList.first.partList.first.startMs.v, 1000);
    // A text edit keeps the time of the first syllable.
    var text = LyricsTextController(lyrics: controller.lyrics)
      ..text.text = 'Ka|ra|o|ke\nMore';
    controller.setLyrics(text.lyricsOfText());
    expect(controller.lyrics.lineList, hasLength(2));
    expect(controller.lyrics.lineList.first.partList.first.startMs.v, 1000);
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(controller.lyrics, tapped);
    expect(controller.tapEditor!.cursorUnit, const LyricsUnitRef(0, 1));
    controller.undo();
    expect(controller.lyrics.isTimed, isFalse);
    expect(controller.canUndo, isFalse);
    controller.redo();
    controller.redo();
    expect(controller.lyrics.lineList, hasLength(2));
    expect(controller.canRedo, isFalse);
    text.dispose();
    controller.dispose();
    await harness.player.dispose();
  });

  test('text keeps the times across an edit', () {
    initTekalyLyricsBuilders();
    var lyrics = parseLrcLyrics(
      '[00:01.000]Il en faut peu\n[00:05.000]Vraiment très peu',
    ).lyrics;
    var text = LyricsTextController(lyrics: lyrics);
    expect(text.dirty, isFalse);
    expect(text.status, '2 line(s), timed by line');
    text.text.text = 'Il en faut peu\nVraiment très peu pour être heureux';
    expect(text.dirty, isTrue);
    var edited = text.lyricsOfText();
    expect(edited.lineList[0].startMs.v, 1000);
    expect(edited.lineList[1].startMs.v, 5000);
    // A whole LRC pasted is imported with its times.
    text.text.text = '[00:02.000]Pasted';
    expect(text.lyricsOfText().lineList.single.startMs.v, 2000);
    text.dispose();
    expect(lyricsFileBaseName('My: song.mp3'), 'My_ song');
  });

  test('LRC mode edits the times, keeps the chords', () {
    initTekalyLyricsBuilders();
    var lyrics = parseLrcLyrics(
      '[00:01.000]Il en faut peu\n[00:05.000]Vrai|ment très peu',
    ).lyrics;
    lyrics.lineList[0].partList[0].chord.v = 'C';
    lyrics.lineList[0].section.v = 'Verse';
    var text = LyricsTextController(
      lyrics: lyrics,
      format: LyricsTextFormat.lrc,
    );
    expect(text.isLrc, isTrue);
    expect(
      text.text.text,
      '[00:01.000]Il en faut peu\n[00:05.000]Vrai|ment très peu\n',
    );
    expect(text.dirty, isFalse);
    expect(text.status, '2 line(s), timed by line, with chords');
    // A time changed, a line added: what the text says.
    text.text.text =
        '[ar:Baloo]\n[00:01.000]Il en faut peu\n[00:06.000]Vrai|ment très peu\n'
        '[00:08.000]<00:08.000>Pour <00:08.500>ê|tre heureux';
    expect(text.dirty, isTrue);
    var edited = text.lyricsOfText();
    var lines = edited.lineList;
    expect(lines.map((line) => line.startMs.v), [1000, 6000, 8000]);
    expect(lines[0].partList[0].chord.v, 'C');
    expect(lines[0].section.v, 'Verse');
    expect(lines[1].partList[0].isJoined, isTrue);
    expect(lines[1].partList.map((part) => part.textOrEmpty), [
      'Vrai',
      'ment',
      'très',
      'peu',
    ]);
    expect(lines[2].partList.map((part) => part.startMs.v), [
      8000,
      8500,
      null,
      null,
    ]);
    expect(lines[2].partList[1].isJoined, isTrue);
    expect(text.importedArtist, 'Baloo');
    // Plain lines are untimed lines.
    text.text.text = 'La la\nlou';
    expect(text.lyricsOfText().isTimed, isFalse);
    text.reset(edited);
    expect(text.dirty, isFalse);
    expect(text.text.text, contains('[00:06.000]Vrai|ment très peu'));
    expect(text.text.text, contains('<00:08.500>ê|tre heureux'));
    text.dispose();
  });
}
