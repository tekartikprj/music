# Lyrics editor

Open a lyrics file and the audio it goes with, time the lyrics by tapping
along (per syllable, word, line or page), add chords, save. No account, no
server: files on disk (desktop) or picked and dropped (web).

- **Opening**: open or drop files. `X.lrc` finds `X.mp3`, `X-vocals.mp3` and
  `X-no_vocals.mp3` next to it (and the other way round); on the web, among
  the files picked together. Also a YouTube link, pasted lyrics, or nothing
  (timing against a clock).
- **Editing**: three tabs (text, timing, preview) on one document, one
  player and one undo history (Ctrl+Z, Shift+Ctrl+Z). V switches tracks
  (song, vocals, instrumental), keeping the position.
- **Saving**: the editor saves a local draft as you go; Ctrl+S writes the
  file in its own format (LRC, text/ChordPro, or the lossless
  `.lyrics.json`), after saying once what the format loses. Subtitles are
  saved as LRC next to them. A draft newer than its file is offered back.

## Samples

Three traditional songs (public domain) in `assets/samples/`, listed on the
home screen and openable from disk too. Their audio is generated from the
same notes as their lyrics (a note a syllable over a bass line), so tapping
along matches what is heard:

| Sample | Lyrics | Audio |
|---|---|---|
| Frère Jacques | `frere_jacques.lrc`, timed to the syllable | `frere_jacques.mp3`, `-vocals.mp3` (melody), `-no_vocals.mp3` (bass): V switches |
| Au clair de la lune | `au_clair_de_la_lune.lrc`, timed to the line | `au_clair_de_la_lune.mp3` |
| Twinkle, Twinkle, Little Star | `twinkle_twinkle.cho`, not timed, with chords | `twinkle_twinkle.mp3` |

The audio is mp3, 128 kbps mono, 44.1 kHz.

They come from `lib/src/samples/lyrics_sample_songs.dart`; regenerate them
with `dart run tool/generate_samples.dart`, which needs ffmpeg with
libmp3lame (a test checks the lyrics files and the mp3 format).

The editor itself is `tekaly_lyrics_editor` (`packages_flutter/lyrics_editor`).
Spec: `alextekartik/projects.dart` `doc/ideas/standalone_lyrics_spec.md`.

```sh
flutter run -d linux   # or macos, windows, chrome
```

On Linux, audio playback needs libmpv (just_audio_mpv).
