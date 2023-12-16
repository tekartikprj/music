import 'package:tekaly_music_note/music_note.dart';

String textToChordPro(String text) {
  var lines = text.split('\n');
  var result = <String>[];
  for (var line in lines) {
    var trimmedLine = line.trim();
    if (trimmedLine.isEmpty) {
      result.add('');
    } else {
      var chordIndex = trimmedLine.indexOf(' ');
      if (chordIndex == -1) {
        result.add(trimmedLine);
      } else {
        var chord = trimmedLine.substring(0, chordIndex);
        var lyrics = trimmedLine.substring(chordIndex + 1);
        result.add('$chord[$lyrics]');
      }
    }
  }
  return result.join('\n');
}

bool _isChordLine(String line) {
  var elements = line
      .split(' ')
      .map((e) => e.trim())
      .where((element) => element.isNotEmpty);
  var chords =
      elements.map((element) => tryParseChord(element)).nonNulls.toList();
  if (chords.isNotEmpty) {
    if (elements.length >= 2) {
      // At least 50M
      return chords.length >= elements.length / 2;
    }
    return true;
  }
  return false;
}

List<String> textLinesToChordProLines(List<String> lines) {
  var result = <String>[];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trimRight();
    if (i < lines.length - 1 && _isChordLine(line)) {
      var lyric = lines[i + 1].trimRight();
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
  }
  return result;
}
