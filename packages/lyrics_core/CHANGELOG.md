## 0.1.0

- Initial version, moved from `festenao_lyrics` (`tekaly/festenao`), which
  now re-exports it. `initFestenaoLyricsBuilders` is `initTekalyLyricsBuilders`.
- `LyricsPlayer` (and `LyricsPlayerClock`, `LyricsPlayerTracks`,
  `LyricsPlayerMute`), `ClockLyricsPlayer`.
- `CvLyricsDocument` (`CvLyricsMedia`, `CvLyricsTrack`), its native JSON
  format, `decodeLyricsBytes` (moved from karasongelio).
- `LyricsTapEditor.state` / `restore` (a host undo history), `isTimed` and
  `firstUntimedIndex` (an LRC line start times its first syllable).
- LRC: `|` inside a word splits the syllables not timed yet (`parseLrcLyrics`),
  `formatLrcLyrics(syllables: true)` writes them back (the editing text, not
  the export); `mergeLyricsExtras` keeps the chords, the sections and the page
  times across an edit of the LRC text.
