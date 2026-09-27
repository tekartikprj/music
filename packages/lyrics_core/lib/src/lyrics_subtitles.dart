/// SRT and WebVTT subtitles to [CvLyrics]: each cue is a page, each of its
/// text lines a lyrics line timed by the cue (split in proportion of their
/// length when the cue has several), the WebVTT karaoke timestamps
/// (`<00:00:12.500>`) timing the parts.
library;

import 'dart:convert';
import 'dart:math';

import 'lyrics_lrc.dart';
import 'lyrics_model.dart';
import 'lyrics_time.dart';

final _cueTimeRegExp = RegExp(r'^\s*([0-9:.,]+)\s*-->\s*([0-9:.,]+)');
final _styleTagRegExp = RegExp(r'</?(?:[a-zA-Z][^>]*)>');

/// Parse SRT or WebVTT subtitles.
LyricsImport parseSubtitleLyrics(String content) {
  var lines = <CvLyricsLine>[];
  var rawLines = LineSplitter.split(content).toList();
  var r = 0;
  while (r < rawLines.length) {
    var match = _cueTimeRegExp.firstMatch(rawLines[r]);
    if (match == null) {
      r++;
      continue;
    }
    var start = parseLyricsTime(match.group(1)!);
    var end = parseLyricsTime(match.group(2)!);
    r++;
    var texts = <String>[];
    while (r < rawLines.length && rawLines[r].trim().isNotEmpty) {
      if (_cueTimeRegExp.hasMatch(rawLines[r])) {
        break;
      }
      var text = rawLines[r].replaceAll(_styleTagRegExp, '').trim();
      if (text.isNotEmpty) {
        texts.add(text);
      }
      r++;
    }
    if (start == null || texts.isEmpty) {
      continue;
    }
    var cueEnd = end != null && end > start ? end : null;
    var total = texts.fold<int>(0, (sum, text) => sum + max(1, text.length));
    var acc = 0;
    for (var t = 0; t < texts.length; t++) {
      var parsed = parseInlineTimedParts(texts[t]);
      if (parsed.parts.isEmpty) {
        continue;
      }
      var lineStart = start;
      var lineEnd = cueEnd;
      if (texts.length > 1 && cueEnd != null) {
        lineStart = start + ((cueEnd - start) * acc) ~/ total;
        acc += max(1, texts[t].length);
        lineEnd = start + ((cueEnd - start) * acc) ~/ total;
      }
      lines.add(
        CvLyricsLine.of(
          parsed.parts,
          startMs: lineStart,
          endMs: parsed.endMs ?? lineEnd,
          newPage: t == 0 && lines.isNotEmpty,
        ),
      );
    }
  }
  return LyricsImport(lyrics: CvLyrics.of(lines));
}
