import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrics_editor_app/src/data/lyrics_file_format.dart';
import 'package:lyrics_editor_app/src/data/lyrics_opener.dart';
import 'package:lyrics_editor_app/src/samples/lyrics_sample_songs.dart';
import 'package:lyrics_editor_app/src/samples/lyrics_samples.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

LyricsSampleSong _song(String baseName) =>
    lyricsSampleSongs.firstWhere((song) => song.baseName == baseName);

/// How strong [hz] is in the 16-bit mono wav [bytes] around [atMs].
double _magnitude(Uint8List bytes, int atMs, double hz) {
  var data = ByteData.sublistView(bytes, 44);
  var center = lyricsSampleRate * atMs ~/ 1000;
  const window = lyricsSampleRate ~/ 20; // 50 ms
  var coefficient = 2 * cos(2 * pi * hz / lyricsSampleRate);
  var s1 = 0.0;
  var s2 = 0.0;
  for (var i = center - window ~/ 2; i < center + window ~/ 2; i++) {
    var sample = data.getInt16(i * 2, Endian.little) / 32768;
    var s0 = sample + coefficient * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  return sqrt(s1 * s1 + s2 * s2 - coefficient * s1 * s2);
}

const _melodyNotes = {
  'G3': 196.00,
  'C4': 261.63,
  'D4': 293.66,
  'E4': 329.63,
  'F4': 349.23,
  'G4': 392.00,
  'A4': 440.00,
};

/// The note of [_melodyNotes] loudest around [atMs].
String _noteAt(Uint8List wav, int atMs) {
  var best = '';
  var bestMagnitude = -1.0;
  for (var entry in _melodyNotes.entries) {
    var magnitude = _magnitude(wav, atMs, entry.value);
    if (magnitude > bestMagnitude) {
      best = entry.key;
      bestMagnitude = magnitude;
    }
  }
  return best;
}

/// The first MPEG-1 Layer III frame header of the mp3 [bytes] (after its
/// ID3v2 tag).
({int bitrate, int rate, bool mono}) _mp3Header(Uint8List bytes) {
  var offset = 0;
  if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
    // ID3v2: a 10 bytes header, a syncsafe size.
    var size = (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
    offset = 10 + size;
  }
  while (!(bytes[offset] == 0xFF && (bytes[offset + 1] & 0xE0) == 0xE0)) {
    offset++;
  }
  var b1 = bytes[offset + 1];
  var b2 = bytes[offset + 2];
  var b3 = bytes[offset + 3];
  // MPEG-1 (0b11), Layer III (0b01).
  expect((b1 >> 3) & 3, 3, reason: 'MPEG-1');
  expect((b1 >> 1) & 3, 1, reason: 'Layer III');
  const bitrates = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192];
  const rates = [44100, 48000, 32000];
  return (
    bitrate: bitrates[b2 >> 4],
    rate: rates[(b2 >> 2) & 3],
    mono: (b3 >> 6) == 3,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the assets are what the generator writes', () async {
    for (var song in lyricsSampleSongs) {
      var files = await loadLyricsSampleFiles(song);
      expect(files.map((file) => file.name), song.fileNames);
      const reason = 'run dart run tool/generate_samples.dart';
      expect(
        await files.first.readAsBytes(),
        song.lyricsFileBytes(),
        reason: '${song.lyricsFileName}: $reason',
      );
      for (var file in files.skip(1)) {
        var header = _mp3Header(await file.readAsBytes());
        expect(header, (
          bitrate: 128,
          rate: 44100,
          mono: true,
        ), reason: file.name);
        // 128 kbps: 16 000 bytes a second.
        var bytes = (await file.readAsBytes()).length;
        expect(
          bytes / 16000,
          closeTo(song.durationMs / 1000, 0.5),
          reason: '${file.name}: $reason',
        );
      }
    }
  });

  test('timing of each sample', () {
    var frere = readLyricsDocument(
      'frere_jacques.lrc',
      _song('frere_jacques').lyricsFileContent(),
    );
    expect(frere.title.v, 'Frère Jacques');
    expect(frere.lyricsOrEmpty.lineList, hasLength(8));
    expect(frere.lyricsOrEmpty.hasPartTiming, isTrue);
    // The first syllable of each line starts with the line.
    var editor = LyricsTapEditor(frere.lyricsOrEmpty);
    expect(editor.firstUntimedIndex, editor.units.length);

    var lune = readLyricsDocument(
      'au_clair_de_la_lune.lrc',
      _song('au_clair_de_la_lune').lyricsFileContent(),
    );
    expect(lune.lyricsOrEmpty.isTimed, isTrue);
    expect(lune.lyricsOrEmpty.hasPartTiming, isFalse);
    expect(lune.lyricsOrEmpty.lineList.map((line) => line.startMs.v), [
      4000,
      8000,
      12000,
      16000,
    ]);
    // Timing the syllables starts on the second one of the first line.
    editor = LyricsTapEditor(lune.lyricsOrEmpty);
    expect(editor.units[editor.firstUntimedIndex], const LyricsUnitRef(0, 1));

    var twinkle = readLyricsDocument(
      'twinkle_twinkle.cho',
      _song('twinkle_twinkle').lyricsFileContent(),
    );
    expect(twinkle.title.v, 'Twinkle, Twinkle, Little Star');
    expect(twinkle.lyricsOrEmpty.isTimed, isFalse);
    expect(twinkle.lyricsOrEmpty.hasChords, isTrue);
    expect(twinkle.lyricsOrEmpty.lineList, hasLength(6));
  });

  test('the melody is sung when the lyrics say', () {
    for (var song in lyricsSampleSongs) {
      var wav = song.audioWavContent(
        song.tracks ? '${song.baseName}-vocals.mp3' : '${song.baseName}.mp3',
      );
      expect(wav.length, 44 + song.durationMs * lyricsSampleRate ~/ 1000 * 2);
      var lines = song.timedLyrics().lineList;
      for (var l = 0; l < lines.length; l++) {
        var parts = lines[l].partList;
        for (var p = 0; p < parts.length; p++) {
          var start = parts[p].startMs.v!;
          var end = p + 1 < parts.length
              ? parts[p + 1].startMs.v!
              : lines[l].endMs.v!;
          var expected = _melodyNotes.entries
              .firstWhere((entry) => entry.value == song.melody[l][p].hz)
              .key;
          expect(
            _noteAt(wav, (start + end) ~/ 2),
            expected,
            reason: '${song.baseName} "${parts[p].text.v}" at $start ms',
          );
        }
      }
    }
  });

  test('a sample opens with its tracks', () async {
    var opened = (await const LyricsOpener().openFiles(
      await loadLyricsSampleFiles(_song('frere_jacques')),
    ))!;
    expect(opened.key, 'frere_jacques.lrc');
    expect(opened.format, LyricsFileFormat.lrc);
    expect(opened.tracks.map((track) => track.name), [
      'song',
      'vocals',
      'no_vocals',
    ]);
    expect(opened.document.lyricsOrEmpty.hasPartTiming, isTrue);
    // No path: saving asks where.
    expect(opened.lyricsFile!.path, isNull);
    expect(
      await rootBundle.loadString('$lyricsSamplesAssetDir/twinkle_twinkle.cho'),
      startsWith('{title: Twinkle'),
    );
  });
}
