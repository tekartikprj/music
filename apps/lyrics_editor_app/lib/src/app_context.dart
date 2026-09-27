/// What the screens share: the local database, the settings, the opener and
/// the players.
library;

import 'dart:typed_data';

import 'package:fs_shim/fs.dart';
import 'package:idb_shim/sdb.dart';

import 'data/lyrics_app_db.dart';
import 'data/lyrics_opener.dart';
import 'player/lyrics_players.dart';

/// What the screens share.
class LyricsAppContext {
  /// The local database (drafts, recents, settings).
  final LyricsAppDb db;

  /// The latency settings.
  final LyricsAppSettings settings;

  /// The file system of the user's files, null on the web.
  final FileSystem? fs;

  /// Opens documents.
  final LyricsOpener opener;

  /// Creates the player of a document.
  final LyricsPlayerFactory createPlayer;

  LyricsAppContext._({
    required this.db,
    required this.settings,
    required this.fs,
    required this.createPlayer,
  }) : opener = LyricsOpener(fs: fs);

  /// Open the database of [sdbFactory] and load the settings.
  static Future<LyricsAppContext> init({
    required SdbFactory sdbFactory,
    FileSystem? fs,
    LyricsPlayerFactory createPlayer = createLyricsPlayer,
  }) async {
    var db = await LyricsAppDb.open(sdbFactory);
    return LyricsAppContext._(
      db: db,
      settings: await db.loadSettings(),
      fs: fs,
      createPlayer: createPlayer,
    );
  }

  /// Close.
  Future<void> close() => db.close();
}

/// A file picked or dropped, as the opener reads it: from its path on
/// desktop (so the files next to it pair), from its content otherwise.
LyricsOpenedFile lyricsOpenedFileOf(
  LyricsAppContext appContext, {
  required String name,
  String? path,
  required Future<List<int>> Function() readAsBytes,
}) {
  var fs = appContext.fs;
  if (fs != null && path != null && path.isNotEmpty) {
    return LyricsOpenedFile.fs(fs, path);
  }
  return LyricsOpenedFile(
    name: name,
    readAsBytes: () async => _asUint8List(await readAsBytes()),
  );
}

Uint8List _asUint8List(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
