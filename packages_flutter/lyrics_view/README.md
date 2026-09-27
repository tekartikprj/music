## Lyrics view

The karaoke and songbook display of `tekaly_lyrics_core` lyrics:
`KaraokeLyricsView` follows a media position (a page or a scrolling list, the
syllables wiped as they are sung, lead-in dots after a gap) and
`SongbookLyricsView` shows the text with the chords above the syllables.

Moved from `festenao_lyrics_player` (`tekaly/festenao`), which re-exports it
until its users switch.

```yaml
  tekaly_lyrics_view:
    git:
      url: https://github.com/tekartikprj/music
      path: packages_flutter/lyrics_view
    version: '>=0.1.0'
```

```dart
import 'package:tekaly_lyrics_view/lyrics_view.dart';
```
