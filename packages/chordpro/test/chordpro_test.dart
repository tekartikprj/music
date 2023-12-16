import 'package:tekaly_chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('chordpro', () {
    test('First Test', () {
      expect(textLinesToChordProLines(['E  D', 'Id t']), ['[E]Id [D]t']);
      expect(textLinesToChordProLines(['E D', 'I t']), ['[E]I [D]t']);
      expect(textLinesToChordProLines(['E', 'I']), ['[E]I']);
    });
  });
}
