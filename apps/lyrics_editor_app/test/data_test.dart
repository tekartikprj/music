import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:lyrics_editor_app/src/data/lyrics_app_db.dart';
import 'package:lyrics_editor_app/src/data/lyrics_file_format.dart';
import 'package:lyrics_editor_app/src/data/lyrics_opener.dart';
import 'package:lyrics_editor_app/src/data/lyrics_pairing.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

/// The naming of the cokedisney kiosk assets.
const _kioskFolder = [
  'hakuna.mp3',
  'hakuna-vocals.mp3',
  'hakuna-no_vocals.mp3',
  'hakuna.lrc',
  'jungle.mp3',
  'jungle.lrc',
  'notes.txt.bak',
];

const _lrc = '''[ti:Hakuna]
[ar:Timon]
[00:01.000]Ha<00:01.500>ku<00:02.000>na
[00:04.000]Ma<00:04.500>ta<00:05.000>ta
''';

void main() {
  group('pairing', () {
    test('a lyrics file finds its tracks', () {
      var pairing = pairLyricsFiles('hakuna.lrc', _kioskFolder);
      expect(pairing.lyrics, 'hakuna.lrc');
      expect(pairing.tracks, const [
        LyricsPairedTrack('song', 'hakuna.mp3'),
        LyricsPairedTrack('vocals', 'hakuna-vocals.mp3'),
        LyricsPairedTrack('no_vocals', 'hakuna-no_vocals.mp3'),
      ]);
    });

    test('a media file finds its lyrics and the other tracks', () {
      var pairing = pairLyricsFiles('hakuna-vocals.mp3', _kioskFolder);
      expect(pairing.lyrics, 'hakuna.lrc');
      expect(pairing.tracks.map((track) => track.name), [
        'song',
        'vocals',
        'no_vocals',
      ]);
    });

    test('lyrics preference and extension preference', () {
      var pairing = pairLyricsFiles('song.ogg', [
        'song.txt',
        'song.lrc',
        'song.lyrics.json',
        'song.mp3',
      ]);
      expect(pairing.lyrics, 'song.lyrics.json');
      // The one opened, then the preferred extension for the others.
      expect(pairing.tracks, const [LyricsPairedTrack('song', 'song.ogg')]);
      pairing = pairLyricsFiles('song.lrc', ['song.ogg', 'song.mp3']);
      expect(pairing.tracks, const [LyricsPairedTrack('song', 'song.mp3')]);
    });

    test('file names', () {
      var name = LyricsFileName.parse('A song.lyrics.json');
      expect(name.base, 'A song');
      expect(name.extension, 'lyrics.json');
      expect(name.kind, LyricsFileKind.lyrics);
      name = LyricsFileName.parse('A-Instrumental.MP3');
      expect(name.base, 'A');
      expect(name.track, 'instrumental');
      expect(LyricsFileName.parse('readme').kind, LyricsFileKind.other);
      expect(LyricsFileName.parse('.lrc').kind, LyricsFileKind.other);
    });
  });

  group('formats', () {
    test('save as LRC and reopen gives the same times', () {
      var document = readLyricsDocument('hakuna.lrc', _lrc);
      expect(document.title.v, 'Hakuna');
      expect(document.artist.v, 'Timon');
      expect(document.source.v, 'hakuna.lrc');
      var written = writeLyricsDocument(document, LyricsFileFormat.lrc);
      var reopened = readLyricsDocument('hakuna.lrc', written);
      expect(reopened.lyricsOrEmpty, document.lyricsOrEmpty);
      expect(reopened.title.v, 'Hakuna');
    });

    test('native keeps everything', () {
      var document = readLyricsDocument('hakuna.lrc', _lrc)
        ..media.v = CvLyricsMedia.file('hakuna.mp3');
      var reopened = readLyricsDocument(
        'hakuna.lyrics.json',
        writeLyricsDocument(document, LyricsFileFormat.native),
      );
      expect(reopened, document);
      expect(lyricsFormatLosses(document, LyricsFileFormat.native), isEmpty);
    });

    test('text keeps the title, the artist and the chords', () {
      var document = CvLyricsDocument.of(
        parseLyricsText('Il en faut [C]peu').lyrics,
        title: 'Peu',
        artist: 'Baloo',
      );
      var text = writeLyricsDocument(document, LyricsFileFormat.text);
      var reopened = readLyricsDocument('peu.cho', text);
      expect(reopened.title.v, 'Peu');
      expect(reopened.artist.v, 'Baloo');
      expect(reopened.lyricsOrEmpty.hasChords, isTrue);
    });

    test('losses', () {
      var document = CvLyricsDocument.of(
        parseLyricsText('[Chorus]\nIl en faut [C]peu').lyrics,
      );
      expect(lyricsFormatLosses(document, LyricsFileFormat.lrc), [
        'the chords',
        'the sections',
      ]);
      expect(lyricsFormatLosses(document, LyricsFileFormat.text), isEmpty);
      var timed = readLyricsDocument('hakuna.lrc', _lrc)
        ..media.v = CvLyricsMedia.file('hakuna.mp3');
      expect(lyricsFormatLosses(timed, LyricsFileFormat.text), [
        'every time',
        'the media it goes with',
      ]);
      expect(lyricsFileFormatOf('a.vtt'), LyricsFileFormat.subtitles);
      expect(lyricsFileFormatOf('a.mp3'), isNull);
      expect(lyricsFileNameIn('a.lyrics.json', LyricsFileFormat.lrc), 'a.lrc');
    });
  });

  group('opener', () {
    test('a media file on disk pairs with the folder', () async {
      var fs = newFileSystemMemory();
      await fs.directory('/kiosk').create();
      for (var name in _kioskFolder) {
        await fs
            .file('/kiosk/$name')
            .writeAsString(name.endsWith('.lrc') ? _lrc : name);
      }
      var opener = LyricsOpener(fs: fs);
      var opened = (await opener.openFiles([
        LyricsOpenedFile.fs(fs, '/kiosk/hakuna-no_vocals.mp3'),
      ]))!;
      expect(opened.key, '/kiosk/hakuna.lrc');
      expect(opened.lyricsFile!.path, '/kiosk/hakuna.lrc');
      expect(opened.format, LyricsFileFormat.lrc);
      expect(opened.tracks.map((track) => track.file.path), [
        '/kiosk/hakuna.mp3',
        '/kiosk/hakuna-vocals.mp3',
        '/kiosk/hakuna-no_vocals.mp3',
      ]);
      expect(opened.document.title.v, 'Hakuna');
      expect(opened.document.media.v!.tracks.v, hasLength(3));
      expect(opened.lyricsModified, isNotNull);
      expect(opened.description, 'hakuna.lrc + hakuna.mp3');
      var recent = await opener.openRecent(opened.toRecent());
      expect(recent!.key, opened.key);
    });

    test('picked files (web): pairing among them only', () async {
      var opener = const LyricsOpener();
      var opened = (await opener.openFiles([
        LyricsOpenedFile.bytes('song.mp3', Uint8List(0)),
        LyricsOpenedFile.bytes(
          'song.lrc',
          Uint8List.fromList(utf8.encode(_lrc)),
        ),
      ]))!;
      expect(opened.key, 'song.lrc');
      expect(opened.tracks.single.file.name, 'song.mp3');
      expect(opened.document.lyricsOrEmpty.isTimed, isTrue);
      // A media file alone: an empty document named after it.
      opened = (await opener.openFiles([
        LyricsOpenedFile.bytes('Artist - Title.mp3', Uint8List(0)),
      ]))!;
      expect(opened.document.lyricsOrEmpty.isEmpty, isTrue);
      expect(opened.document.title.v, 'Artist - Title');
      expect(
        await opener.openFiles([
          LyricsOpenedFile.bytes('readme.md', Uint8List(0)),
        ]),
        isNull,
      );
      expect(await opener.openRecent(opened.toRecent()), isNull);
    });

    test('youtube and new documents', () {
      var opener = const LyricsOpener();
      var opened = opener.openYoutube('https://youtu.be/dQw4w9WgXcQ?t=42')!;
      expect(opened.key, 'youtube:dQw4w9WgXcQ');
      expect(opened.youtube!.start, const Duration(seconds: 42));
      expect(opened.document.media.v!.kind.v, CvLyricsMediaKind.youtube);
      expect(opener.openYoutube('not a link'), isNull);
      var pasted = opener.newDocument(text: 'Hel|lo\nWorld');
      expect(pasted.document.lyricsOrEmpty.lineList, hasLength(2));
      expect(pasted.key, startsWith('untitled:'));
    });
  });

  test('drafts, recents and settings', () async {
    var factory = newSdbFactoryMemory();
    var db = await LyricsAppDb.open(factory);
    expect(await db.getDraft('/a.lrc'), isNull);
    var document = readLyricsDocument('a.lrc', _lrc);
    var store = LyricsDraftStore(db, '/a.lrc');
    await store.save(document);
    var draft = await db.getDraft('/a.lrc');
    expect(draft!.document, document);
    await db.deleteDraft('/a.lrc');
    expect(await db.getDraft('/a.lrc'), isNull);

    for (var i = 0; i < lyricsRecentMax + 2; i++) {
      await db.addRecent(
        LyricsRecent(
          key: 'k$i',
          name: 'n$i',
          opened: DateTime.fromMillisecondsSinceEpoch(1000 + i),
        ),
      );
    }
    var recents = await db.getRecents();
    expect(recents, hasLength(lyricsRecentMax));
    expect(recents.first.key, 'k${lyricsRecentMax + 1}');

    var settings = await db.loadSettings();
    expect(settings.tapLatencyMs.value, lyricsEditorDefaultTapLatencyMs);
    await settings.setTapLatencyMs(80);
    await settings.setAudioLatencyMs(200);
    await db.close();
    db = await LyricsAppDb.open(factory);
    settings = await db.loadSettings();
    expect(settings.tapLatencyMs.value, 80);
    expect(settings.audioLatencyMs.value, 200);
    await db.close();
  });
}
