/// LRC and enhanced LRC (a time per word or syllable) to and from
/// [CvLyrics].
///
/// ```text
/// [ti:Il en faut peu]
/// [00:40.388]<00:40.388>Il <00:40.808>en <00:40.988>faut <00:41.508>ê-<00:42.508>tre
/// [00:43.188]Vrai-ment très peu<00:45.000>
/// [00:46.000]
/// ```
///
/// - a line may carry several times (`[00:12.00][00:45.00]refrain`), it is
///   then repeated;
/// - `<time>` tags time the parts; no space between two parts means they are
///   syllables of the same word ([CvLyricsPart.join]), the text itself (a
///   karaoke hyphen included) is kept as is;
/// - an empty `<time>` at the end of a line is the line end, in the middle
///   the end of the part before it;
/// - an empty timed line (`[00:46.000]`) ends the line before it;
/// - an empty untimed line starts a new page;
/// - `[offset:+100]` (lyrics 100 ms sooner) becomes [CvLyrics.offsetMs]
///   `-100`.
library;

import 'dart:convert';

import 'lyrics_model.dart';
import 'lyrics_time.dart';

/// The result of an import: the lyrics and what the file said about itself.
class LyricsImport {
  /// The lyrics.
  final CvLyrics lyrics;

  /// The title, when the file had one.
  final String? title;

  /// The artist, when the file had one.
  final String? artist;

  /// The result of an import.
  const LyricsImport({required this.lyrics, this.title, this.artist});
}

final _inlineTimeRegExp = RegExp(r'<([0-9:.,]+)>');
final _endsWithSpaceRegExp = RegExp(r'\s$');

/// Parse the content of a line (after its `[time]` tags) into parts, the
/// inline `<time>` tags timing them.
///
/// Returns the parts and the line end (an empty trailing tag).
({List<CvLyricsPart> parts, int? endMs}) parseInlineTimedParts(String text) {
  // Segments: the text before the first tag has no time.
  var segments = <({int? time, String text})>[];
  var index = 0;
  int? time;
  for (var match in _inlineTimeRegExp.allMatches(text)) {
    var parsed = parseLyricsTime(match.group(1)!);
    if (parsed == null) {
      continue;
    }
    segments.add((time: time, text: text.substring(index, match.start)));
    time = parsed;
    index = match.end;
  }
  segments.add((time: time, text: text.substring(index)));

  var parts = <CvLyricsPart>[];
  int? endMs;
  for (var s = 0; s < segments.length; s++) {
    var segment = segments[s];
    var raw = segment.text;
    if (raw.trim().isEmpty) {
      if (segment.time == null) {
        continue;
      }
      // A tag followed by nothing: the end of what came before.
      if (s == segments.length - 1) {
        endMs = segment.time;
      } else if (parts.isNotEmpty) {
        parts.last.endMs.v ??= segment.time;
      }
      if (raw.isNotEmpty && parts.isNotEmpty) {
        parts.last.join.v = null;
      }
      continue;
    }
    // A space before the text ends the previous word.
    if (raw.startsWith(RegExp(r'\s')) && parts.isNotEmpty) {
      parts.last.join.v = null;
    }
    var words = raw.trim().split(RegExp(r'\s+'));
    for (var w = 0; w < words.length; w++) {
      var part = CvLyricsPart.of(
        words[w],
        startMs: w == 0 ? segment.time : null,
      );
      var last = w == words.length - 1;
      if (last && !_endsWithSpaceRegExp.hasMatch(raw)) {
        // Joined to the next segment, unless it starts with a space.
        part.join.v = true;
      }
      parts.add(part);
    }
  }
  if (parts.isNotEmpty) {
    parts.last.join.v = null;
  }
  return (parts: parts, endMs: endMs);
}

/// Parse an LRC (or enhanced LRC) file.
LyricsImport parseLrcLyrics(String content) {
  String? title;
  String? artist;
  String? language;
  int? offsetMs;
  var lines = <CvLyricsLine>[];
  var pendingNewPage = false;
  var multipleTimes = false;
  for (var rawLine in LineSplitter.split(content)) {
    var line = rawLine.trim();
    if (line.isEmpty) {
      if (lines.isNotEmpty) {
        pendingNewPage = true;
      }
      continue;
    }
    var times = <int>[];
    var metadata = false;
    while (line.startsWith('[')) {
      var close = line.indexOf(']');
      if (close < 0) {
        break;
      }
      var tag = line.substring(1, close);
      var time = parseLyricsTime(tag);
      if (time != null) {
        times.add(time);
        line = line.substring(close + 1);
        continue;
      }
      var colon = tag.indexOf(':');
      if (colon > 0 &&
          RegExp(r'^[a-zA-Z]+$').hasMatch(tag.substring(0, colon))) {
        var key = tag.substring(0, colon).toLowerCase();
        var value = tag.substring(colon + 1).trim();
        switch (key) {
          case 'ti':
            title = value;
          case 'ar':
            artist = value;
          case 'la':
          case 'lang':
            language = value;
          case 'offset':
            var lrcOffset = int.tryParse(value.replaceFirst('+', ''));
            if (lrcOffset != null && lrcOffset != 0) {
              offsetMs = -lrcOffset;
            }
        }
        metadata = true;
        line = line.substring(close + 1);
        continue;
      }
      break;
    }
    if (metadata && times.isEmpty && line.trim().isEmpty) {
      continue;
    }
    var parsed = parseInlineTimedParts(line);
    if (parsed.parts.isEmpty) {
      // An empty timed line: the end of the previous line.
      if (times.isNotEmpty && lines.isNotEmpty) {
        var previous = lines.last;
        var previousStart = previous.startMs.v;
        if (previous.endMs.v == null &&
            (previousStart == null || previousStart < times.first)) {
          previous.endMs.v = times.first;
        }
      }
      continue;
    }
    if (times.isEmpty) {
      lines.add(
        CvLyricsLine.of(
          parsed.parts,
          endMs: parsed.endMs,
          newPage: pendingNewPage,
        ),
      );
    } else {
      if (times.length > 1) {
        multipleTimes = true;
      }
      for (var t = 0; t < times.length; t++) {
        List<CvLyricsPart> parts;
        if (t == 0) {
          parts = parsed.parts;
        } else {
          // Repeated: the inline times belong to the first occurrence.
          parts = parsed.parts
              .map(
                (part) => CvLyricsPart.of(
                  part.textOrEmpty,
                  join: part.isJoined,
                  chord: part.chord.v,
                ),
              )
              .toList();
        }
        lines.add(
          CvLyricsLine.of(
            parts,
            startMs: times[t],
            endMs: t == 0 ? parsed.endMs : null,
            newPage: pendingNewPage,
          ),
        );
      }
    }
    pendingNewPage = false;
  }
  if (multipleTimes) {
    // Stable sort on the start, untimed lines keep their relative place.
    var indexed = lines.indexed.toList()
      ..sort((a, b) {
        var sa = a.$2.startMs.v;
        var sb = b.$2.startMs.v;
        if (sa != null && sb != null && sa != sb) {
          return sa.compareTo(sb);
        }
        return a.$1.compareTo(b.$1);
      });
    lines = indexed.map((entry) => entry.$2).toList();
  }
  return LyricsImport(
    lyrics: CvLyrics.of(lines, offsetMs: offsetMs, language: language),
    title: title,
    artist: artist,
  );
}

String _lrcTime(int ms) {
  if (ms < 0) {
    ms = 0;
  }
  var minutes = ms ~/ 60000;
  var rest = formatLyricsTime(ms % 60000, padMinutes: true);
  // `00:12.345` from the minute-less rest.
  return '${minutes.toString().padLeft(2, '0')}${rest.substring(2)}';
}

/// Format [lyrics] as enhanced LRC, times with milliseconds.
///
/// The offset is applied (no `[offset]` tag), chords and sections are not
/// written, pages become empty lines. A line timed to its parts gets
/// `<time>` tags and its end as a trailing tag; a line timed by its start
/// only gets its end as an empty timed line.
String formatLrcLyrics(CvLyrics lyrics, {String? title, String? artist}) {
  var sb = StringBuffer();
  if (title != null) {
    sb.writeln('[ti:$title]');
  }
  if (artist != null) {
    sb.writeln('[ar:$artist]');
  }
  var language = lyrics.language.v;
  if (language != null) {
    sb.writeln('[la:$language]');
  }
  var offset = lyrics.offset;
  int? off(int? ms) => ms == null ? null : ms + offset;
  var list = lyrics.lineList;
  for (var i = 0; i < list.length; i++) {
    var line = list[i];
    if (i > 0 && line.isNewPage) {
      sb.writeln();
    }
    var parts = line.partList;
    var start = off(line.startMs.v);
    if (start == null) {
      for (var part in parts) {
        if (part.startMs.v != null) {
          start = off(part.startMs.v);
          break;
        }
      }
    }
    if (start != null) {
      sb.write('[${_lrcTime(start)}]');
    }
    var withParts = start != null && parts.any((part) => part.isTimed);
    for (var p = 0; p < parts.length; p++) {
      var part = parts[p];
      var partStart = off(part.startMs.v);
      if (withParts && partStart != null) {
        sb.write('<${_lrcTime(partStart)}>');
      }
      sb.write(part.textOrEmpty);
      var partEnd = off(part.endMs.v);
      if (withParts && partEnd != null && p < parts.length - 1) {
        var next = off(parts[p + 1].startMs.v);
        if (next == null || next > partEnd) {
          sb.write('${part.isJoined ? '' : ' '}<${_lrcTime(partEnd)}>');
          continue;
        }
      }
      if (p < parts.length - 1 && !part.isJoined) {
        sb.write(' ');
      }
    }
    var end = off(line.endMs.v);
    if (end == null && withParts && parts.isNotEmpty) {
      end = off(parts.last.endMs.v);
    }
    if (withParts && end != null) {
      sb.write('<${_lrcTime(end)}>');
    }
    sb.writeln();
    if (!withParts && start != null && end != null) {
      sb.writeln('[${_lrcTime(end)}]');
    }
  }
  return sb.toString();
}
