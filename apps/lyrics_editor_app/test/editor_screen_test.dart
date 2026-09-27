import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:lyrics_editor_app/src/app_context.dart';
import 'package:lyrics_editor_app/src/data/lyrics_file_format.dart';
import 'package:lyrics_editor_app/src/data/lyrics_opener.dart';
import 'package:lyrics_editor_app/src/player/lyrics_players.dart';
import 'package:lyrics_editor_app/src/screen/editor_screen.dart';
import 'package:lyrics_editor_app/src/screen/home_screen.dart';

const _lrc = '''[ti:Hakuna]
[ar:Timon]
[00:01.000]Ha<00:01.500>ku<00:02.000>na
[00:04.000]Ma<00:04.500>ta<00:05.000>ta
''';

/// A few frames, the async work (memory databases) done in between.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late FileSystem fs;
  late LyricsAppContext appContext;

  setUp(() async {
    fs = newFileSystemMemory();
    await fs.directory('/kiosk').create();
    await fs.file('/kiosk/hakuna.lrc').writeAsString(_lrc);
    for (var name in ['hakuna.mp3', 'hakuna-vocals.mp3']) {
      await fs.file('/kiosk/$name').writeAsString('audio');
    }
    appContext = await LyricsAppContext.init(
      sdbFactory: newSdbFactoryMemory(),
      fs: fs,
      createPlayer: createClockLyricsPlayer,
    );
  });

  tearDown(() => appContext.close());

  Future<LyricsOpenedDocument> openKiosk() async => (await appContext.opener
      .openFiles([LyricsOpenedFile.fs(fs, '/kiosk/hakuna.lrc')]))!;

  Future<void> pumpEditor(
    WidgetTester tester,
    LyricsOpenedDocument opened,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LyricsEditorScreen(appContext: appContext, opened: opened),
      ),
    );
    await _settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    // The draft saved on leaving, before the database is closed.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }

  /// Wait for a menu or a dialog to be done animating.
  Future<void> animations(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('kiosk: re-time and save the LRC in place', (tester) async {
    var opened = await tester.runAsync(openKiosk);
    await pumpEditor(tester, opened!);
    expect(find.text('Hakuna'), findsOneWidget);
    expect(find.text('hakuna.lrc + hakuna.mp3'), findsOneWidget);
    // Everything is timed already: the timing tab, nothing left.
    expect(find.text('Done: everything is timed'), findsOneWidget);

    // Shift every time by 100 ms.
    await tester.tap(find.byTooltip('Show menu'));
    await animations(tester);
    await tester.tap(find.text('Offset…'));
    await animations(tester);
    await tester.enterText(find.byType(TextField).last, '100');
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(find.textContaining('not saved'), findsNothing);

    // Ctrl+S: the LRC loses the offset (applied to the times), once.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(find.text('Saving as LRC'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    var saved = await tester.runAsync<String>(
      () => fs.file('/kiosk/hakuna.lrc').readAsString(),
    );
    expect(saved, contains('[ti:Hakuna]'));
    expect(saved, contains('[00:01.100]'));
    expect(
      await tester.runAsync(() => appContext.db.getDraft(opened.key)),
      isNull,
    );
    await close(tester);
  });

  testWidgets('a draft newer than its file is offered back', (tester) async {
    var opened = (await tester.runAsync(openKiosk))!;
    var draft = readLyricsDocument('hakuna.lrc', _lrc)..title.v = 'Draft';
    await tester.runAsync(() => appContext.db.saveDraft(opened.key, draft));
    await pumpEditor(tester, opened);
    expect(find.text('Restore the draft?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await _settle(tester);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.textContaining('not saved'), findsOneWidget);
    await close(tester);
  });

  testWidgets('pasted lyrics: text, then timing, one undo', (tester) async {
    var opened = appContext.opener.newDocument(text: 'Hel|lo');
    await pumpEditor(tester, opened);
    expect(find.text('Next: Hel'), findsOneWidget);
    // To the text tab, edit, back to the timing tab.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Hel|lo\nWorld');
    await tester.tap(find.text('Timing'));
    await _settle(tester);
    expect(find.text('World'), findsOneWidget);
    // Undo the text edit.
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await _settle(tester);
    expect(find.text('World'), findsNothing);
    await close(tester);
  });

  testWidgets('home screen: recent documents', (tester) async {
    var opened = (await tester.runAsync(openKiosk))!;
    await tester.runAsync(() => appContext.db.addRecent(opened.toRecent()));
    await tester.pumpWidget(
      MaterialApp(home: LyricsHomeScreen(appContext: appContext)),
    );
    await _settle(tester);
    expect(find.text('Open files…'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('/kiosk/hakuna.lrc'), findsOneWidget);
    await tester.tap(find.text('Hakuna'));
    await _settle(tester);
    expect(find.text('hakuna.lrc + hakuna.mp3'), findsOneWidget);
    await close(tester);
  });

  testWidgets('home screen: open a sample', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LyricsHomeScreen(appContext: appContext)),
    );
    await _settle(tester);
    expect(find.text('Samples'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Frère Jacques'), 100);
    await tester.tap(find.text('Frère Jacques'));
    await _settle(tester);
    expect(find.text('frere_jacques.lrc + frere_jacques.mp3'), findsOneWidget);
    expect(find.text('Done: everything is timed'), findsOneWidget);
    await close(tester);
  });
}
