/// The state the editor widgets share: the document, the player and its
/// clock, the timing editor, saving and the changes made elsewhere.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

import 'lyrics_editor_host.dart';

/// The pre-roll before a line replayed (previous line, loop).
const lyricsEditorPreRoll = Duration(seconds: 2);

/// How long after the last change the document is saved.
const lyricsEditorSaveDelay = Duration(seconds: 2);

/// The most undo steps kept.
const lyricsEditorMaxUndo = 200;

/// The state the editor widgets share.
///
/// It owns the clock (fed by the player reports, unless the player is a
/// [LyricsPlayerClock]), the timing editor ([tapEditor], null while there
/// are no lyrics), the debounced save to the [store] and the changes made
/// elsewhere ([remoteChanged]). It never disposes the [player]: the host
/// does.
class LyricsEditorController extends ChangeNotifier {
  /// The player the lyrics are timed against.
  final LyricsPlayer player;

  /// The latency settings.
  final LyricsEditorSettings settings;

  /// Where the document is saved, none for a read only preview.
  final LyricsEditorStore? store;

  /// How long after the last change the document is saved.
  final Duration saveDelay;

  /// The pre-roll before a line replayed.
  final Duration preRoll;

  /// The smooth media position every tap, the playhead and the preview
  /// read.
  late final LyricsClock clock;
  late final bool _ownClock;

  /// The last player report: what the transport bar shows.
  final playerState = ValueNotifier<LyricsPlayerReport>(
    const LyricsPlayerReport(positionMs: 0, playing: false),
  );

  late CvLyricsDocument _document;
  LyricsTapEditor? _tapEditor;
  var _granularity = LyricsTimingGranularity.syllable;

  /// What was last saved (or loaded).
  CvLyrics? _saved;

  /// A change made elsewhere, not applied yet.
  CvLyricsDocument? _remote;

  /// One undo history for the text and the timing.
  final _undoStack = <LyricsTapEditorState>[];
  final _redoStack = <LyricsTapEditorState>[];

  Timer? _saveTimer;
  StreamSubscription<LyricsPlayerReport>? _reportSubscription;
  StreamSubscription<CvLyricsDocument>? _remoteSubscription;
  var _disposed = false;

  /// The unit selected (nudge, set to now), null when none is.
  LyricsUnitRef? selected;

  /// Hold mode: a key down is the start, a key up the end.
  var holdMode = false;

  /// Loop the current line.
  var loop = false;

  /// True when there are changes not saved yet.
  var dirty = false;

  /// Bumped on every change: the preview rebuilds its timeline.
  var revision = 0;

  /// The controller of [document].
  LyricsEditorController({
    required CvLyricsDocument document,
    required this.player,
    required this.settings,
    this.store,
    this.saveDelay = lyricsEditorSaveDelay,
    this.preRoll = lyricsEditorPreRoll,
  }) {
    var player = this.player;
    if (player is LyricsPlayerClock) {
      clock = (player as LyricsPlayerClock).clock;
      _ownClock = false;
    } else {
      clock = LyricsClock();
      _ownClock = true;
    }
    _setDocument(document);
    _reportSubscription = player.reports.listen(_onReport);
    _remoteSubscription = store?.remoteChanges?.listen(_onRemote);
    settings.tapLatencyMs.addListener(_onTapLatency);
  }

  void _setDocument(CvLyricsDocument document) {
    _document = document.copy();
    var lyrics = _document.lyricsOrEmpty;
    _saved = lyrics.copy();
    _resetTapEditor(lyrics);
  }

  void _resetTapEditor(CvLyrics lyrics) {
    if (lyrics.isEmpty) {
      _tapEditor = null;
      return;
    }
    _tapEditor = LyricsTapEditor(
      lyrics,
      granularity: _granularity,
      tapLatencyMs: settings.tapLatencyMs.value,
    );
    _moveCursorToFirstUntimed();
  }

  /// Carry on where the timing stopped: the first untimed unit.
  void _moveCursorToFirstUntimed() {
    var editor = _tapEditor!;
    editor.moveCursor(-editor.cursor);
    editor.moveCursor(editor.firstUntimedIndex);
  }

  void _onTapLatency() {
    _tapEditor?.tapLatencyMs = settings.tapLatencyMs.value;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // --- The document ---

  /// The timing editor, null while there are no lyrics.
  LyricsTapEditor? get tapEditor => _tapEditor;

  /// The lyrics now.
  CvLyrics get lyrics => _tapEditor?.lyrics ?? _document.lyricsOrEmpty;

  /// True when there are lyrics to time.
  bool get hasLyrics => !lyrics.isEmpty;

  /// The document now, a copy.
  CvLyricsDocument get document =>
      _document.copy()..lyrics.v = lyrics.isEmpty ? null : lyrics.copy();

  /// What a tap times.
  LyricsTimingGranularity get granularity => _granularity;

  /// Replace the lyrics (a text edit, an import): the timing starts again
  /// from the first untimed unit.
  void setLyrics(CvLyrics lyrics) {
    _record();
    _document.lyrics.v = lyrics.copy();
    _resetTapEditor(lyrics);
    selected = null;
    changed();
  }

  /// Change the document fields other than the lyrics (title, artist...).
  void updateDocument(void Function(CvLyricsDocument document) update) {
    update(_document);
    changed();
  }

  // --- Undo history ---

  LyricsTapEditorState get _state =>
      _tapEditor?.state ?? LyricsTapEditorState(lyrics.copy(), 0, null);

  /// Remember the state before a change.
  void _record() {
    _undoStack.add(_state);
    if (_undoStack.length > lyricsEditorMaxUndo) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Forget the state remembered by [_record] (the change did nothing).
  void _unrecord() {
    _undoStack.removeLast();
  }

  void _restore(LyricsTapEditorState state) {
    var lyrics = state.lyrics;
    _document.lyrics.v = lyrics.isEmpty ? null : lyrics.copy();
    if (lyrics.isEmpty) {
      _tapEditor = null;
    } else {
      var editor = _tapEditor ??= LyricsTapEditor(
        lyrics,
        granularity: _granularity,
        tapLatencyMs: settings.tapLatencyMs.value,
      );
      editor.restore(state);
    }
    selected = _tapEditor?.lastTapped;
  }

  /// True when there is something to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// True when there is something to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Undo the last change (a tap as well as a text edit).
  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    _redoStack.add(_state);
    _restore(_undoStack.removeLast());
    changed();
  }

  /// Redo the last change undone.
  void redo() {
    if (_redoStack.isEmpty) {
      return;
    }
    _undoStack.add(_state);
    _restore(_redoStack.removeLast());
    changed();
  }

  // --- Changes and saving ---

  /// Something changed: saved [saveDelay] later.
  void changed() {
    dirty = true;
    revision++;
    _notify();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(save()));
  }

  /// Save now, when there is something to save.
  Future<void> save() async {
    _saveTimer?.cancel();
    var store = this.store;
    if (store == null || !dirty) {
      return;
    }
    var document = this.document;
    _saved = lyrics.copy();
    dirty = false;
    await store.save(document);
    _remote = null;
    _notify();
  }

  /// True when the lyrics were changed elsewhere meanwhile.
  bool get remoteChanged => _remote != null;

  void _onRemote(CvLyricsDocument remote) {
    var remoteLyrics = remote.lyricsOrEmpty;
    // Our own save, or the same content: nothing to say.
    if (remoteLyrics == _saved || remoteLyrics == lyrics) {
      return;
    }
    _remote = remote;
    _notify();
  }

  /// Take the lyrics changed elsewhere.
  void reloadRemote() {
    var remote = _remote;
    if (remote == null) {
      return;
    }
    _remote = null;
    _setDocument(remote);
    _undoStack.clear();
    _redoStack.clear();
    dirty = false;
    selected = null;
    revision++;
    _notify();
  }

  /// Keep ours: saved over the ones changed elsewhere.
  void keepMine() {
    _remote = null;
    changed();
  }

  // --- Player ---

  /// The media position now.
  int get positionMs => clock.positionMs;

  void _onReport(LyricsPlayerReport report) {
    playerState.value = report;
    if (_ownClock) {
      clock.report(
        report.positionMs,
        playing: report.playing,
        rate: report.rate,
      );
    }
    _checkLoop(report.positionMs);
  }

  void _checkLoop(int positionMs) {
    var editor = _tapEditor;
    if (!loop || editor == null) {
      return;
    }
    var line = editor.lastTapped?.line ?? editor.cursorUnit?.line;
    if (line == null) {
      return;
    }
    var timed = LyricsTimeline(editor.lyrics).lines[line];
    var start = timed.startMs;
    var end = timed.endMs ?? timed.sungEndMs;
    if (start == null || end == null) {
      return;
    }
    if (positionMs >= end + 300) {
      unawaited(seek(max(0, start - preRoll.inMilliseconds)));
    }
  }

  /// Play.
  Future<void> play() => player.play();

  /// Pause.
  Future<void> pause() => player.pause();

  /// Play or pause.
  Future<void> togglePlayPause() =>
      playerState.value.playing ? pause() : play();

  /// Seek to [positionMs].
  Future<void> seek(int positionMs) async {
    if (_ownClock) {
      clock.seek(positionMs);
    }
    await player.seek(positionMs);
  }

  /// Seek by [deltaMs] from where the clock is.
  Future<void> seekBy(int deltaMs) => seek(max(0, positionMs + deltaMs));

  /// Set the playback rate.
  Future<void> setRate(double rate) async {
    if (_ownClock) {
      clock.setRate(rate);
    }
    await player.setRate(rate);
  }

  /// The next (1) or previous (-1) rate of the player menu.
  Future<void> changeSpeed(int direction) async {
    var rates = player.rates;
    if (rates.isEmpty) {
      return;
    }
    var index = rates.indexOf(playerState.value.rate);
    if (index < 0) {
      index = max(0, rates.indexOf(1.0));
    }
    index = (index + direction).clamp(0, rates.length - 1);
    await setRate(rates[index]);
  }

  /// Loop the current line, or stop looping.
  void toggleLoop() {
    loop = !loop;
    _notify();
  }

  /// Back to the line before the cursor, [preRoll] before it, to re-tap
  /// from there.
  Future<void> fromPreviousLine() async {
    var editor = _tapEditor;
    if (editor == null) {
      return;
    }
    var line = max(0, (editor.cursorUnit?.line ?? editor.units.length) - 1);
    var timeline = LyricsTimeline(editor.lyrics);
    int? start;
    for (var i = line; i >= 0 && start == null; i--) {
      start = timeline.lines[i].startMs;
      line = i;
    }
    editor.moveCursorToLine(line);
    _notify();
    await seek(max(0, (start ?? 0) - preRoll.inMilliseconds));
    if (!playerState.value.playing) {
      await play();
    }
  }

  // --- Taps ---

  /// Time the unit under the cursor, advance.
  void tap() {
    var editor = _tapEditor;
    if (editor == null) {
      return;
    }
    _record();
    if (editor.tap(positionMs)) {
      selected = editor.lastTapped;
      changed();
    } else {
      _unrecord();
    }
  }

  /// The end of a hold (hold mode only).
  void release() {
    var editor = _tapEditor;
    if (editor == null || !holdMode) {
      return;
    }
    _record();
    editor.release(positionMs);
    changed();
  }

  /// The end of the current line, now.
  void endLine() {
    var editor = _tapEditor;
    if (editor == null) {
      return;
    }
    _record();
    editor.endLine(positionMs);
    changed();
  }

  /// The next line starts a page, now.
  void pageHere() {
    var editor = _tapEditor;
    if (editor == null) {
      return;
    }
    _record();
    editor.pageHere(positionMs);
    changed();
  }

  /// The unit the nudge and "set to now" act on.
  LyricsUnitRef? get nudgeTarget => selected ?? _tapEditor?.lastTapped;

  /// Nudge the selected time by [deltaMs].
  void nudge(int deltaMs) {
    var editor = _tapEditor;
    var ref = nudgeTarget;
    if (editor == null || ref == null) {
      return;
    }
    _record();
    editor.nudge(ref, deltaMs);
    changed();
  }

  /// The selected time set to now.
  void setSelectedToNow() {
    var editor = _tapEditor;
    var ref = selected;
    if (editor == null || ref == null) {
      return;
    }
    _record();
    editor.setTime(ref, positionMs);
    changed();
  }

  /// Move the cursor by [delta] units.
  void moveCursor(int delta) {
    _tapEditor?.moveCursor(delta);
    _notify();
  }

  /// Select [ref] and move the cursor to it.
  void selectUnit(LyricsUnitRef ref) {
    var editor = _tapEditor;
    if (editor == null) {
      return;
    }
    selected = ref;
    editor.moveCursorTo(ref);
    _notify();
  }

  /// What a tap times.
  void setGranularity(LyricsTimingGranularity granularity) {
    _granularity = granularity;
    _tapEditor?.setGranularity(granularity);
    _notify();
  }

  /// Hold mode on or off.
  void setHoldMode(bool holdMode) {
    this.holdMode = holdMode;
    _notify();
  }

  /// The line the "from the cursor" actions start from.
  int? get actionLine => _tapEditor?.cursorUnit?.line ?? selected?.line;

  /// Set the offset added to every time.
  void setOffset(int offsetMs) {
    _record();
    _tapEditor?.setOffset(offsetMs);
    changed();
  }

  /// Shift the times from [line] on by [deltaMs].
  void shiftFrom(int line, int deltaMs) {
    _record();
    _tapEditor?.shiftFrom(line, deltaMs);
    changed();
  }

  /// Clear the times from [line] on.
  void clearFrom(int line) {
    _record();
    _tapEditor?.clearFrom(line);
    changed();
  }

  /// Estimate the syllables of the selected (or last tapped) line.
  void estimateParts() {
    var editor = _tapEditor;
    var line = selected?.line ?? editor?.lastTapped?.line;
    if (editor == null || line == null) {
      return;
    }
    _record();
    editor.estimateParts(line);
    changed();
  }

  /// Save what is not saved yet, then release (not the player).
  Future<void> close() async {
    _saveTimer?.cancel();
    if (dirty) {
      await save();
    }
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _saveTimer?.cancel();
    if (dirty) {
      // Saved in the background, nothing is notified any more.
      unawaited(save());
    }
    _disposed = true;
    settings.tapLatencyMs.removeListener(_onTapLatency);
    unawaited(_reportSubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    playerState.dispose();
    super.dispose();
  }
}
