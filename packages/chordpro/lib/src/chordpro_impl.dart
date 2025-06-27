import 'dart:convert';

import 'package:tekaly_music_note/music_note.dart';

/// Text convert helpers
String textToChordPro(String text) {
  return textLinesToChordProLines(LineSplitter.split(text).toList()).join('\n');
}

bool _isChordLine(String line) {
  var elements = line
      .split(' ')
      .map((e) => e.trim())
      .where((element) => element.isNotEmpty);
  var chords = elements
      .map((element) => tryParseChord(element))
      .nonNulls
      .toList();
  if (chords.isNotEmpty) {
    if (elements.length >= 2) {
      // At least 50M
      return chords.length >= elements.length / 2;
    }
    return true;
  }
  return false;
}

String _chordLineToChordProLine(String line) {
  var sb = StringBuffer();
  sb.write(line.split(' ').map((e) => e.isEmpty ? '' : '[$e]').join(' '));
  return sb.toString();
}

/// Convert text lines to chordpro lines
List<String> textLinesToChordProLines(List<String> lines) {
  var result = <String>[];
  String? sectionType;

  void terminateSection() {
    if (sectionType != null) {
      result.add('{end_of_$sectionType}');
      sectionType = null;
    }
  }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trimRight();
    late String lyric;
    if (_isChordLine(line)) {
      var noLyrics = false;
      if (i < lines.length - 1) {
        lyric = lines[i + 1].trimRight();
        if (_isChordLine(lyric)) {
          noLyrics = true;
        }
      } else {
        noLyrics = true;
      }
      if (noLyrics) {
        var sb = StringBuffer();
        sb.write(_chordLineToChordProLine(line));
        if (sb.isNotEmpty) {
          result.add(sb.toString());
        }
      } else {
        // Skip
        i++;
        var sb = StringBuffer();
        var chordIndex = 0;
        var lyricIndex = 0;
        var chordStarted = false;
        while (true) {
          if (chordIndex < line.length) {
            var char = line[chordIndex++];
            if (char == ' ') {
              if (chordStarted) {
                chordStarted = false;
                sb.write(']');
              }
              while (lyricIndex < chordIndex) {
                if (lyricIndex < lyric.length) {
                  var lyricChar = lyric[lyricIndex++];
                  sb.write(lyricChar);
                } else {
                  sb.write(' ');
                  break;
                }
              }
            } else {
              if (!chordStarted) {
                chordStarted = true;
                sb.write('[');
              }
              sb.write(char);
            }
          } else {
            if (chordStarted) {
              chordStarted = false;
              sb.write(']');
            }
            if (lyricIndex < lyric.length) {
              sb.write(lyric.substring(lyricIndex));
            }
            break;
          }
        }
        if (sb.isNotEmpty) {
          result.add(sb.toString());
        }
      }
    } else if (line.startsWith('[')) {
      terminateSection();
      var end = line.indexOf(']');
      if (end != -1) {
        var sectionName = line.substring(1, end);
        var type = sectionName.split(' ').first.toLowerCase();
        if (type == 'verse' || type == 'chorus' || type == 'bridge') {
          sectionType = type;
        } else {
          sectionType = 'bridge';
        }
        result.add('{start_of_$sectionType: $sectionName}');
      }
    } else {
      terminateSection();
      result.add(line);
    }
  }
  terminateSection();
  return result;
}
