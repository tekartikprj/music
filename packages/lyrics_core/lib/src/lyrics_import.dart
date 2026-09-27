/// Import lyrics from any supported format, detected from the file name or
/// the content.
library;

import 'lyrics_lrc.dart';
import 'lyrics_subtitles.dart';
import 'lyrics_text.dart';

/// The lyrics file formats.
enum LyricsFormat {
  /// Plain text, the lyrics text format, ChordPro, chords over lyrics.
  text,

  /// LRC, enhanced LRC.
  lrc,

  /// SRT or WebVTT subtitles.
  subtitles,
}

final _lrcLineRegExp = RegExp(
  r'^\s*\[\d{1,3}:\d{1,2}(?:[.,]\d{1,3})?\]',
  multiLine: true,
);
final _cueRegExp = RegExp(r'^\s*[0-9:.,]+\s*-->\s*[0-9:.,]+', multiLine: true);

/// The format of [content], from the [fileName] extension when known, the
/// content otherwise.
LyricsFormat detectLyricsFormat(String content, {String? fileName}) {
  var name = fileName?.toLowerCase();
  if (name != null) {
    if (name.endsWith('.lrc')) {
      return LyricsFormat.lrc;
    }
    if (name.endsWith('.srt') || name.endsWith('.vtt')) {
      return LyricsFormat.subtitles;
    }
    for (var extension in ['.cho', '.chopro', '.chordpro', '.crd', '.pro']) {
      if (name.endsWith(extension)) {
        return LyricsFormat.text;
      }
    }
  }
  if (content.trimLeft().startsWith('WEBVTT') || _cueRegExp.hasMatch(content)) {
    return LyricsFormat.subtitles;
  }
  if (_lrcLineRegExp.hasMatch(content)) {
    return LyricsFormat.lrc;
  }
  return LyricsFormat.text;
}

/// Import [content] ([format] detected when not given).
LyricsImport importLyrics(
  String content, {
  String? fileName,
  LyricsFormat? format,
}) {
  format ??= detectLyricsFormat(content, fileName: fileName);
  return switch (format) {
    LyricsFormat.lrc => parseLrcLyrics(content),
    LyricsFormat.subtitles => parseSubtitleLyrics(content),
    LyricsFormat.text => parseLyricsText(content),
  };
}
