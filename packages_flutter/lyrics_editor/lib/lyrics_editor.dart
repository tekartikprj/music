/// The lyrics editor widgets, with no player and no storage of their own:
/// the host gives a [LyricsPlayer] (a [ClockLyricsPlayer] when there is no
/// media), a [LyricsEditorStore] and [LyricsEditorSettings].
///
/// - [LyricsEditorController]: the state the widgets share (the document,
///   the clock, the timing editor, saving, the changes made elsewhere).
/// - [LyricsTimingEditor], [LyricsTimingKeys], [LyricsTimingMenuButton]: the
///   timing editor (tap along, to the syllable, the word, the line or the
///   page).
/// - [LyricsTextEditor], [LyricsTextController]: the text (typed, pasted,
///   imported; exported as LRC or text).
/// - [LyricsLatencySettings]: the tap and audio latencies, with a
///   calibration.
/// - [LyricsTransportBar], [LyricsKaraokePreview]: the transport and the
///   preview.
///
/// Re-exports `package:tekaly_lyrics_view/lyrics_view.dart`.
library;

export 'package:tekaly_lyrics_view/lyrics_view.dart';

export 'src/latency/lyrics_latency_settings.dart' show LyricsLatencySettings;
export 'src/lyrics_editor_controller.dart'
    show
        LyricsEditorController,
        lyricsEditorMaxUndo,
        lyricsEditorPreRoll,
        lyricsEditorSaveDelay;
export 'src/lyrics_editor_dialogs.dart'
    show
        formatLyricsPlaybackRate,
        lyricsEditorConfirm,
        lyricsEditorPromptText,
        lyricsEditorSnackBar;
export 'src/lyrics_editor_host.dart'
    show
        LyricsEditorAction,
        LyricsEditorSettings,
        LyricsEditorSettingsMemory,
        LyricsEditorStore,
        LyricsEditorStoreMemory,
        LyricsPlayerView,
        lyricsEditorDefaultTapLatencyMs;
export 'src/lyrics_transport_bar.dart'
    show LyricsKaraokePreview, LyricsSpeedMenu, LyricsTransportBar;
export 'src/text/lyrics_text_editor.dart'
    show
        LyricsTextController,
        LyricsTextEditor,
        LyricsTextImportButton,
        LyricsTextMenuButton,
        lyricsFileBaseName,
        lyricsFileExtensions,
        lyricsTextHelp;
export 'src/timing/lyrics_timing_editor.dart'
    show
        LyricsEditorSaveButton,
        LyricsTapBar,
        LyricsTimingEditor,
        LyricsTimingKeys,
        LyricsTimingMenuButton;
