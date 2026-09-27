/// The lyrics model: lines made of parts (syllables), each one optionally
/// timed, every time an `int` of milliseconds of the media's own timeline
/// (the *media time*: it depends neither on the playback speed nor on the
/// clips played).
///
/// Untimed lyrics are songbook text, timed ones are karaoke: the same model
/// is progressively enriched, page times first or syllables right away.
library;

import 'package:cv/cv.dart';

import 'lyrics_document.dart';

/// One part of a lyrics line: a syllable, a word, or an empty part holding
/// only a chord. The unit a karaoke wipe advances by.
class CvLyricsPart extends CvModelBase {
  /// The text, without separator (no trailing space, no `|`).
  final text = CvField<String>('text');

  /// When the part starts being sung, null when untimed.
  final startMs = CvField<int>('startMs');

  /// When the part stops being sung, null for the start of the next part
  /// (or the end of the line). Set in the hold mode of the timing editor.
  final endMs = CvField<int>('endMs');

  /// True when no space follows: the part and the next one are syllables of
  /// the same word (`ê` + `tre` shows as `être`).
  final join = CvField<bool>('join');

  /// The chord starting on this part, if any (`C`, `Am7`, `F#m/C#`).
  final chord = CvField<String>('chord');

  @override
  CvFields get fields => [text, startMs, endMs, join, chord];

  /// A part.
  CvLyricsPart();

  /// A part with its values.
  factory CvLyricsPart.of(
    String text, {
    int? startMs,
    int? endMs,
    bool join = false,
    String? chord,
  }) => CvLyricsPart()
    ..text.v = text
    ..startMs.v = startMs
    ..endMs.v = endMs
    ..join.v = join ? true : null
    ..chord.v = chord;
}

/// One line of lyrics.
class CvLyricsLine extends CvModelBase {
  /// The parts, in singing order.
  final parts = CvModelListField<CvLyricsPart>('parts');

  /// When the line starts, null when untimed. The effective start is the one
  /// of the first timed part when this one is null.
  final startMs = CvField<int>('startMs');

  /// When the line stops being sung, null to derive it (last part end, next
  /// line start). Needed to skip the instrumental gap that follows.
  final endMs = CvField<int>('endMs');

  /// True when this line starts a new page (the first line always does).
  final newPage = CvField<bool>('newPage');

  /// Explicit page change time, only meaningful on a [newPage] line: when the
  /// page this line starts is shown (default: before the line, see
  /// `LyricsTimeline`).
  final pageMs = CvField<int>('pageMs');

  /// Optional section label (`verse`, `chorus`), used by the songbook
  /// display and to group the chords.
  final section = CvField<String>('section');

  @override
  CvFields get fields => [parts, startMs, endMs, newPage, pageMs, section];

  /// A line.
  CvLyricsLine();

  /// A line with its values.
  factory CvLyricsLine.of(
    List<CvLyricsPart> parts, {
    int? startMs,
    int? endMs,
    bool newPage = false,
    int? pageMs,
    String? section,
  }) => CvLyricsLine()
    ..parts.v = parts
    ..startMs.v = startMs
    ..endMs.v = endMs
    ..newPage.v = newPage ? true : null
    ..pageMs.v = pageMs
    ..section.v = section;
}

/// The lyrics of a song.
class CvLyrics extends CvModelBase {
  /// The lines, in singing order.
  final lines = CvModelListField<CvLyricsLine>('lines');

  /// Added to every time, to reuse a timing on another recording of the same
  /// song (a longer intro: a positive offset).
  final offsetMs = CvField<int>('offsetMs');

  /// Language code (`fr`, `en`), used to split syllables later on.
  final language = CvField<String>('language');

  @override
  CvFields get fields => [lines, offsetMs, language];

  /// Lyrics.
  CvLyrics();

  /// Lyrics with their lines.
  factory CvLyrics.of(
    List<CvLyricsLine> lines, {
    int? offsetMs,
    String? language,
  }) => CvLyrics()
    ..lines.v = lines
    ..offsetMs.v = offsetMs
    ..language.v = language;
}

var _buildersInitialized = false;

/// Register the lyrics model builders (idempotent).
void initTekalyLyricsBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  cvAddConstructors([
    CvLyrics.new,
    CvLyricsLine.new,
    CvLyricsPart.new,
    CvLyricsDocument.new,
    CvLyricsMedia.new,
    CvLyricsTrack.new,
  ]);
}

/// Part helpers.
extension CvLyricsPartExt on CvLyricsPart {
  /// The text, empty when null.
  String get textOrEmpty => text.v ?? '';

  /// True when no space follows.
  bool get isJoined => join.v ?? false;

  /// True when the part has an explicit start.
  bool get isTimed => startMs.v != null;
}

/// Line helpers.
extension CvLyricsLineExt on CvLyricsLine {
  /// The parts, empty when null.
  List<CvLyricsPart> get partList => parts.v ?? const <CvLyricsPart>[];

  /// True when this line explicitly starts a page.
  bool get isNewPage => newPage.v ?? false;

  /// The text shown: the parts, a space after each one unless joined.
  String get text {
    var sb = StringBuffer();
    var list = partList;
    for (var i = 0; i < list.length; i++) {
      var part = list[i];
      sb.write(part.textOrEmpty);
      if (i < list.length - 1 && !part.isJoined) {
        sb.write(' ');
      }
    }
    return sb.toString().trim();
  }

  /// True when the line or one of its parts has a time.
  bool get isTimed => startMs.v != null || partList.any((part) => part.isTimed);

  /// True when at least one part (other than the first) has its own start:
  /// the line is timed to the syllable (or the word).
  bool get hasPartTiming => partList.skip(1).any((part) => part.isTimed);

  /// True when a part carries a chord.
  bool get hasChords => partList.any((part) => part.chord.v != null);
}

/// Lyrics helpers.
extension CvLyricsExt on CvLyrics {
  /// The lines, empty when null.
  List<CvLyricsLine> get lineList => lines.v ?? const <CvLyricsLine>[];

  /// The offset, 0 when null.
  int get offset => offsetMs.v ?? 0;

  /// True when there are no lines at all.
  bool get isEmpty => lineList.isEmpty;

  /// The text shown, one line per lyrics line.
  String get text => lineList.map((line) => line.text).join('\n');

  /// True when at least one line is timed: karaoke rather than songbook.
  bool get isTimed => lineList.any((line) => line.isTimed);

  /// True when at least one line is timed to the syllable.
  bool get hasPartTiming => lineList.any((line) => line.hasPartTiming);

  /// True when at least one part carries a chord.
  bool get hasChords => lineList.any((line) => line.hasChords);

  /// A deep copy.
  CvLyrics copy() {
    initTekalyLyricsBuilders();
    return clone();
  }

  /// Every time shifted by [deltaMs] (lines from [fromLine] on only when
  /// given); a time ending up negative becomes 0.
  void shiftTimes(int deltaMs, {int fromLine = 0}) {
    int? shift(int? ms) => ms == null ? null : (ms + deltaMs).clamp(0, 1 << 40);
    var list = lineList;
    for (var i = fromLine; i < list.length; i++) {
      var line = list[i];
      line
        ..startMs.v = shift(line.startMs.v)
        ..endMs.v = shift(line.endMs.v)
        ..pageMs.v = shift(line.pageMs.v);
      for (var part in line.partList) {
        part
          ..startMs.v = shift(part.startMs.v)
          ..endMs.v = shift(part.endMs.v);
      }
    }
  }

  /// Remove every time (lines from [fromLine] on only when given), the text,
  /// the pages and the chords are kept.
  void clearTimes({int fromLine = 0}) {
    var list = lineList;
    for (var i = fromLine; i < list.length; i++) {
      var line = list[i];
      line
        ..startMs.v = null
        ..endMs.v = null
        ..pageMs.v = null;
      for (var part in line.partList) {
        part
          ..startMs.v = null
          ..endMs.v = null;
      }
    }
  }
}
