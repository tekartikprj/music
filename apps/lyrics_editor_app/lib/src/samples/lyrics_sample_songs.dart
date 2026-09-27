/// The sample songs of the app: traditional songs (public domain), their
/// lyrics and their audio generated from the same notes (a note a
/// syllable over a bass line), so that the times and the sound agree.
///
/// `tool/generate_samples.dart` writes them to `assets/samples/`: the audio
/// generated here as wav, encoded to mp3 (128 kbps mono) by ffmpeg.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:tekaly_lyrics_core/lyrics_core.dart';

/// How a sample song is timed.
enum LyricsSampleTiming {
  /// Every syllable (enhanced LRC).
  syllable,

  /// Every line (LRC).
  line,

  /// Not timed (ChordPro text, with chords).
  none,
}

/// A note of a melody: its frequency (0 for a rest) and its length in beats.
typedef LyricsSampleNote = ({double hz, double beats});

// The notes, octave 4 for the melody.
const _c4 = 261.63;
const _d4 = 293.66;
const _e4 = 329.63;
const _f4 = 349.23;
const _g4 = 392.00;
const _a4 = 440.00;
const _g3 = 196.00;

/// The bass note of a chord (low, under the melody).
const _chordRootHz = {
  'C': 130.81,
  'D': 146.83,
  'E': 164.81,
  'F': 174.61,
  'G': 98.00,
  'A': 110.00,
  'B': 123.47,
};

LyricsSampleNote _n(double hz, [double beats = 1]) => (hz: hz, beats: beats);

/// The sample rate of the generated audio (MPEG-1 for the mp3, which every
/// player reads).
const lyricsSampleRate = 44100;

/// The bit rate of the sample mp3 files.
const lyricsSampleMp3Bitrate = '128k';

/// A sample song.
class LyricsSampleSong {
  /// The file base name (`frere_jacques`).
  final String baseName;

  /// The title.
  final String title;

  /// The artist.
  final String artist;

  /// What the sample shows, for the samples list.
  final String description;

  /// How its lyrics file is timed.
  final LyricsSampleTiming timing;

  /// Also write the `-vocals` and `-no_vocals` tracks.
  final bool tracks;

  /// The tempo.
  final int bpm;

  /// The beats before the first line and after the last one.
  final int introBeats;

  /// The beats after the last line.
  final int outroBeats;

  /// The lyrics, in the lyrics text format (`|` between syllables, `[C]`
  /// chords, a blank line for a new page).
  final String text;

  /// The melody, a list of notes per non blank line of [text], one note a
  /// syllable.
  final List<List<LyricsSampleNote>> melody;

  /// A sample song.
  const LyricsSampleSong({
    required this.baseName,
    required this.title,
    required this.artist,
    required this.description,
    required this.timing,
    this.tracks = false,
    this.bpm = 120,
    this.introBeats = 8,
    this.outroBeats = 4,
    required this.text,
    required this.melody,
  });

  /// The length of a beat.
  int get beatMs => 60000 ~/ bpm;

  /// The lyrics file name.
  String get lyricsFileName =>
      '$baseName.${timing == LyricsSampleTiming.none ? 'cho' : 'lrc'}';

  /// The audio file names, the one timed first.
  List<String> get audioFileNames => [
    '$baseName.mp3',
    if (tracks) ...['$baseName-vocals.mp3', '$baseName-no_vocals.mp3'],
  ];

  /// Every file of the sample.
  List<String> get fileNames => [lyricsFileName, ...audioFileNames];

  /// The lyrics, fully timed (every syllable, every line end), whatever
  /// [timing] says.
  CvLyrics timedLyrics() {
    initTekalyLyricsBuilders();
    var lyrics = parseLyricsText(text).lyrics;
    var lines = lyrics.lineList;
    if (lines.length != melody.length) {
      throw StateError('$baseName: ${lines.length} lines, ${melody.length}');
    }
    var t = introBeats * beatMs;
    for (var l = 0; l < lines.length; l++) {
      var line = lines[l];
      var parts = line.partList;
      var notes = melody[l];
      if (parts.length != notes.length) {
        throw StateError(
          '$baseName line ${l + 1}: ${parts.length} syllables, '
          '${notes.length} notes',
        );
      }
      line.startMs.v = t;
      for (var p = 0; p < parts.length; p++) {
        parts[p].startMs.v = t;
        t += (notes[p].beats * beatMs).round();
      }
      line.endMs.v = t;
    }
    return lyrics;
  }

  /// The length of the audio.
  int get durationMs {
    var beats = (introBeats + outroBeats).toDouble();
    for (var notes in melody) {
      for (var note in notes) {
        beats += note.beats;
      }
    }
    return (beats * beatMs).round();
  }

  /// The lyrics file content.
  String lyricsFileContent() {
    var timed = timedLyrics();
    switch (timing) {
      case LyricsSampleTiming.syllable:
        return formatLrcLyrics(timed, title: title, artist: artist);
      case LyricsSampleTiming.line:
        for (var line in timed.lineList) {
          line.endMs.v = null;
          for (var part in line.partList) {
            part.startMs.v = null;
          }
        }
        return formatLrcLyrics(timed, title: title, artist: artist);
      case LyricsSampleTiming.none:
        return '{title: $title}\n{artist: $artist}\n$text\n';
    }
  }

  /// The melody notes, timed.
  List<_Tone> _melodyTones() {
    var tones = <_Tone>[];
    var t = introBeats * beatMs;
    for (var notes in melody) {
      for (var note in notes) {
        var ms = (note.beats * beatMs).round();
        if (note.hz > 0) {
          tones.add(_Tone(t, ms, note.hz, 0.55, melody: true));
        }
        t += ms;
      }
    }
    return tones;
  }

  /// The bass: a pulse a beat on the root of the chord playing.
  List<_Tone> _bassTones() {
    var changes = <(int, String)>[];
    for (var line in timedLyrics().lineList) {
      for (var part in line.partList) {
        var chord = part.chord.v;
        if (chord != null && chord.isNotEmpty) {
          changes.add((part.startMs.v!, chord.substring(0, 1)));
        }
      }
    }
    var tones = <_Tone>[];
    var beats = durationMs ~/ beatMs;
    for (var b = 0; b < beats; b++) {
      var t = b * beatMs;
      var root = changes.isEmpty ? 'C' : changes.first.$2;
      for (var (at, chord) in changes) {
        if (at <= t) {
          root = chord;
        }
      }
      tones.add(
        _Tone(t, (beatMs * 0.8).round(), _chordRootHz[root] ?? 130.81, 0.4),
      );
    }
    return tones;
  }

  /// The audio of the file [name] (one of [audioFileNames]) as wav, what
  /// the mp3 is encoded from.
  Uint8List audioWavContent(String name) {
    var withMelody = !name.endsWith('-no_vocals.mp3');
    var withBass = !name.endsWith('-vocals.mp3');
    return _wav([
      if (withMelody) ..._melodyTones(),
      if (withBass) ..._bassTones(),
    ], durationMs);
  }

  /// The content of the lyrics file.
  Uint8List lyricsFileBytes() =>
      Uint8List.fromList(utf8.encode(lyricsFileContent()));
}

/// A tone of the generated audio.
class _Tone {
  final int startMs;
  final int ms;
  final double hz;
  final double volume;

  /// A sung note (sustained) rather than a bass pulse (decaying).
  final bool melody;

  _Tone(this.startMs, this.ms, this.hz, this.volume, {this.melody = false});
}

/// A mono 16-bit PCM wav file of [tones] mixed, [durationMs] long.
Uint8List _wav(List<_Tone> tones, int durationMs) {
  const rate = lyricsSampleRate;
  var count = rate * durationMs ~/ 1000;
  var mix = Float64List(count);
  for (var tone in tones) {
    var start = rate * tone.startMs ~/ 1000;
    var length = rate * tone.ms ~/ 1000;
    var attack = rate * 0.015;
    var release = rate * (tone.melody ? 0.04 : 0.02);
    for (var i = 0; i < length && start + i < count; i++) {
      var envelope = min(1.0, min(i / attack, (length - i) / release));
      if (!tone.melody) {
        // A plucked bass: it fades along.
        envelope *= exp(-3.0 * i / length);
      }
      var phase = 2 * pi * tone.hz * i / rate;
      var value = sin(phase) + (tone.melody ? 0.25 * sin(2 * phase) : 0);
      mix[start + i] += value * envelope * tone.volume;
    }
  }
  var dataSize = count * 2;
  var bytes = ByteData(44 + dataSize);
  void writeString(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // pcm
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  writeString(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < count; i++) {
    var sample = mix[i].clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (sample * 30000).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// The sample songs.
final lyricsSampleSongs = [
  LyricsSampleSong(
    baseName: 'frere_jacques',
    title: 'Frère Jacques',
    artist: 'Traditional',
    description:
        'Timed to the syllable, three tracks (song, vocals, no vocals)',
    timing: LyricsSampleTiming.syllable,
    tracks: true,
    text: '''
[C]Frè|re Jac|ques,
frè|re Jac|ques,

Dor|mez-|vous?
Dor|mez-|vous?

Son|nez les ma|ti|nes,
son|nez les ma|ti|nes,

Ding, dang, dong.
Ding, dang, dong.''',
    melody: [
      for (var i = 0; i < 2; i++) [_n(_c4), _n(_d4), _n(_e4), _n(_c4)],
      for (var i = 0; i < 2; i++) [_n(_e4), _n(_f4), _n(_g4, 2)],
      for (var i = 0; i < 2; i++)
        [
          _n(_g4, 0.5),
          _n(_a4, 0.5),
          _n(_g4, 0.5),
          _n(_f4, 0.5),
          _n(_e4),
          _n(_c4),
        ],
      for (var i = 0; i < 2; i++) [_n(_c4), _n(_g3), _n(_c4, 2)],
    ],
  ),
  LyricsSampleSong(
    baseName: 'au_clair_de_la_lune',
    title: 'Au clair de la lune',
    artist: 'Traditional',
    description: 'Timed to the line: time its syllables',
    timing: LyricsSampleTiming.line,
    text: '''
[C]Au clair de la lu|[G]ne,
[C]mon a|[G]mi Pier|[C]rot,

[C]Prê|te-|moi ta plu|[G]me
[C]pour é|[G]crire un [C]mot.''',
    melody: [
      for (var i = 0; i < 2; i++) ...[
        [_n(_c4), _n(_c4), _n(_c4), _n(_d4), _n(_e4, 2), _n(_d4, 2)],
        [_n(_c4), _n(_e4), _n(_d4), _n(_d4), _n(_c4, 4)],
      ],
    ],
  ),
  LyricsSampleSong(
    baseName: 'twinkle_twinkle',
    title: 'Twinkle, Twinkle, Little Star',
    artist: 'Traditional',
    description: 'Not timed, with chords: time it from scratch',
    timing: LyricsSampleTiming.none,
    text: '''
[C]Twin|kle, twin|kle, [F]lit|tle [C]star,
[F]How I [C]won|der [G]what you [C]are!

[C]Up a|[F]bove the [C]world so [G]high,
[C]Like a [F]dia|mond [C]in the [G]sky.

[C]Twin|kle, twin|kle, [F]lit|tle [C]star,
[F]How I [C]won|der [G]what you [C]are!''',
    melody: [
      for (var i = 0; i < 3; i++) ...[
        if (i == 1) ...[
          for (var j = 0; j < 2; j++)
            [_n(_g4), _n(_g4), _n(_f4), _n(_f4), _n(_e4), _n(_e4), _n(_d4, 2)],
        ] else ...[
          [_n(_c4), _n(_c4), _n(_g4), _n(_g4), _n(_a4), _n(_a4), _n(_g4, 2)],
          [_n(_f4), _n(_f4), _n(_e4), _n(_e4), _n(_d4), _n(_d4), _n(_c4, 2)],
        ],
      ],
    ],
  ),
];
