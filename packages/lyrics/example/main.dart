// ignore_for_file: avoid_print

import 'package:tekaly_lyrics/utils/duration_helper.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

/// Word timed lyrics, the last line sung twice.
const lrc = '''
[ti:Demo]
[ar:Me]
[00:01.00]<00:01.00>Hello <00:02.00>my <00:03.00>friend<00:04.00>
[00:05.00][00:09.00]Time to go
''';

/// Parses LRC lyrics, prints them, then the word sung at a few positions
/// as a karaoke highlight would.
void main() {
  var lyrics = parseLyricLrc(lrc);
  print('${lyrics.title} - ${lyrics.artist}');
  for (var line in lyrics.lines) {
    var words = line.parts.map((part) => '"${part.text}"').join(' ');
    print('${lrcFormatDuration(line.time)} ${line.text} ($words)');
  }

  var located = LocatedLyricsData(lyricsData: lyrics);
  for (var position in [500.ms, 1.s, 2500.ms, 4.s, 6.s, 10.s]) {
    var info = located.locateItemInfo(position);
    if (info.ref.lineIndex < 0) {
      print('${lrcFormatDuration(position)}: not started');
      continue;
    }
    var text = located.getLine(info.ref.lineIndex).text;
    // The part sung so far in brackets.
    print(
      '${lrcFormatDuration(position)}: '
      '[${text.substring(0, info.end)}]${text.substring(info.end)}',
    );
  }

  // Written back as LRC (tags not included).
  print(lyrics.toLrcLines().join('\n'));
}
