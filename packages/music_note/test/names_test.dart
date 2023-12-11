import 'package:tekaly_music_note/music_note.dart';

import 'package:test/test.dart';

void main() {
  group('keyNames', () {
    test('size', () {
      expect(keyNames.length, octaveNoteCount);
    });
  });
}
