import 'package:tekaly_chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('chordpro', () {
    test('textToChordPro', () {
      expect(textToChordPro('E D  E\nI'), '[E]I [D]  [E]');
    });
    test('ChordLyric', () {
      expect(textLinesToChordProLines(['E D  E', 'I']), ['[E]I [D]  [E]']);
      expect(textLinesToChordProLines(['E  D', 'Id t']), ['[E]Id [D]t']);
      expect(textLinesToChordProLines(['E D', 'I t']), ['[E]I [D]t']);
      expect(textLinesToChordProLines(['E', 'I']), ['[E]I']);
    });
    test('Section', () {
      expect(textLinesToChordProLines(['[Intro]', 'Am C  E']), [
        '{start_of_bridge: Intro}',
        '[Am] [C]  [E]',
        '{end_of_bridge}',
      ]);
      expect(textLinesToChordProLines(['[Intro]', 'Am']), [
        '{start_of_bridge: Intro}',
        '[Am]',
        '{end_of_bridge}',
      ]);
      expect(textLinesToChordProLines(['[Verse 1]']), [
        '{start_of_verse: Verse 1}',
        '{end_of_verse}',
      ]);
    });
  });
}
