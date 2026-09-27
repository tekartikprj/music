import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

void main() {
  test('transpose', () {
    expect(transposeLyricsChord('C', 2), 'D');
    expect(transposeLyricsChord('Am7', 2), 'Bm7');
    expect(transposeLyricsChord('B', 1), 'C');
    expect(transposeLyricsChord('D/F#', 1), 'D#/G');
    expect(transposeLyricsChord('Bb', 2), 'C');
    expect(transposeLyricsChord('Eb', 1), 'E');
    expect(transposeLyricsChord('Eb', 2), 'F');
    expect(transposeLyricsChord('F#m7b5', -1), 'Fm7b5');
    expect(transposeLyricsChord('C', -1), 'B');
    expect(transposeLyricsChord('G', 12), 'G');
    expect(transposeLyricsChord('N.C.', 3), 'N.C.');
  });
  test('transpose lyrics', () {
    initTekalyLyricsBuilders();
    var lyrics = parseLyricsText('[C]la [G]la [Am]la').lyrics
      ..transposeChords(-2);
    expect(formatLyricsText(lyrics).trim(), '[A#]la [F]la [Gm]la');
  });
}
