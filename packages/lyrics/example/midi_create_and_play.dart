import 'package:tekartik_midi/midi.dart';
import 'package:tekartik_midi/midi_file_player.dart';
import 'package:tekartik_midi/midi_player_base.dart';

MidiFile getDemoFileCDE() {
  final file = MidiFile();
  file.fileFormat = MidiFile.formatMultiTrack;
  file.ppq = 240;

  var track = MidiTrack();
  track.addEvent(0, TimeSigEvent(4, 4));
  track.addEvent(0, TempoEvent.bpm(120));
  track.addEvent(0, EndOfTrackEvent());
  file.addTrack(track);

  track = MidiTrack();
  track.addEvent(0, ProgramChangeEvent(1, 25));
  track.addEvent(0, NoteOnEvent(1, 42, 127));
  track.addEvent(240, NoteOffEvent(1, 42, 127));
  track.addEvent(240, NoteOnEvent(1, 44, 127));
  track.addEvent(240, NoteOnEvent(1, 46, 127));

  track.addEvent(0, NoteOffEvent(1, 44, 127));
  track.addEvent(480, NoteOffEvent(1, 46, 127));
  track.addEvent(0, EndOfTrackEvent());

  file.addTrack(track);

  return file;
}

class StdoutMidiPlayer extends MidiPlayerBase {
  @override
  void rawPlayEvent(PlayableEvent event) {
    // ignore: avoid_print
    print(event);
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

  StdoutMidiPlayer() : super(null);
}

Future<void> main(List<String> args) async {
  var file = getDemoFileCDE();
  final player = StdoutMidiPlayer();
  player.load(file);
  player.resume();

  await player.done;
}
