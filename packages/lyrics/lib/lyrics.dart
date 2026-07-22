/// Lyrics parsing, model, and playback support (LRC format).
library;

export 'src/lrc_parser.dart' show parseLyricLrc, parseLyricDurationLrc;
export 'src/lyrics.dart'
    show
        LyricsData,
        LyricsDataExt,
        LyricsLineData,
        LyricsLineDataExt,
        LyricsPartData,
        LyricsLineSingleContent,
        LyricsLineMultiContent,
        LyricsLineContent;
