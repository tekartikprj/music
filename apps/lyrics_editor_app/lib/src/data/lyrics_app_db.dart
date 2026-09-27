/// What the app keeps locally: the drafts (the editor saves there, never
/// straight to the user's file), the recent documents and the settings.
library;

import 'package:flutter/foundation.dart';
import 'package:idb_shim/sdb.dart';
import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

/// The drafts, by document key.
final _draftStore = SdbStoreRef<String, SdbModel>('draft');

/// The recent documents, by document key.
final _recentStore = SdbStoreRef<String, SdbModel>('recent');

/// The settings, by name.
final _settingStore = SdbStoreRef<String, SdbModel>('setting');

/// How many recent documents are kept.
const lyricsRecentMax = 20;

/// A draft: the document as the editor last saved it.
class LyricsDraft {
  /// The document.
  final CvLyricsDocument document;

  /// When it was saved.
  final DateTime updated;

  /// A draft.
  const LyricsDraft(this.document, this.updated);
}

/// A recent document.
class LyricsRecent {
  /// Its key (a path on desktop, a name on the web).
  final String key;

  /// The name shown.
  final String name;

  /// The lyrics file path, if any (desktop).
  final String? lyricsPath;

  /// The media file paths (desktop).
  final List<String> mediaPaths;

  /// A YouTube link, if any.
  final String? youtubeUrl;

  /// When it was opened.
  final DateTime opened;

  /// A recent document.
  const LyricsRecent({
    required this.key,
    required this.name,
    this.lyricsPath,
    this.mediaPaths = const [],
    this.youtubeUrl,
    required this.opened,
  });

  Map<String, Object?> _toMap() => {
    'name': name,
    'lyricsPath': ?lyricsPath,
    if (mediaPaths.isNotEmpty) 'mediaPaths': mediaPaths,
    'youtubeUrl': ?youtubeUrl,
    'opened': opened.millisecondsSinceEpoch,
  };

  static LyricsRecent _fromMap(String key, Map map) => LyricsRecent(
    key: key,
    name: map['name'] as String? ?? key,
    lyricsPath: map['lyricsPath'] as String?,
    mediaPaths: (map['mediaPaths'] as List?)?.cast<String>() ?? const [],
    youtubeUrl: map['youtubeUrl'] as String?,
    opened: DateTime.fromMillisecondsSinceEpoch(
      (map['opened'] as num?)?.toInt() ?? 0,
    ),
  );
}

/// The local database of the app.
class LyricsAppDb {
  /// The database.
  final SdbDatabase db;

  LyricsAppDb._(this.db);

  /// Open the database [name] of [factory].
  static Future<LyricsAppDb> open(
    SdbFactory factory, {
    String name = 'lyrics_editor.db',
  }) async {
    var db = await factory.openDatabase(
      name,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(
          stores: [
            _draftStore.schema(),
            _recentStore.schema(),
            _settingStore.schema(),
          ],
        ),
      ),
    );
    return LyricsAppDb._(db);
  }

  // --- Drafts ---

  /// Save the draft of [key].
  Future<void> saveDraft(String key, CvLyricsDocument document) async {
    await _draftStore.record(key).put(db, {
      'document': document.toMap(),
      'updated': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// The draft of [key], null when there is none.
  Future<LyricsDraft?> getDraft(String key) async {
    var value = await _draftStore.record(key).getValue(db);
    var map = value?['document'];
    if (value == null || map is! Map) {
      return null;
    }
    return LyricsDraft(
      lyricsDocumentFromMap(map),
      DateTime.fromMillisecondsSinceEpoch(
        (value['updated'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Forget the draft of [key] (saved to its file, or discarded).
  Future<void> deleteDraft(String key) => _draftStore.record(key).delete(db);

  // --- Recent documents ---

  /// Remember [recent], the [lyricsRecentMax] most recent only.
  Future<void> addRecent(LyricsRecent recent) async {
    await _recentStore.record(recent.key).put(db, recent._toMap());
    var recents = await getRecents();
    for (var old in recents.skip(lyricsRecentMax)) {
      await _recentStore.record(old.key).delete(db);
    }
  }

  /// The recent documents, the most recent first.
  Future<List<LyricsRecent>> getRecents() async {
    var records = await _recentStore.findRecords(db);
    return [
      for (var record in records)
        LyricsRecent._fromMap(record.ref.key, record.value),
    ]..sort((a, b) => b.opened.compareTo(a.opened));
  }

  /// Forget [key].
  Future<void> removeRecent(String key) => _recentStore.record(key).delete(db);

  // --- Settings ---

  /// The latency settings, loaded.
  Future<LyricsAppSettings> loadSettings() async {
    Future<int?> get(String name) async =>
        ((await _settingStore.record(name).getValue(db))?['value'] as num?)
            ?.toInt();
    return LyricsAppSettings._(
      this,
      tapLatencyMs:
          await get('tapLatencyMs') ?? lyricsEditorDefaultTapLatencyMs,
      audioLatencyMs: await get('audioLatencyMs') ?? 0,
    );
  }

  Future<void> _setSetting(String name, int value) =>
      _settingStore.record(name).put(db, {'value': value});

  /// Close.
  Future<void> close() => db.close();
}

/// The latency settings, kept in the app database.
class LyricsAppSettings implements LyricsEditorSettings {
  final LyricsAppDb _db;

  @override
  final ValueNotifier<int> tapLatencyMs;

  @override
  final ValueNotifier<int> audioLatencyMs;

  LyricsAppSettings._(
    this._db, {
    required int tapLatencyMs,
    required int audioLatencyMs,
  }) : tapLatencyMs = ValueNotifier(tapLatencyMs),
       audioLatencyMs = ValueNotifier(audioLatencyMs);

  @override
  Future<void> setTapLatencyMs(int value) async {
    tapLatencyMs.value = value;
    await _db._setSetting('tapLatencyMs', value);
  }

  @override
  Future<void> setAudioLatencyMs(int value) async {
    audioLatencyMs.value = value;
    await _db._setSetting('audioLatencyMs', value);
  }
}

/// The editor store of a document: its draft.
class LyricsDraftStore implements LyricsEditorStore {
  /// The database.
  final LyricsAppDb db;

  /// The document key.
  final String key;

  /// Called after each save (the document now differs from its file).
  final VoidCallback? onSaved;

  /// The draft of [key].
  LyricsDraftStore(this.db, this.key, {this.onSaved});

  @override
  Future<void> save(CvLyricsDocument document) async {
    await db.saveDraft(key, document);
    onSaved?.call();
  }

  @override
  Stream<CvLyricsDocument>? get remoteChanges => null;
}
