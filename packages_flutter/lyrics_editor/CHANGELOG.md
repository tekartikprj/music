## 0.1.0

- Initial version: the timing editor, the text editor and the latency
  calibration, extracted from karasongelio behind `LyricsPlayer`,
  `LyricsEditorStore` and `LyricsEditorSettings`; `LyricsEditorController`
  with one undo history for the text and the timing.
- `LyricsTextImportButton` and `importFile` take the file extensions offered
  (`allowedExtensions`), `LyricsTextEditor` the help shown (`help`).
- `LyricsTextController(format: LyricsTextFormat.lrc)`: the text is the LRC
  itself, times included (`|` splits the syllables not timed yet), the
  chords, sections and page times kept across the edit; `lyricsLrcHelp`.
