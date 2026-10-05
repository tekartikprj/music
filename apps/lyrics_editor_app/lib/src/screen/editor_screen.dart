/// The editor: one screen, three tabs (text, timing, preview) on one
/// document, one player and one undo history.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_file_picker/file_picker.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import '../app_context.dart';
import '../data/lyrics_app_db.dart';
import '../data/lyrics_file_format.dart';
import '../data/lyrics_opener.dart';
import 'settings_screen.dart';

/// The tabs of the editor.
enum LyricsEditorTab {
  /// The text.
  text,

  /// The timing.
  timing,

  /// The preview.
  preview,
}

/// The editor of [opened].
class LyricsEditorScreen extends StatefulWidget {
  /// What the screens share.
  final LyricsAppContext appContext;

  /// The document opened.
  final LyricsOpenedDocument opened;

  /// The editor of [opened].
  const LyricsEditorScreen({
    super.key,
    required this.appContext,
    required this.opened,
  });

  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen>
    with SingleTickerProviderStateMixin {
  LyricsAppContext get appContext => widget.appContext;

  late LyricsOpenedDocument _opened = widget.opened;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _text = LyricsTextController();
  LyricsPlayer? _player;
  LyricsEditorController? _controller;
  String? _error;

  /// True when the document differs from its file.
  var _fileDirty = false;

  /// The formats whose losses were accepted already.
  final _lossesAccepted = <LyricsFileFormat>{};

  var _previewSongbook = false;
  var _previewChords = true;
  var _previewTranspose = 0;
  var _previousTab = 0;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      var document = _opened.document;
      var draft = await appContext.db.getDraft(_opened.key);
      if (draft != null && draft.document != document) {
        var modified = _opened.lyricsModified;
        var newer = modified == null || draft.updated.isAfter(modified);
        if (newer && mounted && await _askRestore(draft)) {
          document = draft.document;
          _fileDirty = true;
        } else {
          await appContext.db.deleteDraft(_opened.key);
        }
      }
      LyricsPlayer player;
      try {
        player = await appContext.createPlayer(_opened);
      } catch (e) {
        player = ClockLyricsPlayer();
        if (mounted) {
          lyricsEditorSnackBar(context, 'Cannot play the media: $e');
        }
      }
      if (_disposed) {
        await player.dispose();
        return;
      }
      var controller = LyricsEditorController(
        document: document,
        player: player,
        settings: appContext.settings,
        store: LyricsDraftStore(
          appContext.db,
          _opened.key,
          onSaved: () {
            if (!_disposed && !_fileDirty) {
              setState(() => _fileDirty = true);
            }
          },
        ),
      );
      _text.reset(controller.lyrics);
      await appContext.db.addRecent(_opened.toRecent());
      setState(() {
        _player = player;
        _controller = controller;
      });
      _tabs.index = controller.hasLyrics
          ? LyricsEditorTab.timing.index
          : LyricsEditorTab.text.index;
    } catch (e) {
      if (!_disposed) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<bool> _askRestore(LyricsDraft draft) async {
    var time = TimeOfDay.fromDateTime(draft.updated).format(context);
    var day = MaterialLocalizations.of(context).formatShortDate(draft.updated);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restore the draft?'),
            content: Text(
              'Changes saved on $day at $time were never written to the '
              'file.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- Text tab ---

  void _onTab() {
    // As soon as the tab changes (its animation is not waited for).
    var index = _tabs.index;
    if (index == _previousTab) {
      return;
    }
    if (_previousTab == LyricsEditorTab.text.index) {
      _applyText();
    }
    if (index == LyricsEditorTab.text.index && !_text.dirty) {
      var controller = _controller;
      if (controller != null) {
        _text.reset(controller.lyrics);
      }
    }
    _previousTab = index;
  }

  /// The text edits applied to the document (one undo step).
  void _applyText() {
    var controller = _controller;
    if (controller == null || !_text.dirty) {
      return;
    }
    var lyrics = _text.lyricsOfText();
    var title = _text.importedTitle;
    var artist = _text.importedArtist;
    controller.setLyrics(lyrics);
    if ((title != null && controller.document.title.v == null) ||
        (artist != null && controller.document.artist.v == null)) {
      controller.updateDocument((document) {
        document.title.v ??= title;
        document.artist.v ??= artist;
      });
    }
    _text.reset(controller.lyrics);
  }

  // --- Saving ---

  Future<void> _save() async {
    var controller = _controller;
    if (controller == null) {
      return;
    }
    _applyText();
    await controller.save();
    var file = _opened.lyricsFile;
    var format = _opened.format;
    var fs = appContext.fs;
    var path = file?.path;
    if (file == null || path == null || fs == null || format == null) {
      await _saveAs();
      return;
    }
    if (!format.writable) {
      // Subtitles are saved as LRC next to them.
      format = LyricsFileFormat.lrc;
      path = fs.path.join(
        fs.path.dirname(path),
        lyricsFileNameIn(file.name, format),
      );
    }
    var document = controller.document;
    var keepNative = false;
    var losses = lyricsFormatLosses(document, format);
    if (losses.isNotEmpty && !_lossesAccepted.contains(format)) {
      if (!mounted) {
        return;
      }
      var choice = await _askLosses(format, losses, file.name);
      if (choice == null) {
        return;
      }
      _lossesAccepted.add(format);
      keepNative = choice;
    }
    await fs.file(path).writeAsString(writeLyricsDocument(document, format));
    if (keepNative) {
      await fs
          .file(
            fs.path.join(
              fs.path.dirname(path),
              lyricsFileNameIn(file.name, LyricsFileFormat.native),
            ),
          )
          .writeAsString(
            writeLyricsDocument(document, LyricsFileFormat.native),
          );
    }
    await _saved(
      LyricsOpenedFile.fs(fs, path),
      format,
      modified: (await fs.file(path).stat()).modified,
    );
  }

  /// The document now written to [file] in [format].
  Future<void> _saved(
    LyricsOpenedFile file,
    LyricsFileFormat format, {
    DateTime? modified,
  }) async {
    var oldKey = _opened.key;
    _opened = _opened.savedAs(file, format, modified: modified);
    await appContext.db.deleteDraft(oldKey);
    if (_opened.key != oldKey) {
      await appContext.db.addRecent(_opened.toRecent());
    }
    if (mounted) {
      setState(() => _fileDirty = false);
      lyricsEditorSnackBar(context, 'Saved ${file.name}');
    }
  }

  /// null: cancel, false: save, true: save and keep a native copy.
  Future<bool?> _askLosses(
    LyricsFileFormat format,
    List<String> losses,
    String name,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Saving as ${format.extension.toUpperCase()}'),
      content: Text(
        'This format does not keep ${losses.join(', ')}. A '
        '${lyricsFileNameIn(name, LyricsFileFormat.native)} next to it '
        'keeps everything.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Save'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save and keep both'),
        ),
      ],
    ),
  );

  Future<LyricsFileFormat?> _askFormat(String title) =>
      showDialog<LyricsFileFormat>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (var (format, label) in [
              (LyricsFileFormat.lrc, 'LRC (times, for any karaoke player)'),
              (LyricsFileFormat.text, 'Text / ChordPro (chords, no time)'),
              (LyricsFileFormat.native, 'Lyrics document (everything)'),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(format),
                child: Text(label),
              ),
          ],
        ),
      );

  /// Save to a new file; [export] saves a copy, the document keeps its own.
  Future<void> _saveAs({bool export = false}) async {
    var controller = _controller;
    if (controller == null) {
      return;
    }
    _applyText();
    var format = await _askFormat(export ? 'Export as' : 'Save as');
    if (format == null) {
      return;
    }
    var document = controller.document;
    var base = _opened.lyricsFile?.name ?? '${document.title.v ?? 'lyrics'}.x';
    var name = lyricsFileNameIn(base, format);
    var uri = await tekalyFilePicker.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(
        utf8.encode(writeLyricsDocument(document, format)),
      ),
      mimeType: format == LyricsFileFormat.native
          ? 'application/json'
          : 'text/plain',
      dialogTitle: export ? 'Export the lyrics' : 'Save the lyrics',
    );
    if (export || !mounted) {
      return;
    }
    var fs = appContext.fs;
    if (uri != null && uri.scheme == 'file' && fs != null) {
      var path = uri.toFilePath();
      await _saved(
        LyricsOpenedFile.fs(fs, path),
        format,
        modified: (await fs.file(path).stat()).modified,
      );
    } else if (uri != null || fs == null) {
      // Downloaded (the web): the draft is what reopens it.
      setState(() => _fileDirty = false);
    }
  }

  Future<void> _copy({required bool lrc}) async {
    var controller = _controller;
    if (controller == null) {
      return;
    }
    _applyText();
    var document = controller.document;
    await Clipboard.setData(
      ClipboardData(
        text: writeLyricsDocument(
          document,
          lrc ? LyricsFileFormat.lrc : LyricsFileFormat.text,
        ),
      ),
    );
    if (mounted) {
      lyricsEditorSnackBar(context, lrc ? 'LRC copied' : 'Text copied');
    }
  }

  // --- Tracks ---

  Future<void> _nextTrack() async {
    var player = _player;
    if (player is! LyricsPlayerTracks) {
      return;
    }
    var tracks = (player as LyricsPlayerTracks).tracks;
    if (tracks.length < 2) {
      return;
    }
    var index = tracks.indexOf((player as LyricsPlayerTracks).track ?? '');
    await (player as LyricsPlayerTracks).selectTrack(
      tracks[(index + 1) % tracks.length],
    );
    if (mounted) {
      setState(() {});
    }
  }

  // --- Keys ---

  bool get _inTextField =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    var keyboard = HardwareKeyboard.instance;
    var command = keyboard.isControlPressed || keyboard.isMetaPressed;
    var key = event.logicalKey;
    var controller = _controller;
    if (command && key == LogicalKeyboardKey.keyS) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    if (command) {
      var tab = switch (key) {
        LogicalKeyboardKey.digit1 => LyricsEditorTab.text,
        LogicalKeyboardKey.digit2 => LyricsEditorTab.timing,
        LogicalKeyboardKey.digit3 => LyricsEditorTab.preview,
        _ => null,
      };
      if (tab != null) {
        _tabs.animateTo(tab.index);
        return KeyEventResult.handled;
      }
    }
    // The text field keeps its own keys (its own undo while typing).
    if (_inTextField || controller == null) {
      return KeyEventResult.ignored;
    }
    if (command && key == LogicalKeyboardKey.keyZ) {
      keyboard.isShiftPressed ? controller.redo() : controller.undo();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    if (!command && key == LogicalKeyboardKey.keyV) {
      unawaited(_nextTrack());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _disposed = true;
    _tabs.removeListener(_onTab);
    _applyText();
    // Saves the draft if needed: it is offered back next time.
    _controller?.dispose();
    unawaited(_player?.dispose());
    _text.dispose();
    _tabs.dispose();
    super.dispose();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    var controller = _controller;
    var title =
        controller?.document.title.v ??
        _opened.document.title.v ??
        _opened.name;
    return Focus(
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, overflow: TextOverflow.ellipsis),
              Text(
                '${_opened.description}${_fileDirty ? ' · not saved' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Text'),
              Tab(text: 'Timing'),
              Tab(text: 'Preview'),
            ],
          ),
          actions: [
            if (controller != null) ...[
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Undo (Ctrl+Z)',
                      icon: const Icon(Icons.undo),
                      onPressed: controller.canUndo ? controller.undo : null,
                    ),
                    IconButton(
                      tooltip: 'Redo (Shift+Ctrl+Z)',
                      icon: const Icon(Icons.redo),
                      onPressed: controller.canRedo ? controller.redo : null,
                    ),
                  ],
                ),
              ),
              _TrackButton(player: _player, onChanged: () => setState(() {})),
              IconButton(
                tooltip: 'Save (Ctrl+S)',
                icon: Icon(_fileDirty ? Icons.save : Icons.save_outlined),
                onPressed: _save,
              ),
              LyricsTimingMenuButton(
                controller: controller,
                actions: [
                  LyricsEditorAction(
                    label: 'Save as…',
                    onSelected: (_) => _saveAs(),
                  ),
                  LyricsEditorAction(
                    label: 'Export a copy…',
                    onSelected: (_) => _saveAs(export: true),
                  ),
                  LyricsEditorAction(
                    label: 'Copy as LRC',
                    onSelected: (_) => _copy(lrc: true),
                  ),
                  LyricsEditorAction(
                    label: 'Copy as text',
                    onSelected: (_) => _copy(lrc: false),
                  ),
                  LyricsEditorAction(
                    label: 'Latency…',
                    onSelected: (context) => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            LyricsSettingsScreen(settings: appContext.settings),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    var controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: _tabs,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _WithTransport(
          controller: controller,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: LyricsTextImportButton(controller: _text),
              ),
              Expanded(child: LyricsTextEditor(controller: _text)),
            ],
          ),
        ),
        LyricsTimingKeys(
          controller: controller,
          child: LyricsTimingEditor(
            controller: controller,
            noLyrics: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('There are no lyrics to time yet.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        _tabs.animateTo(LyricsEditorTab.text.index),
                    child: const Text('Type or paste the lyrics'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _WithTransport(controller: controller, child: _buildPreview(context)),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    var controller = _controller!;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Karaoke')),
                ButtonSegment(value: true, label: Text('Songbook')),
              ],
              selected: {_previewSongbook},
              onSelectionChanged: (selection) =>
                  setState(() => _previewSongbook = selection.first),
            ),
            if (_previewSongbook) ...[
              FilterChip(
                label: const Text('Chords'),
                selected: _previewChords,
                onSelected: (value) => setState(() => _previewChords = value),
              ),
              IconButton(
                tooltip: 'Transpose down',
                icon: const Icon(Icons.remove),
                onPressed: () => setState(() => _previewTranspose--),
              ),
              Text('$_previewTranspose'),
              IconButton(
                tooltip: 'Transpose up',
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _previewTranspose++),
              ),
            ],
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _previewSongbook
                ? ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => SingleChildScrollView(
                      child: SongbookLyricsView(
                        lyrics: controller.lyrics,
                        showChords: _previewChords,
                        transpose: _previewTranspose,
                      ),
                    ),
                  )
                : LyricsKaraokePreview(controller: controller),
          ),
        ),
      ],
    );
  }
}

/// [child] over the transport bar, so that every tab plays.
class _WithTransport extends StatelessWidget {
  final LyricsEditorController controller;
  final Widget child;

  const _WithTransport({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        const Divider(height: 1),
        LyricsTransportBar(controller: controller),
      ],
    );
  }
}

/// The track menu, for a document with several tracks.
class _TrackButton extends StatelessWidget {
  final LyricsPlayer? player;
  final VoidCallback onChanged;

  const _TrackButton({required this.player, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    var player = this.player;
    if (player is! LyricsPlayerTracks) {
      return const SizedBox.shrink();
    }
    var tracks = (player as LyricsPlayerTracks).tracks;
    if (tracks.length < 2) {
      return const SizedBox.shrink();
    }
    var current = (player as LyricsPlayerTracks).track;
    return PopupMenuButton<String>(
      tooltip: 'Track (V)',
      icon: const Icon(Icons.queue_music),
      onSelected: (name) async {
        await (player as LyricsPlayerTracks).selectTrack(name);
        onChanged();
      },
      itemBuilder: (context) => [
        for (var name in tracks)
          PopupMenuItem(
            value: name,
            child: Text(
              name,
              style: name == current
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
      ],
    );
  }
}
