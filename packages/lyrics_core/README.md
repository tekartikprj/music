## Lyrics core

Lyrics for karaoke and songbooks, pure Dart: the model (`CvLyrics`, every
time in media milliseconds), the formats (LRC and enhanced LRC, SRT/WebVTT,
the lyrics text format which also reads ChordPro), the effective timing
(`LyricsTimeline`), what a player plays of a song (`computePlayRanges`), a
smooth display position (`LyricsClock`) and the timing editor logic
(`LyricsTapEditor`). Also what the editor opens and saves
(`CvLyricsDocument`, its native `.lyrics.json` format) and what it plays
against (`LyricsPlayer`, a `ClockLyricsPlayer` when there is no media). The
Flutter display is `tekaly_lyrics_view`, the editor `tekaly_lyrics_editor`.

Moved from `festenao_lyrics` (`tekaly/festenao`), which re-exports it until its
users switch.

Setup `pubspec.yaml`:

```yaml
  tekaly_lyrics_core:
    git:
      url: https://github.com/tekartikprj/music
      path: packages/lyrics_core
    version: '>=0.1.0'
```

```dart
import 'package:tekaly_lyrics_core/lyrics_core.dart';
```
