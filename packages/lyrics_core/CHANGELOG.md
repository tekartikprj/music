## 0.1.0

- Initial version, moved from `festenao_lyrics` (`tekaly/festenao`), which
  now re-exports it. `initFestenaoLyricsBuilders` is `initTekalyLyricsBuilders`.
- `LyricsPlayer` (and `LyricsPlayerClock`, `LyricsPlayerTracks`,
  `LyricsPlayerMute`), `ClockLyricsPlayer`.
- `CvLyricsDocument` (`CvLyricsMedia`, `CvLyricsTrack`), its native JSON
  format, `decodeLyricsBytes` (moved from karasongelio).
- `LyricsTapEditor.state` / `restore` (a host undo history), `isTimed` and
  `firstUntimedIndex` (an LRC line start times its first syllable).
