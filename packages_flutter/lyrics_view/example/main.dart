// Karaoke lyrics following a player with no media (a stopwatch), and the same
// song as songbook text with its chords.
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

/// Enhanced LRC: line times, and `<mm:ss.xx>` syllable times on the first
/// line (the second one is timed by its start only).
const karaokeLrc = '''
[00:01.00]<00:01.00>Hel<00:01.50>lo <00:02.00>world
[00:04.00]A line timed by its start
[00:12.00]After a gap, with lead-in dots
''';

/// The lyrics text format: `[Label]` sections, `[C]` chords, `|` syllables.
const songbookText = '''
[Chorus]
Il en faut [C]peu
Pour être heu|[G]reux
''';

void main() {
  // Once, before reading or copying lyrics documents (idempotent).
  initTekalyLyricsBuilders();
  runApp(const MaterialApp(home: LyricsExampleScreen()));
}

/// The karaoke view on top, the songbook view below.
class LyricsExampleScreen extends StatefulWidget {
  /// The example screen.
  const LyricsExampleScreen({super.key});

  @override
  State<LyricsExampleScreen> createState() => _LyricsExampleScreenState();
}

class _LyricsExampleScreenState extends State<LyricsExampleScreen> {
  final _karaoke = parseLrcLyrics(karaokeLrc).lyrics;
  final _songbook = parseLyricsText(songbookText).lyrics;

  /// No media: a stopwatch that plays, pauses and seeks like a player. With a
  /// real player, feed a `LyricsClock` with its reports
  /// (`clock.report(positionMs, playing: playing)`) and read
  /// `clock.positionMs` instead.
  final _player = ClockLyricsPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Column(
      children: [
        // A bounded box: the page layout fits the font to it.
        Expanded(
          child: KaraokeLyricsView(
            lyrics: _karaoke,
            // Read on every frame, the media time in milliseconds.
            positionMs: () => _player.positionMs,
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // Not scrollable itself.
              child: SongbookLyricsView(lyrics: _songbook, transpose: 2),
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _togglePlay,
      child: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
    ),
  );
}
