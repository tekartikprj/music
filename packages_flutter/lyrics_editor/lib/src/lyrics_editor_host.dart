/// What the host of the editor provides: where the document is saved, the
/// latency settings, the player view and extra actions.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

/// Where the editor saves the document. The editor never saves by itself:
/// it calls [save] (debounced, 2 s after the last change, and on leaving).
abstract class LyricsEditorStore {
  /// Save the document.
  Future<void> save(CvLyricsDocument document);

  /// Changes made elsewhere while editing, null when there is nothing to
  /// watch. A change shows the "Reload / Keep mine" banner.
  Stream<CvLyricsDocument>? get remoteChanges;
}

/// A store keeping the document in memory (tests, previews).
class LyricsEditorStoreMemory implements LyricsEditorStore {
  /// The last document saved, null until something is.
  CvLyricsDocument? saved;

  /// How many times [save] was called.
  var saveCount = 0;

  final _remote = StreamController<CvLyricsDocument>.broadcast();

  @override
  Future<void> save(CvLyricsDocument document) async {
    saved = document.copy();
    saveCount++;
  }

  @override
  Stream<CvLyricsDocument>? get remoteChanges => _remote.stream;

  /// Simulate a change made elsewhere.
  void changeRemotely(CvLyricsDocument document) {
    saved = document.copy();
    _remote.add(document.copy());
  }

  /// Release.
  Future<void> close() => _remote.close();
}

/// The latency settings of this device, read by the editor and written by
/// the calibration.
abstract class LyricsEditorSettings {
  /// How late a tap is on what it marks (reaction time), taken off every
  /// tap.
  ValueListenable<int> get tapLatencyMs;

  /// How late the sound comes out (Bluetooth: 150 to 300 ms): the display
  /// and the playhead are shifted by it.
  ValueListenable<int> get audioLatencyMs;

  /// Set [tapLatencyMs].
  Future<void> setTapLatencyMs(int value);

  /// Set [audioLatencyMs].
  Future<void> setAudioLatencyMs(int value);
}

/// The default tap latency.
const lyricsEditorDefaultTapLatencyMs = 100;

/// Settings kept in memory.
class LyricsEditorSettingsMemory implements LyricsEditorSettings {
  @override
  final ValueNotifier<int> tapLatencyMs;

  @override
  final ValueNotifier<int> audioLatencyMs;

  /// Settings kept in memory.
  LyricsEditorSettingsMemory({
    int tapLatencyMs = lyricsEditorDefaultTapLatencyMs,
    int audioLatencyMs = 0,
  }) : tapLatencyMs = ValueNotifier(tapLatencyMs),
       audioLatencyMs = ValueNotifier(audioLatencyMs);

  @override
  Future<void> setTapLatencyMs(int value) async => tapLatencyMs.value = value;

  @override
  Future<void> setAudioLatencyMs(int value) async =>
      audioLatencyMs.value = value;
}

/// A player with a picture (a YouTube video): the editor shows it, at least
/// 200 px high, never covered.
abstract class LyricsPlayerView {
  /// The picture.
  Widget buildView(BuildContext context);
}

/// An action the host adds to an editor menu (import from Drive, open the
/// latency settings, edit the text...).
class LyricsEditorAction {
  /// The menu label.
  final String label;

  /// An optional icon.
  final IconData? icon;

  /// Called when picked.
  final Future<void> Function(BuildContext context) onSelected;

  /// An action.
  const LyricsEditorAction({
    required this.label,
    required this.onSelected,
    this.icon,
  });
}
