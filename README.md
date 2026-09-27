# music

Music related components.

| Package | Folder | What |
|---|---|---|
| `tekaly_music_note` | `packages/music_note` | Notes and chords, transposition |
| `tekaly_chordpro` | `packages/chordpro` | ChordPro parser and formatter |
| `tekaly_lyrics` | `packages/lyrics` | The older LRC parser and players (kiosk, karakelio) |
| `tekaly_lyrics_core` | `packages/lyrics_core` | Lyrics model, formats (LRC, SRT, text/ChordPro), timing, the tap editor logic, players, documents |
| `tekaly_lyrics_view` | `packages_flutter/lyrics_view` | Karaoke and songbook display |
| `tekaly_lyrics_editor` | `packages_flutter/lyrics_editor` | The lyrics editor widgets (timing, text, latency), any player, any storage |
| `lyrics_editor_app` | `apps/lyrics_editor_app` | The standalone lyrics editor (desktop, web) |

The workspace has Flutter packages: use `flutter pub get` at the root.
