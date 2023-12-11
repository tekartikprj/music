import 'package:tekaly_music_note/music_note.dart';

import 'package:test/test.dart';

var cMajor = Chord(c, major);
var cMinor = Chord(c, minor);
var dMajor = Chord(d, major);
var dMinor = Chord(d, minor);

void main() {
  group('Chord', () {
    test('equals', () {
      expect(cMajor, cMajor);
      expect(cMajor, Chord(c, major));
      expect(cMajor, isNot(cMinor));
      expect(cMajor, isNot(dMajor));
    });
    test('toString', () {
      expect(cMajor.toString(), 'C Major[R, M3, 5]');
    });
    test('containsKey', () {
      expect(cMajor.containsKey(c), isTrue);
      expect(cMajor.containsKey(e), isTrue);
      expect(cMajor.containsKey(g), isTrue);
      expect(cMajor.containsKey(d), isFalse);
    });
    test('findInterval', () {
      expect(cMajor.findInterval(c), root);
      expect(cMajor.findInterval(e), major3rd);
      expect(cMajor.findInterval(d), isNull);
    });
    test('transpose', () {
      expect(cMajor.transpose(0), cMajor);
      expect(cMajor.transpose(2), dMajor);
    });
  });
}
