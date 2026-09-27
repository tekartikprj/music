/// The lyrics file formats the app reads and writes, and what each one
/// loses on save.
library;

import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import 'lyrics_pairing.dart';

/// A lyrics file format.
enum LyricsFileFormat {
  /// The native format, `X.lyrics.json`: everything.
  native('lyrics.json'),

  /// Enhanced LRC: line and syllable times.
  lrc('lrc'),

  /// The lyrics text format / ChordPro: text, syllables, chords, no time.
  text('txt'),

  /// SRT or WebVTT subtitles: read only, saved as LRC.
  subtitles('srt');

  /// The extension written.
  final String extension;

  const LyricsFileFormat(this.extension);

  /// True when the app can write it.
  bool get writable => this != subtitles;
}

/// The format of the file [name], null when it is not a lyrics file.
LyricsFileFormat? lyricsFileFormatOf(String name) {
  var parsed = LyricsFileName.parse(name);
  if (parsed.kind != LyricsFileKind.lyrics) {
    return null;
  }
  return switch (parsed.extension) {
    'lyrics.json' => LyricsFileFormat.native,
    'lrc' => LyricsFileFormat.lrc,
    'srt' || 'vtt' => LyricsFileFormat.subtitles,
    // Lyricsfile comes later: read as text until then.
    _ => LyricsFileFormat.text,
  };
}

/// Read the lyrics file [name] of [content] as a document.
CvLyricsDocument readLyricsDocument(String name, String content) {
  initTekalyLyricsBuilders();
  if (lyricsFileFormatOf(name) == LyricsFileFormat.native) {
    return parseLyricsDocumentJson(content);
  }
  var imported = importLyrics(content, fileName: name);
  return CvLyricsDocument.of(
    imported.lyrics,
    title: imported.title,
    artist: imported.artist,
    source: name,
  );
}

/// [document] written in [format] (not [LyricsFileFormat.subtitles]).
String writeLyricsDocument(CvLyricsDocument document, LyricsFileFormat format) {
  var lyrics = document.lyricsOrEmpty;
  switch (format) {
    case LyricsFileFormat.native:
      return document.toJsonText();
    case LyricsFileFormat.lrc:
      return formatLrcLyrics(
        lyrics,
        title: document.title.v,
        artist: document.artist.v,
      );
    case LyricsFileFormat.text:
      var sb = StringBuffer();
      var title = document.title.v;
      var artist = document.artist.v;
      if (title != null) {
        sb.writeln('{title: $title}');
      }
      if (artist != null) {
        sb.writeln('{artist: $artist}');
      }
      sb.write(formatLyricsText(lyrics));
      return sb.toString();
    case LyricsFileFormat.subtitles:
      throw UnsupportedError('subtitles are read only');
  }
}

/// What [document] loses when saved in [format], for the notice shown once.
List<String> lyricsFormatLosses(
  CvLyricsDocument document,
  LyricsFileFormat format,
) {
  var lyrics = document.lyricsOrEmpty;
  var lines = lyrics.lineList;
  var losses = <String>[];
  switch (format) {
    case LyricsFileFormat.native:
      break;
    case LyricsFileFormat.lrc:
    case LyricsFileFormat.subtitles:
      if (lyrics.hasChords) {
        losses.add('the chords');
      }
      if (lines.any((line) => line.section.v != null)) {
        losses.add('the sections');
      }
      if (lines.any((line) => line.pageMs.v != null)) {
        losses.add('the page times');
      }
      if (lyrics.offset != 0) {
        losses.add('the offset (applied to the times)');
      }
      if (document.album.v != null) {
        losses.add('the album');
      }
    case LyricsFileFormat.text:
      if (lyrics.isTimed) {
        losses.add('every time');
      }
  }
  var media = document.media.v;
  if (format != LyricsFileFormat.native &&
      media != null &&
      media.kind.v != CvLyricsMediaKind.none) {
    losses.add('the media it goes with');
  }
  return losses;
}

/// The file name [name] with the extension of [format] instead of its own.
String lyricsFileNameIn(String name, LyricsFileFormat format) =>
    '${LyricsFileName.parse(name).base}.${format.extension}';
