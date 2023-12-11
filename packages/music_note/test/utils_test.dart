import 'package:tekaly_music_note/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('utils', () {
    test('semitonesSameKey', () {
      expect(semitonesSameKey(0, 0), isTrue);
      expect(semitonesSameKey(0, 12), isTrue);
      expect(semitonesSameKey(0, 1), isFalse);
    });
  });
}
