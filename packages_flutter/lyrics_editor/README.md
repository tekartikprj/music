## Lyrics editor

The lyrics editor widgets: time lyrics by tapping along (per syllable, word,
line or page, hold mode, nudge, loop, speed), edit the text (syllables with
`|`, `[C]` chords, pages), calibrate the latencies, preview. One controller
(`LyricsEditorController`) shares the document, the clock and one undo
history between them.

No player and no storage of its own: the host gives a `LyricsPlayer`
(`tekaly_lyrics_core`; a `ClockLyricsPlayer` when there is no media), a
`LyricsEditorStore` and `LyricsEditorSettings`. Karasongelio hosts it on its
playlist player and synced db; `apps/lyrics_editor_app` on audio files,
YouTube or a clock, and local drafts.

```yaml
  tekaly_lyrics_editor:
    git:
      url: https://github.com/tekartikprj/music
      path: packages_flutter/lyrics_editor
    version: '>=0.1.0'
```

```dart
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';
```

See the `tekaly-lyrics-editor-host` skill.
