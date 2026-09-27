import 'dart:convert';
import 'dart:typed_data';

import 'package:tekaly_lyrics_core/lyrics_core.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initTekalyLyricsBuilders);

  test('document json round trip', () {
    var lyrics = parseLrcLyrics('[00:01.000]Il en <00:01.500>faut peu').lyrics;
    var document = CvLyricsDocument.of(
      lyrics,
      title: 'Il en faut peu',
      artist: 'Baloo',
      media: CvLyricsMedia.file(
        'song.mp3',
        tracks: [
          CvLyricsTrack.of('vocals', 'song-vocals.mp3'),
          CvLyricsTrack.of('instrumental', 'song-no_vocals.mp3'),
        ],
      ),
      source: 'song.lrc',
    )..instrumental.v = false;
    var text = document.toJsonText();
    expect(text, endsWith('}\n'));
    var read = parseLyricsDocumentJson(text);
    expect(read, document);
    expect(read.media.v!.tracks.v![1].path.v, 'song-no_vocals.mp3');
    expect(read.lyricsOrEmpty.hasPartTiming, isTrue);
    expect(read.copy(), document);
  });

  test('document with no lyrics', () {
    var document = CvLyricsDocument()..media.v = CvLyricsMedia.none();
    expect(document.lyricsOrEmpty.isEmpty, isTrue);
    expect(
      parseLyricsDocumentJson(document.toJsonText()).media.v!.kind.v,
      CvLyricsMediaKind.none,
    );
    expect(
      () => parseLyricsDocumentJson('[]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('decodeLyricsBytes', () {
    expect(
      decodeLyricsBytes(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('été')]),
      ),
      'été',
    );
    expect(decodeLyricsBytes(Uint8List.fromList(utf8.encode('être'))), 'être');
    // Latin-1 (an old LRC file): not valid UTF-8.
    expect(
      decodeLyricsBytes(Uint8List.fromList(latin1.encode('être'))),
      'être',
    );
  });
}
