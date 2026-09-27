/// The timing editor: tap along with the song to time its lyrics, to the
/// syllable, the word, the line or the page, then fine-tune.
///
/// The times recorded are media times, so tapping at half speed gives
/// precise times. The logic is `LyricsTapEditor` (tekaly_lyrics_core); this
/// is its screen body: the player view, the preview, the transport bar, the
/// lyrics with the cursor and the tap pad. The keys are
/// [LyricsTimingKeys], the menu [LyricsTimingMenuButton].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

import '../lyrics_editor_controller.dart';
import '../lyrics_editor_dialogs.dart';
import '../lyrics_editor_host.dart';
import '../lyrics_transport_bar.dart';

/// The timing editor body.
class LyricsTimingEditor extends StatefulWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// Show the karaoke preview above the lyrics.
  final bool showPreview;

  /// Shown when there are no lyrics to time yet.
  final Widget? noLyrics;

  /// The timing editor body.
  const LyricsTimingEditor({
    super.key,
    required this.controller,
    this.showPreview = true,
    this.noLyrics,
  });

  @override
  State<LyricsTimingEditor> createState() => _LyricsTimingEditorState();
}

class _LyricsTimingEditorState extends State<LyricsTimingEditor> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};
  LyricsUnitRef? _lastCursor;

  LyricsEditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
    _lastCursor = controller.tapEditor?.cursorUnit;
    _revealCursor();
  }

  @override
  void didUpdateWidget(covariant LyricsTimingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onChange);
      controller.addListener(_onChange);
    }
  }

  void _onChange() {
    var cursor = controller.tapEditor?.cursorUnit;
    if (cursor != _lastCursor) {
      _lastCursor = cursor;
      _revealCursor();
    }
  }

  void _revealCursor() {
    var line = controller.tapEditor?.cursorUnit?.line;
    if (line == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var context = _lineKeys[line]?.currentContext;
      if (context != null && context.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            context,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    var editor = controller.tapEditor;
    if (editor == null) {
      return widget.noLyrics ??
          const Center(child: Text('There are no lyrics to time yet.'));
    }
    var issues = editor.validate();
    var issueRefs = {for (var issue in issues) issue.ref};
    var player = controller.player;
    return LayoutBuilder(
      builder: (context, constraints) {
        var wide = constraints.maxWidth >= 900;
        var media = Column(
          children: [
            if (player is LyricsPlayerView)
              SizedBox(
                height: wide ? 240 : 200,
                child: (player as LyricsPlayerView).buildView(context),
              ),
            if (widget.showPreview)
              SizedBox(
                height: wide ? 160 : 110,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: LyricsKaraokePreview(controller: controller),
                ),
              ),
            LyricsTransportBar(controller: controller),
          ],
        );
        var lyricsList = _LyricsTimingList(
          editor: editor,
          selected: controller.selected,
          issueRefs: issueRefs,
          lineKeys: _lineKeys,
          scrollController: _scrollController,
          onSelect: controller.selectUnit,
        );
        return Column(
          children: [
            if (controller.remoteChanged)
              MaterialBanner(
                content: const Text(
                  'These lyrics were changed elsewhere meanwhile.',
                ),
                actions: [
                  TextButton(
                    onPressed: controller.reloadRemote,
                    child: const Text('Reload'),
                  ),
                  TextButton(
                    onPressed: controller.keepMine,
                    child: const Text('Keep mine'),
                  ),
                ],
              ),
            if (issues.isNotEmpty)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber),
                  title: Text(
                    '${issues.length} timing issue(s), first: line '
                    '${issues.first.ref.line + 1} ${issues.first.message}',
                  ),
                  onTap: () => controller.selectUnit(issues.first.ref),
                ),
              ),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        SizedBox(
                          width: 460,
                          child: SingleChildScrollView(child: media),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: lyricsList),
                      ],
                    )
                  : LayoutBuilder(
                      // The media part shrinks (and scrolls) on a short
                      // screen, the lyrics keep at least 40% of it.
                      builder: (context, inner) => Column(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: inner.maxHeight * 0.6,
                            ),
                            child: SingleChildScrollView(child: media),
                          ),
                          const Divider(height: 1),
                          Expanded(child: lyricsList),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            LyricsTapBar(controller: controller),
          ],
        );
      },
    );
  }
}

/// The keys of the timing editor, active while [child] (or something in
/// it) has the focus.
///
/// | Key | Action |
/// |---|---|
/// | Space (tap) | time the unit under the cursor, advance |
/// | Space held (hold mode) | key down is the start, key up the end |
/// | Enter | end of the current line |
/// | P, Shift+Enter | the next line starts a page, now |
/// | Backspace | undo |
/// | ← / → | seek −2 s / +2 s |
/// | Shift+← | back to the previous line (2 s before), re-tap from there |
/// | ↑ / ↓ | move the cursor |
/// | , / . | nudge the selected time by −10 / +10 ms (Shift: ±100 ms) |
/// | [ / ] | speed down / up |
/// | L | loop the current line |
/// | K | play / pause |
class LyricsTimingKeys extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// What the keys apply to.
  final Widget child;

  /// Grab the focus when shown.
  final bool autofocus;

  /// An external focus node, one is created otherwise.
  final FocusNode? focusNode;

  /// The keys of the timing editor.
  const LyricsTimingKeys({
    super.key,
    required this.controller,
    required this.child,
    this.autofocus = true,
    this.focusNode,
  });

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    var key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        controller.tap();
      } else if (event is KeyUpEvent) {
        controller.release();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    var shift = HardwareKeyboard.instance.isShiftPressed;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (shift && event is KeyDownEvent) {
        unawaited(controller.fromPreviousLine());
      } else {
        unawaited(controller.seekBy(-2000));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(controller.seekBy(2000));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      controller.moveCursor(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.moveCursor(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.comma) {
      controller.nudge(shift ? -100 : -10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.period) {
      controller.nudge(shift ? 100 : 10);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter) {
      shift ? controller.pageHere() : controller.endLine();
    } else if (key == LogicalKeyboardKey.keyP) {
      controller.pageHere();
    } else if (key == LogicalKeyboardKey.backspace) {
      controller.undo();
    } else if (key == LogicalKeyboardKey.bracketLeft) {
      unawaited(controller.changeSpeed(-1));
    } else if (key == LogicalKeyboardKey.bracketRight) {
      unawaited(controller.changeSpeed(1));
    } else if (key == LogicalKeyboardKey.keyL) {
      controller.toggleLoop();
    } else if (key == LogicalKeyboardKey.keyK) {
      unawaited(controller.togglePlayPause());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: _onKeyEvent,
      child: child,
    );
  }
}

/// The timing actions menu: estimate, shift, clear, offset, plus the
/// [actions] of the host (latency settings, text...).
class LyricsTimingMenuButton extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// The actions of the host, after the timing ones.
  final List<LyricsEditorAction> actions;

  /// The timing actions menu.
  const LyricsTimingMenuButton({
    super.key,
    required this.controller,
    this.actions = const [],
  });

  Future<void> _setOffset(BuildContext context) async {
    if (controller.tapEditor == null) {
      return;
    }
    var text = await lyricsEditorPromptText(
      context,
      title: 'Offset',
      label: 'Milliseconds added to every time',
      initialValue: '${controller.lyrics.offset}',
      helperText:
          'To reuse the timing on another recording: a longer intro is a '
          'positive offset.',
    );
    var offset = int.tryParse(text?.trim() ?? '');
    if (offset != null) {
      controller.setOffset(offset);
    }
  }

  Future<void> _shiftFromCursor(BuildContext context) async {
    var line = controller.actionLine;
    if (controller.tapEditor == null || line == null) {
      return;
    }
    var text = await lyricsEditorPromptText(
      context,
      title: 'Shift the times',
      label: 'Milliseconds, from line ${line + 1} on',
      initialValue: '0',
    );
    var delta = int.tryParse(text?.trim() ?? '');
    if (delta != null && delta != 0) {
      controller.shiftFrom(line, delta);
    }
  }

  Future<void> _clearFromCursor(BuildContext context) async {
    var line = controller.actionLine;
    if (controller.tapEditor == null || line == null) {
      return;
    }
    var ok = await lyricsEditorConfirm(
      context,
      title: 'Clear the times',
      message: 'Remove every time from line ${line + 1} on?',
    );
    if (ok) {
      controller.clearFrom(line);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      onSelected: (value) async {
        if (value is LyricsEditorAction) {
          await value.onSelected(context);
          return;
        }
        switch (value) {
          case 'offset':
            await _setOffset(context);
          case 'shift':
            await _shiftFromCursor(context);
          case 'clear':
            await _clearFromCursor(context);
          case 'estimate':
            controller.estimateParts();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'estimate',
          child: Text('Estimate the syllables of the line'),
        ),
        const PopupMenuItem(
          value: 'shift',
          child: Text('Shift the times from the cursor…'),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Text('Clear the times from the cursor…'),
        ),
        const PopupMenuItem(value: 'offset', child: Text('Offset…')),
        for (var action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }
}

/// The lyrics, every unit with its time, the cursor and the selection.
class _LyricsTimingList extends StatelessWidget {
  final LyricsTapEditor editor;
  final LyricsUnitRef? selected;
  final Set<LyricsUnitRef> issueRefs;
  final Map<int, GlobalKey> lineKeys;
  final ScrollController scrollController;
  final void Function(LyricsUnitRef ref) onSelect;

  const _LyricsTimingList({
    required this.editor,
    required this.selected,
    required this.issueRefs,
    required this.lineKeys,
    required this.scrollController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    var lines = editor.lyrics.lineList;
    var cursor = editor.cursorUnit;
    var theme = Theme.of(context);
    var scheme = theme.colorScheme;
    var offset = editor.lyrics.offset;
    String time(int? ms) => ms == null ? '—' : formatLyricsTime(ms + offset);
    var perPart =
        editor.granularity == LyricsTimingGranularity.syllable ||
        editor.granularity == LyricsTimingGranularity.word;
    var pageMode = editor.granularity == LyricsTimingGranularity.page;
    return ListView.builder(
      controller: scrollController,
      itemCount: lines.length,
      itemBuilder: (context, l) {
        var line = lines[l];
        var lineRef = LyricsUnitRef(l);
        var lineIsCursor = cursor != null && cursor.line == l && cursor.isLine;
        var lineTime = pageMode ? line.pageMs.v : line.startMs.v;
        Widget chip({
          required LyricsUnitRef ref,
          required String label,
          required String? timeText,
          required bool isCursor,
          required bool timed,
        }) {
          var isSelected = ref == selected;
          var issue = issueRefs.contains(ref);
          return Padding(
            padding: const EdgeInsets.all(2),
            child: InkWell(
              onTap: () => onSelect(ref),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isCursor
                      ? scheme.primaryContainer
                      : timed
                      ? scheme.secondaryContainer.withValues(alpha: 0.5)
                      : null,
                  border: Border.all(
                    color: issue
                        ? scheme.error
                        : isSelected
                        ? scheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: theme.textTheme.bodyLarge),
                    if (timeText != null)
                      Text(timeText, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          key: lineKeys.putIfAbsent(l, GlobalKey.new),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: l > 0 && line.isNewPage
                ? Border(top: BorderSide(color: scheme.outline, width: 2))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Text('${l + 1}', style: theme.textTheme.labelSmall),
              ),
              if (!perPart)
                chip(
                  ref: lineRef,
                  label: pageMode && !line.isNewPage && l > 0
                      ? '·'
                      : (pageMode ? 'page' : 'line'),
                  timeText: time(lineTime),
                  isCursor: lineIsCursor,
                  timed: lineTime != null,
                ),
              Expanded(
                child: perPart
                    ? Wrap(
                        children: [
                          for (var p = 0; p < line.partList.length; p++)
                            chip(
                              ref: LyricsUnitRef(l, p),
                              label: line.partList[p].textOrEmpty.isEmpty
                                  ? '♪'
                                  : line.partList[p].textOrEmpty,
                              // The first part starts with the line.
                              timeText: time(
                                line.partList[p].startMs.v ??
                                    (p == 0 ? line.startMs.v : null),
                              ),
                              isCursor:
                                  cursor != null &&
                                  cursor.line == l &&
                                  cursor.part == p,
                              timed: editor.isTimed(LyricsUnitRef(l, p)),
                            ),
                          if (line.endMs.v != null)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '⏹ ${time(line.endMs.v)}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          line.text,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The granularity, the tap pad and the editing buttons.
class LyricsTapBar extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// The granularity, the tap pad and the editing buttons.
  const LyricsTapBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    var editor = controller.tapEditor;
    if (editor == null) {
      return const SizedBox.shrink();
    }
    var scheme = Theme.of(context).colorScheme;
    var cursor = editor.cursorUnit;
    var canNudge = controller.nudgeTarget != null;
    var padTextColor = cursor == null
        ? scheme.onSurfaceVariant
        : scheme.onPrimary;
    var next = cursor == null
        ? 'Done: everything is timed'
        : cursor.isLine
        ? 'Next: line ${cursor.line + 1}'
        : 'Next: '
              '${editor.lyrics.lineList[cursor.line].partList[cursor.part].textOrEmpty}';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                SegmentedButton<LyricsTimingGranularity>(
                  segments: const [
                    ButtonSegment(
                      value: LyricsTimingGranularity.syllable,
                      label: Text('Syllable'),
                    ),
                    ButtonSegment(
                      value: LyricsTimingGranularity.word,
                      label: Text('Word'),
                    ),
                    ButtonSegment(
                      value: LyricsTimingGranularity.line,
                      label: Text('Line'),
                    ),
                    ButtonSegment(
                      value: LyricsTimingGranularity.page,
                      label: Text('Page'),
                    ),
                  ],
                  selected: {editor.granularity},
                  onSelectionChanged: (selection) =>
                      controller.setGranularity(selection.first),
                ),
                FilterChip(
                  label: const Text('Hold mode'),
                  tooltip: 'Press for the start, release for the end',
                  selected: controller.holdMode,
                  onSelected: controller.setHoldMode,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => controller.tap(),
                    onTapUp: (_) => controller.release(),
                    onTapCancel: controller.release,
                    child: Container(
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cursor == null
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TAP (space)',
                            style: TextStyle(
                              color: padTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            next,
                            style: TextStyle(color: padTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: controller.endLine,
                  icon: const Icon(Icons.keyboard_return),
                  label: const Text('End line'),
                ),
                TextButton.icon(
                  onPressed: controller.pageHere,
                  icon: const Icon(Icons.auto_stories),
                  label: const Text('Page (P)'),
                ),
                TextButton.icon(
                  onPressed: controller.canUndo ? controller.undo : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                IconButton(
                  tooltip: '−100 ms (Shift+,)',
                  onPressed: canNudge ? () => controller.nudge(-100) : null,
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                ),
                IconButton(
                  tooltip: '−10 ms (,)',
                  onPressed: canNudge ? () => controller.nudge(-10) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '+10 ms (.)',
                  onPressed: canNudge ? () => controller.nudge(10) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: '+100 ms (Shift+.)',
                  onPressed: canNudge ? () => controller.nudge(100) : null,
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                ),
                TextButton.icon(
                  onPressed: canNudge ? controller.setSelectedToNow : null,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Set to now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A save button shown while there are changes not saved yet.
class LyricsEditorSaveButton extends StatelessWidget {
  /// The controller.
  final LyricsEditorController controller;

  /// A save button.
  const LyricsEditorSaveButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.dirty
          ? IconButton(
              tooltip: 'Save now',
              icon: const Icon(Icons.save),
              onPressed: () => unawaited(controller.save()),
            )
          : const SizedBox.shrink(),
    );
  }
}
