import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekaly_lyrics/src/lyrics_data_player.dart';
import 'package:tekartik_midi/midi.dart';
import 'package:tekartik_midi/midi_file_player.dart';
import 'package:test/test.dart';

class _Player extends LyricsDataPlayerBase {
  final texts = <String>[];
  var endOfTrackCount = 0;

  @override
  void onPlayEvent(PlayableEvent event) {
    if (event.midiEvent is EndOfTrackEvent) {
      endOfTrackCount++;
    }
    super.onPlayEvent(event);
  }

  @override
  void onPlayText(String text) => texts.add(text);
}

void main() {
  test('lyrics data player', () async {
    var data = parseLyricLrc(
      '[00:00.00]One\n[00:00.10]Two<00:00.20>Three\n[00:00.30]Four',
    );
    var player = _Player();
    player.load(data);
    player.resume();
    await player.done.timeout(const Duration(seconds: 5));
    expect(player.texts.where((text) => text != '\n'), [
      'One',
      'Two',
      'Three',
      'Four',
    ]);
    expect(player.endOfTrackCount, 1);
  });
}
