import 'package:tekaly_lyrics/lyrics.dart';
import 'package:tekartik_midi/midi.dart';
import 'package:tekartik_midi/midi_file_player.dart';
import 'package:tekartik_midi/midi_player_base.dart';

/// Player
abstract class LyricsDataPlayer {}

class _LyricsMidiPlayer extends MidiPlayerBase {
  LyricsData? _lyricsData;
  void Function(PlayableEvent event)? playEventCallback;

  _LyricsMidiPlayer({LyricsData? lyricsData, this.playEventCallback})
    : super(null) {
    if (lyricsData != null) {
      loadLyricsData(lyricsData);
    }
  }

  void loadLyricsData(LyricsData lyricsData) {
    _lyricsData = lyricsData;

    final file = MidiFile();

    var track = MidiTrack();

    var timeUnitPerMs = 1 / midiDeltaTimeUnitToMillis();

    int durationAbsoluteMs(Duration duration) {
      return (duration.inMilliseconds * timeUnitPerMs).toInt();
    }

    for (var line in _lyricsData!.lines) {
      var content = line.content;
      var lineTime = line.time;
      track.addAbsolutionEvent(
        durationAbsoluteMs(lineTime),
        MetaTextEvent.text('\n'),
      );
      if (content is LyricsLineSingleContent) {
        var time = content.time;
        var text = content.part.text;
        track.addAbsolutionEvent(
          durationAbsoluteMs(time),
          MetaTextEvent.text(text),
        );
      } else if (content is LyricsLineMultiContent) {
        var parts = content.parts;
        for (var part in parts) {
          var time = part.time;
          var text = part.text;
          track.addAbsolutionEvent(
            durationAbsoluteMs(time),
            MetaTextEvent.text(text),
          );
        }
      } else {
        throw 'Unknown content type ${content.runtimeType}';
      }
      track.addEvent(0, EndOfTrackEvent());
    }
    file.addTrack(track);
    load(file);
  }

  @override
  void rawPlayEvent(PlayableEvent event) {
    // ignore: avoid_print
    //print(event);
    playEventCallback?.call(event);
  }

  Stopwatch? stopwatch;

  @override
  num get now {
    // make the first call 0
    if (stopwatch == null) {
      stopwatch = Stopwatch();
      stopwatch!.start();
    }
    return stopwatch!.elapsed.inMilliseconds;
  }
}

/// A base class for [LyricsDataPlayer]
class LyricsDataPlayerBase implements LyricsDataPlayer {
  late _LyricsMidiPlayer _midiPlayer;

  /// on play event
  void onPlayEvent(PlayableEvent event) {
    // ignore: avoid_print
    var midiEvent = event.midiEvent;
    if (midiEvent is MetaTextEvent) {
      onPlayText(midiEvent.text);
    }
  }

  /// on play text
  void onPlayText(String text) {
    // ignore: avoid_print
    // print('text: $text');
  }

  /// Constructor
  LyricsDataPlayerBase() {
    _midiPlayer = _LyricsMidiPlayer(
      playEventCallback: (event) {
        onPlayEvent(event);
        // print('lyrics: $event');
      },
    );
  }

  /// Load lyrics data
  void load(LyricsData lyricsData) {
    _midiPlayer.loadLyricsData(lyricsData);
  }

  /// Resume
  void resume() {
    _midiPlayer.resume();
  }

  /// True when done
  Future<void> get done async {
    await _midiPlayer.done;
  }
}
