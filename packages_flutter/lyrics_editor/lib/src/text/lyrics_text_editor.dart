/// The lyrics text: typed, pasted, or imported from a file (LRC, enhanced
/// LRC, SRT/WebVTT, ChordPro, text); exported as LRC or text.
///
/// The text is edited in the lyrics text format (a line per line, a blank
/// line for a new page, `|` between syllables, `[C]` chords); the times are
/// not part of it and are kept across the edit (`mergeLyricsTiming`).
/// Pasting a whole LRC or subtitles file imports it with its times.
///
/// Or, in the LRC mode ([LyricsTextFormat.lrc]), the text is the LRC itself,
/// its times included (`|` still splits the syllables not timed yet); what
/// an LRC cannot say (chords, sections, page times) is kept across the edit
/// (`mergeLyricsExtras`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekaly_file_picker/file_picker.dart';
import 'package:tekaly_lyrics_view/lyrics_view.dart';

import '../lyrics_editor_dialogs.dart';
import '../lyrics_editor_host.dart';

/// What the lyrics text format is, for the help.
const lyricsTextHelp = '''
One line per lyrics line, a blank line starts a new page.
| splits the syllables of a word: ê|tre heu|reux (not shown).
[C] puts a chord on what follows: Il en faut [C]peu.
[Chorus] alone on a line names the section up to the next blank line.
Pasting a whole LRC, SRT or WebVTT file imports it with its times.''';

/// What the LRC format is, for the help of the LRC mode.
const lyricsLrcHelp = '''
[mm:ss.xx] before a line: when it starts; alone on a line: when the line before ends.
<mm:ss.xx> inside a line: when the word or syllable after it starts.
| splits the syllables of a word: ê|tre heu|reux (not shown).
A blank line starts a new page. A line without a time is kept, to be timed.''';

/// What the text of the editor is written and read in.
enum LyricsTextFormat {
  /// The lyrics text format (`|` syllables, `[C]` chords, sections): the
  /// times are not part of the text and are kept across the edit.
  text,

  /// LRC: the times are part of the text (`|` splits the syllables not timed
  /// yet); chords, sections and page times are kept across the edit.
  lrc,
}

/// The extensions of the lyrics files the editor imports.
const lyricsFileExtensions = [
  'lrc',
  'srt',
  'vtt',
  'cho',
  'chopro',
  'chordpro',
  'crd',
  'txt',
];

/// The state of the text editor: the text, and the lyrics it started from
/// (their times are what [lyricsOfText] keeps in the text format, their
/// chords in the LRC one).
class LyricsTextController extends ChangeNotifier {
  /// The text.
  final text = TextEditingController();

  /// What the text is written and read in.
  final LyricsTextFormat format;

  /// The lyrics the text started from (loaded or imported).
  CvLyrics? base;

  /// Where the lyrics were imported from (a file name), if any.
  String? sourceName;

  /// An id of the source given by the host (a Drive file), if any.
  String? sourceId;

  /// The title of the file imported, if it had one.
  String? importedTitle;

  /// The artist of the file imported, if it had one.
  String? importedArtist;

  /// True when the text changed since it was loaded or saved.
  var dirty = false;

  var _settingText = false;

  /// The text of [lyrics], in the text [format].
  LyricsTextController({
    CvLyrics? lyrics,
    this.sourceName,
    this.format = LyricsTextFormat.text,
  }) {
    reset(lyrics);
    text.addListener(_onText);
  }

  /// True in the LRC mode.
  bool get isLrc => format == LyricsTextFormat.lrc;

  /// [lyrics] written in the [format].
  String formatLyrics(CvLyrics lyrics) => isLrc
      ? formatLrcLyrics(lyrics, syllables: true)
      : formatLyricsText(lyrics);

  void _onText() {
    if (!_settingText && !dirty) {
      dirty = true;
      notifyListeners();
    }
  }

  void _setText(String value) {
    _settingText = true;
    text.text = value;
    _settingText = false;
  }

  /// Start again from [lyrics] (loaded or saved): not dirty.
  void reset(CvLyrics? lyrics) {
    base = lyrics;
    _setText(lyrics == null ? '' : formatLyrics(lyrics));
    dirty = false;
    notifyListeners();
  }

  /// What the text says.
  ///
  /// In the text format, with the times of [base] where they still apply,
  /// or an import when it is a whole LRC/subtitles file. In the LRC mode,
  /// the times are the ones of the text (plain lines are untimed), the
  /// chords, sections and page times of [base] kept where they still apply.
  /// A `[ti:]` or `[ar:]` tag of the text is noted in [importedTitle] and
  /// [importedArtist].
  CvLyrics lyricsOfText() {
    var content = text.text;
    var format = detectLyricsFormat(content);
    var base = this.base;
    if (isLrc) {
      var imported = importLyrics(content, format: format);
      _noteTags(imported);
      var edited = imported.lyrics;
      return base == null ? edited : mergeLyricsExtras(base, edited);
    }
    if (format != LyricsFormat.text) {
      var imported = importLyrics(content, format: format);
      _noteTags(imported);
      return imported.lyrics;
    }
    var edited = parseLyricsText(content).lyrics;
    return base == null ? edited : mergeLyricsTiming(base, edited);
  }

  void _noteTags(LyricsImport imported) {
    if (imported.title != null) {
      importedTitle = imported.title;
    }
    if (imported.artist != null) {
      importedArtist = imported.artist;
    }
  }

  /// The text replaced by [imported], its times kept.
  void setImported(LyricsImport imported, {String? name, String? sourceId}) {
    base = imported.lyrics;
    sourceName = name;
    this.sourceId = sourceId;
    importedTitle = imported.title;
    importedArtist = imported.artist;
    _setText(formatLyrics(imported.lyrics));
    dirty = true;
    notifyListeners();
  }

  /// A short description of [lyrics]: lines, timing, chords.
  static String describe(CvLyrics lyrics) {
    var timing = lyrics.hasPartTiming
        ? 'timed to the syllable'
        : lyrics.isTimed
        ? 'timed by line'
        : 'not timed';
    return '${lyrics.lineList.length} line(s), $timing'
        '${lyrics.hasChords ? ', with chords' : ''}';
  }

  /// What the lyrics are: the status line of the editor.
  String get status {
    var base = this.base;
    if (base == null || base.isEmpty) {
      return 'No lyrics yet';
    }
    return '${describe(base)}'
        '${sourceName == null ? '' : ' · from $sourceName'}';
  }

  /// Ask before replacing lyrics that are there.
  Future<bool> confirmReplace(BuildContext context) async {
    if (text.text.trim().isEmpty) {
      return true;
    }
    return await lyricsEditorConfirm(
      context,
      title: 'Replace the lyrics',
      message: 'Replace the current lyrics (and their times) by the file?',
    );
  }

  /// Import [content] read from the file [name].
  LyricsImport importContent(
    BuildContext context,
    String content, {
    required String name,
    String? sourceId,
  }) {
    var imported = importLyrics(content, fileName: name);
    setImported(imported, name: name, sourceId: sourceId);
    lyricsEditorSnackBar(
      context,
      '${imported.lyrics.lineList.length} line(s) imported, '
      '${describe(imported.lyrics).split(', ')[1]}',
    );
    return imported;
  }

  /// Pick a lyrics file (of the [allowedExtensions]) and import it, null
  /// when cancelled.
  Future<LyricsImport?> importFile(
    BuildContext context, {
    List<String> allowedExtensions = lyricsFileExtensions,
  }) async {
    if (!await confirmReplace(context)) {
      return null;
    }
    var file = await tekalyFilePicker.pickCustomFile(
      allowedExtensions: allowedExtensions,
      dialogTitle: 'Lyrics file',
    );
    if (file == null || !context.mounted) {
      return null;
    }
    var content = decodeLyricsBytes(await file.readAsBytes());
    if (!context.mounted) {
      return null;
    }
    return importContent(context, content, name: file.name);
  }

  /// Save the lyrics as an LRC file ([fileName] without extension), or copy
  /// it to the clipboard when there is no save dialog.
  Future<void> exportLrc(
    BuildContext context, {
    required String fileName,
    String? title,
    String? artist,
  }) async {
    var lrc = formatLrcLyrics(lyricsOfText(), title: title, artist: artist);
    try {
      await tekalyFilePicker.saveFile(
        fileName: '$fileName.lrc',
        bytes: Uint8List.fromList(utf8.encode(lrc)),
        mimeType: 'text/plain',
        dialogTitle: 'Save the LRC file',
      );
    } catch (e) {
      // No save dialog on this platform: the clipboard then.
      await Clipboard.setData(ClipboardData(text: lrc));
      if (context.mounted) {
        lyricsEditorSnackBar(context, 'LRC copied to the clipboard');
      }
    }
  }

  /// Copy the lyrics to the clipboard, as LRC or as text.
  Future<void> copy(BuildContext context, {required bool lrc}) async {
    var lyrics = lyricsOfText();
    await Clipboard.setData(
      ClipboardData(
        text: lrc ? formatLrcLyrics(lyrics) : formatLyricsText(lyrics),
      ),
    );
    if (context.mounted) {
      lyricsEditorSnackBar(context, lrc ? 'LRC copied' : 'Text copied');
    }
  }

  @override
  void dispose() {
    text.removeListener(_onText);
    text.dispose();
    super.dispose();
  }
}

/// A file name made of [name]: its extension dropped, the characters files
/// cannot hold replaced.
String lyricsFileBaseName(String? name) {
  var base = (name ?? 'lyrics').trim();
  var dot = base.lastIndexOf('.');
  if (dot > 0) {
    base = base.substring(0, dot);
  }
  return base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// The text editor body: the status, the help, the text.
class LyricsTextEditor extends StatelessWidget {
  /// The controller.
  final LyricsTextController controller;

  /// The help shown under the status ([lyricsTextHelp] by default,
  /// [lyricsLrcHelp] in the LRC mode; a host offering fewer formats says so
  /// here).
  final String? help;

  /// The text editor body.
  const LyricsTextEditor({super.key, required this.controller, this.help});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListTile(
            title: Text(controller.status),
            subtitle: Text(
              help ?? (controller.isLrc ? lyricsLrcHelp : lyricsTextHelp),
            ),
            isThreeLine: true,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: controller.text,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: controller.isLrc
                    ? 'Type or paste the LRC'
                    : 'Type or paste the lyrics',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Import a lyrics file.
class LyricsTextImportButton extends StatelessWidget {
  /// The controller.
  final LyricsTextController controller;

  /// The file extensions offered ([lyricsFileExtensions] by default).
  final List<String> allowedExtensions;

  /// Import a lyrics file.
  const LyricsTextImportButton({
    super.key,
    required this.controller,
    this.allowedExtensions = lyricsFileExtensions,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Import a file',
      icon: const Icon(Icons.file_open),
      onPressed: () => unawaited(
        controller.importFile(context, allowedExtensions: allowedExtensions),
      ),
    );
  }
}

/// The text menu: save as LRC, copy as LRC or text, plus the [actions] of
/// the host.
class LyricsTextMenuButton extends StatelessWidget {
  /// The controller.
  final LyricsTextController controller;

  /// The file name of the export, without extension.
  final String fileName;

  /// The title written in the LRC export.
  final String? title;

  /// The artist written in the LRC export.
  final String? artist;

  /// The actions of the host, after the text ones.
  final List<LyricsEditorAction> actions;

  /// The text menu.
  const LyricsTextMenuButton({
    super.key,
    required this.controller,
    required this.fileName,
    this.title,
    this.artist,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      onSelected: (value) async {
        if (value is LyricsEditorAction) {
          await value.onSelected(context);
          return;
        }
        switch (value) {
          case 'export':
            await controller.exportLrc(
              context,
              fileName: fileName,
              title: title,
              artist: artist,
            );
          case 'copy_lrc':
            await controller.copy(context, lrc: true);
          case 'copy_text':
            await controller.copy(context, lrc: false);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'export', child: Text('Save as LRC…')),
        const PopupMenuItem(value: 'copy_lrc', child: Text('Copy as LRC')),
        const PopupMenuItem(value: 'copy_text', child: Text('Copy as text')),
        for (var action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }
}
