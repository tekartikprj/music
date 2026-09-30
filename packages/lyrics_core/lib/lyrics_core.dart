/// Lyrics for karaoke and songbooks: the model ([CvLyrics], every time in
/// media milliseconds), the formats (LRC and enhanced LRC, SRT/WebVTT, the
/// lyrics text format which also reads ChordPro), the effective timing
/// ([LyricsTimeline]: pages, where a position falls, the sung ranges), what
/// a player plays of a song ([computePlayRanges]: clips and skipped gaps), a
/// smooth position for the display ([LyricsClock]) and the logic of the
/// timing editor ([LyricsTapEditor]). Also what the editor opens and saves
/// ([CvLyricsDocument]) and what it plays against ([LyricsPlayer], a
/// [ClockLyricsPlayer] when there is no media).
///
/// Pure Dart; the karaoke display is in `tekaly_lyrics_view`.
library;

export 'src/clock_lyrics_player.dart'
    show ClockLyricsPlayer, clockLyricsPlayerRates;
export 'src/lyrics_chord.dart' show CvLyricsChordExt, transposeLyricsChord;
export 'src/lyrics_clock.dart' show LyricsClock;
export 'src/lyrics_document.dart'
    show
        CvLyricsDocument,
        CvLyricsDocumentExt,
        CvLyricsMedia,
        CvLyricsMediaKind,
        CvLyricsTrack,
        decodeLyricsBytes,
        lyricsDocumentFromMap,
        parseLyricsDocumentJson;
export 'src/lyrics_import.dart'
    show LyricsFormat, detectLyricsFormat, importLyrics;
export 'src/lyrics_lrc.dart' show LyricsImport, formatLrcLyrics, parseLrcLyrics;
export 'src/lyrics_merge.dart' show mergeLyricsExtras, mergeLyricsTiming;
export 'src/lyrics_model.dart'
    show
        CvLyrics,
        CvLyricsExt,
        CvLyricsLine,
        CvLyricsLineExt,
        CvLyricsPart,
        CvLyricsPartExt,
        initTekalyLyricsBuilders;
export 'src/lyrics_player.dart'
    show
        LyricsPlayer,
        LyricsPlayerClock,
        LyricsPlayerMute,
        LyricsPlayerReport,
        LyricsPlayerTracks,
        lyricsPlayerDefaultRates;
export 'src/lyrics_subtitles.dart' show parseSubtitleLyrics;
export 'src/lyrics_tap_editor.dart'
    show
        LyricsTapEditor,
        LyricsTapEditorState,
        LyricsTimingGranularity,
        LyricsTimingIssue,
        LyricsUnitRef;
export 'src/lyrics_text.dart'
    show
        formatLyricsText,
        isLyricsChordName,
        parseLyricsText,
        parseLyricsTextLine;
export 'src/lyrics_time.dart' show formatLyricsTime, parseLyricsTime;
export 'src/lyrics_timeline.dart'
    show
        LyricsLocation,
        LyricsTimeline,
        LyricsTimelineLine,
        LyricsTimelineOptions,
        LyricsTimelinePage,
        LyricsTimelinePart;
export 'src/media_range.dart'
    show MediaRange, computePlayRanges, nextPlayRangeIndex;
