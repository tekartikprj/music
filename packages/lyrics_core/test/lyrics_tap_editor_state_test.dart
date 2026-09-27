import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

void main() {
  test('state and restore', () {
    initTekalyLyricsBuilders();
    var editor = LyricsTapEditor(parseLyricsText('Ka|ra|o|ke').lyrics);
    var before = editor.state;
    editor.tap(100);
    editor.tap(200);
    var afterTwo = editor.state;
    expect(editor.cursorUnit, const LyricsUnitRef(0, 2));
    // The state is a copy: later taps do not change it.
    editor.tap(300);
    expect(afterTwo.lyrics.lineList.first.partList[2].startMs.v, isNull);
    editor.restore(afterTwo);
    expect(editor.cursorUnit, const LyricsUnitRef(0, 2));
    expect(editor.lastTapped, const LyricsUnitRef(0, 1));
    expect(editor.lyrics.lineList.first.partList[2].startMs.v, isNull);
    editor.restore(before);
    expect(editor.cursorUnit, const LyricsUnitRef(0, 0));
    expect(editor.lastTapped, isNull);
    expect(editor.lyrics.isTimed, isFalse);
  });

  test('an LRC line start times its first syllable', () {
    initTekalyLyricsBuilders();
    var lyrics = parseLrcLyrics(
      '[00:01.000]Ha<00:01.500>ku\n[00:04.000]Ma<00:04.500>ta\n[00:06.000]Plain',
    ).lyrics;
    var editor = LyricsTapEditor(lyrics);
    expect(editor.timeOf(const LyricsUnitRef(0, 0)), isNull);
    expect(editor.isTimed(const LyricsUnitRef(0, 0)), isTrue);
    expect(editor.firstUntimedIndex, editor.units.length);
    editor = LyricsTapEditor(parseLyricsText('Hel|lo\nWorld').lyrics);
    expect(editor.firstUntimedIndex, 0);
  });
}
