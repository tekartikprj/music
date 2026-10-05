/// The home screen: open files (or drop them), paste a YouTube link or
/// lyrics, start from nothing, or reopen a recent document.
library;

import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_file_picker/file_picker.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import '../app_context.dart';
import '../data/lyrics_app_db.dart';
import '../data/lyrics_opener.dart';
import '../samples/lyrics_samples.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

/// The name of the app, until it gets one (see the spec, open question 2).
const lyricsEditorAppName = 'Lyrics editor';

/// The home screen.
class LyricsHomeScreen extends StatefulWidget {
  /// What the screens share.
  final LyricsAppContext appContext;

  /// The home screen.
  const LyricsHomeScreen({super.key, required this.appContext});

  @override
  State<LyricsHomeScreen> createState() => _LyricsHomeScreenState();
}

class _LyricsHomeScreenState extends State<LyricsHomeScreen> {
  LyricsAppContext get appContext => widget.appContext;

  var _recents = <LyricsRecent>[];
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecents());
  }

  Future<void> _loadRecents() async {
    var recents = await appContext.db.getRecents();
    if (mounted) {
      setState(() => _recents = recents);
    }
  }

  Future<void> _edit(LyricsOpenedDocument? opened, {String? failure}) async {
    if (opened == null) {
      if (failure != null && mounted) {
        lyricsEditorSnackBar(context, failure);
      }
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            LyricsEditorScreen(appContext: appContext, opened: opened),
      ),
    );
    await _loadRecents();
  }

  Future<void> _openFiles(List<LyricsOpenedFile> files) async {
    try {
      var opened = await appContext.opener.openFiles(files);
      await _edit(opened, failure: 'Neither a lyrics nor an audio file');
    } catch (e) {
      if (mounted) {
        lyricsEditorSnackBar(context, 'Cannot open: $e');
      }
    }
  }

  Future<void> _pickFiles() async {
    var picked = await tekalyFilePicker.pickFiles(
      dialogTitle: 'Open a lyrics file, its audio, or both',
    );
    if (picked.isEmpty) {
      return;
    }
    await _openFiles([
      for (var file in picked)
        lyricsOpenedFileOf(
          appContext,
          name: file.name,
          path: file.path,
          readAsBytes: file.readAsBytes,
        ),
    ]);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    await _openFiles([
      for (var file in details.files)
        lyricsOpenedFileOf(
          appContext,
          name: file.name,
          path: file.path,
          readAsBytes: file.readAsBytes,
        ),
    ]);
  }

  Future<void> _pasteLink() async {
    var url = await lyricsEditorPromptText(
      context,
      title: 'YouTube link',
      label: 'A video link (t= gives the start)',
    );
    if (url == null || url.isEmpty) {
      return;
    }
    await _edit(
      appContext.opener.openYoutube(url),
      failure: 'Not a YouTube video link',
    );
  }

  Future<void> _pasteText() async {
    var controller = TextEditingController();
    var text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste the lyrics'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 12,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Text, LRC, SRT, ChordPro…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null) {
      await _edit(appContext.opener.newDocument(text: text));
    }
  }

  Future<void> _openSample(LyricsSampleSong song) async {
    await _openFiles(await loadLyricsSampleFiles(song));
  }

  Future<void> _openRecent(LyricsRecent recent) async {
    var opened = await appContext.opener.openRecent(recent);
    await _edit(
      opened,
      failure: appContext.fs == null
          ? 'Open its files again (a browser cannot reopen them)'
          : 'Its files are gone',
    );
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _dragging
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.lyrics_outlined, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Drop a lyrics file (LRC, text, ChordPro, SRT) and its audio '
                'here: files with the same name go together.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open files…'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pasteLink,
                    icon: const Icon(Icons.smart_display),
                    label: const Text('YouTube link…'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pasteText,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste lyrics…'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _edit(appContext.opener.newDocument()),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('New, no media'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_recents.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Recent', style: theme.textTheme.titleMedium),
          for (var recent in _recents)
            ListTile(
              leading: Icon(
                recent.youtubeUrl != null
                    ? Icons.smart_display
                    : Icons.lyrics_outlined,
              ),
              title: Text(recent.name),
              subtitle: Text(
                recent.lyricsPath ?? recent.youtubeUrl ?? recent.key,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _openRecent(recent),
              trailing: IconButton(
                tooltip: 'Forget',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await appContext.db.removeRecent(recent.key);
                  await _loadRecents();
                },
              ),
            ),
        ],
        const SizedBox(height: 24),
        Text('Samples', style: theme.textTheme.titleMedium),
        for (var song in lyricsSampleSongs)
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(song.title),
            subtitle: Text(song.description),
            onTap: () => _openSample(song),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(lyricsEditorAppName),
        actions: [
          IconButton(
            tooltip: 'Latency',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    LyricsSettingsScreen(settings: appContext.settings),
              ),
            ),
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: _onDrop,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      ),
    );
  }
}
