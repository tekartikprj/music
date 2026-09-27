/// Opening a document: picked or dropped files (a lyrics file, its media,
/// or both), a YouTube link, pasted text, a recent document.
library;

import 'dart:typed_data';

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:fs_shim/fs.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import 'lyrics_app_db.dart';
import 'lyrics_file_format.dart';
import 'lyrics_pairing.dart';

/// A file of a document: picked, dropped, or found next to one on disk.
class LyricsOpenedFile {
  /// Its name.
  final String name;

  /// Its path, when it has one (desktop).
  final String? path;

  /// Its content.
  final Future<Uint8List> Function() readAsBytes;

  /// A file.
  LyricsOpenedFile({required this.name, this.path, required this.readAsBytes});

  /// A file with its [bytes] at hand (picked on the web, dropped, a test).
  factory LyricsOpenedFile.bytes(
    String name,
    Uint8List bytes, {
    String? path,
  }) =>
      LyricsOpenedFile(name: name, path: path, readAsBytes: () async => bytes);

  /// The file [path] of [fs].
  factory LyricsOpenedFile.fs(FileSystem fs, String path) => LyricsOpenedFile(
    name: fs.path.basename(path),
    path: path,
    readAsBytes: () => fs.file(path).readAsBytes(),
  );

  @override
  String toString() => 'LyricsOpenedFile(${path ?? name})';
}

/// A media file of a document, with its track name.
class LyricsOpenedTrack {
  /// The track name (`song`, `vocals`, `no_vocals`, `instrumental`).
  final String name;

  /// The file.
  final LyricsOpenedFile file;

  /// A track.
  const LyricsOpenedTrack(this.name, this.file);

  @override
  String toString() => '$name: $file';
}

/// A document opened in the editor.
class LyricsOpenedDocument {
  /// The key of its draft and of its recent entry: the lyrics path on
  /// desktop, a name on the web, `youtube:<id>`, `untitled:<time>`.
  final String key;

  /// The name shown.
  final String name;

  /// The lyrics file, null when there was none (a new document).
  final LyricsOpenedFile? lyricsFile;

  /// The format of [lyricsFile].
  final LyricsFileFormat? format;

  /// The media files, the one timed first.
  final List<LyricsOpenedTrack> tracks;

  /// The YouTube video, if the media is one.
  final YtVideoSource? youtube;

  /// The YouTube link.
  final String? youtubeUrl;

  /// When the lyrics file was last written, when known (desktop).
  final DateTime? lyricsModified;

  /// The document read.
  final CvLyricsDocument document;

  /// A document opened.
  const LyricsOpenedDocument({
    required this.key,
    required this.name,
    required this.document,
    this.lyricsFile,
    this.format,
    this.tracks = const [],
    this.youtube,
    this.youtubeUrl,
    this.lyricsModified,
  });

  /// The same document, saved to [file] in [format] now.
  LyricsOpenedDocument savedAs(
    LyricsOpenedFile file,
    LyricsFileFormat format, {
    DateTime? modified,
  }) => LyricsOpenedDocument(
    key: file.path ?? file.name,
    name: file.name,
    document: document,
    lyricsFile: file,
    format: format,
    tracks: tracks,
    youtube: youtube,
    youtubeUrl: youtubeUrl,
    lyricsModified: modified,
  );

  /// What the title bar says: the lyrics file and the media.
  String get description {
    var media = youtube != null
        ? 'YouTube'
        : tracks.isEmpty
        ? 'no media'
        : tracks.first.file.name;
    return '${lyricsFile?.name ?? 'new lyrics'} + $media';
  }

  /// Its recent entry.
  LyricsRecent toRecent() => LyricsRecent(
    key: key,
    name: document.title.v ?? name,
    lyricsPath: lyricsFile?.path,
    mediaPaths: [for (var track in tracks) ?track.file.path],
    youtubeUrl: youtubeUrl,
    opened: DateTime.now(),
  );
}

/// Opens documents; [fs] is the file system of the user's files, null when
/// they have no path (the web: pairing then only among the files picked).
class LyricsOpener {
  /// The file system of the user's files.
  final FileSystem? fs;

  /// The opener.
  const LyricsOpener({this.fs});

  /// The document of [files] (a lyrics file, its media, or both): what goes
  /// with the first lyrics file (else the first media file), by name, among
  /// [files] and, on desktop, the files next to it. Null when there is
  /// neither a lyrics nor a media file.
  Future<LyricsOpenedDocument?> openFiles(List<LyricsOpenedFile> files) async {
    LyricsOpenedFile? opened;
    for (var kind in [LyricsFileKind.lyrics, LyricsFileKind.media]) {
      opened = files
          .where((file) => LyricsFileName.parse(file.name).kind == kind)
          .firstOrNull;
      if (opened != null) {
        break;
      }
    }
    if (opened == null) {
      return null;
    }
    var byName = <String, LyricsOpenedFile>{};
    var fs = this.fs;
    var path = opened.path;
    if (fs != null && path != null) {
      var dir = fs.path.dirname(path);
      try {
        await for (var entity in fs.directory(dir).list()) {
          if (await fs.isFile(entity.path)) {
            var file = LyricsOpenedFile.fs(fs, entity.path);
            byName[file.name] = file;
          }
        }
      } catch (_) {
        // Not listable: the files given only.
      }
    }
    for (var file in files) {
      byName[file.name] = file;
    }
    var pairing = pairLyricsFiles(opened.name, byName.keys);
    var lyricsFile = pairing.lyrics == null ? null : byName[pairing.lyrics!];
    var tracks = [
      for (var track in pairing.tracks)
        LyricsOpenedTrack(track.name, byName[track.fileName]!),
    ];
    return await _open(lyricsFile: lyricsFile, tracks: tracks, opened: opened);
  }

  Future<LyricsOpenedDocument> _open({
    required LyricsOpenedFile? lyricsFile,
    required List<LyricsOpenedTrack> tracks,
    required LyricsOpenedFile opened,
  }) async {
    CvLyricsDocument document;
    DateTime? modified;
    LyricsFileFormat? format;
    if (lyricsFile != null) {
      var content = decodeLyricsBytes(await lyricsFile.readAsBytes());
      document = readLyricsDocument(lyricsFile.name, content);
      format = lyricsFileFormatOf(lyricsFile.name);
      var fs = this.fs;
      var path = lyricsFile.path;
      if (fs != null && path != null) {
        try {
          modified = (await fs.file(path).stat()).modified;
        } catch (_) {}
      }
    } else {
      document = CvLyricsDocument.of(
        CvLyrics.of(const []),
        title: LyricsFileName.parse(opened.name).base,
      );
    }
    if (tracks.isNotEmpty) {
      document.media.v = CvLyricsMedia.file(
        tracks.first.file.name,
        tracks: [
          for (var track in tracks)
            CvLyricsTrack.of(track.name, track.file.name),
        ],
      );
    }
    var key =
        lyricsFile?.path ??
        lyricsFile?.name ??
        tracks.firstOrNull?.file.path ??
        opened.name;
    return LyricsOpenedDocument(
      key: key,
      name: lyricsFile?.name ?? opened.name,
      document: document,
      lyricsFile: lyricsFile,
      format: format,
      tracks: tracks,
      lyricsModified: modified,
    );
  }

  /// A document timed against the YouTube video of [url], null when it is
  /// not a video link.
  LyricsOpenedDocument? openYoutube(String url) {
    var source = parseYtSource(url);
    if (source is! YtVideoSource) {
      return null;
    }
    var document = CvLyricsDocument.of(CvLyrics.of(const []))
      ..media.v = CvLyricsMedia.youtube(source.videoId, url: url);
    return LyricsOpenedDocument(
      key: 'youtube:${source.videoId}',
      name: url,
      document: document,
      youtube: source,
      youtubeUrl: url,
    );
  }

  /// A new document, of the pasted [text] when given, with no media (a
  /// clock).
  LyricsOpenedDocument newDocument({String? text}) {
    var lyrics = text == null || text.trim().isEmpty
        ? CvLyrics.of(const [])
        : importLyrics(text).lyrics;
    var document = CvLyricsDocument.of(lyrics, title: 'Untitled')
      ..media.v = CvLyricsMedia.none();
    return LyricsOpenedDocument(
      key: 'untitled:${DateTime.now().millisecondsSinceEpoch}',
      name: 'Untitled',
      document: document,
    );
  }

  /// Open [recent] again: its files on desktop, its YouTube link; null when
  /// its files cannot be reached (the web: they must be picked again).
  Future<LyricsOpenedDocument?> openRecent(LyricsRecent recent) async {
    var url = recent.youtubeUrl;
    if (url != null && recent.lyricsPath == null) {
      return openYoutube(url);
    }
    var fs = this.fs;
    if (fs == null) {
      return null;
    }
    var files = [?recent.lyricsPath, ...recent.mediaPaths];
    var existing = <LyricsOpenedFile>[];
    for (var path in files) {
      if (await fs.isFile(path)) {
        existing.add(LyricsOpenedFile.fs(fs, path));
      }
    }
    return existing.isEmpty ? null : openFiles(existing);
  }
}
