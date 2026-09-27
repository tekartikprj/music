/// The karaoke display of `tekaly_lyrics_core` lyrics ([CvLyrics]): a page
/// (or a scrolling list) of lines, the syllables wiped as they are sung,
/// lead-in dots after a gap ([KaraokeLyricsView]); and their songbook text,
/// the chords above the syllables ([SongbookLyricsView]).
///
/// Re-exports `package:tekaly_lyrics_core/lyrics_core.dart` (the model, the
/// formats, the timeline and the clock).
library;

export 'package:tekaly_lyrics_core/lyrics_core.dart';

export 'src/karaoke/karaoke_lyrics_view.dart'
    show KaraokeLyricsLayout, KaraokeLyricsStyle, KaraokeLyricsView;
export 'src/karaoke/songbook_lyrics_view.dart' show SongbookLyricsView;
