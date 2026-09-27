/// Lyrics and media files paired by name: `X.lrc` goes with `X.mp3`,
/// `X-vocals.mp3` and `X-no_vocals.mp3`, whichever is opened first.
library;

/// The media extensions, in order of preference.
const lyricsMediaExtensions = [
  'mp3',
  'm4a',
  'ogg',
  'wav',
  'flac',
  'aac',
  'opus',
];

/// The lyrics extensions, in order of preference (compound ones first).
const lyricsDocumentExtensions = [
  'lyrics.json',
  'lyricsfile.yaml',
  'lrc',
  'cho',
  'chordpro',
  'chopro',
  'crd',
  'txt',
  'srt',
  'vtt',
];

/// The track suffixes of a media file name (`X-vocals.mp3`), in the order
/// the tracks are listed.
const lyricsTrackSuffixes = ['vocals', 'no_vocals', 'instrumental'];

/// What a file is, by its name.
enum LyricsFileKind {
  /// A lyrics file.
  lyrics,

  /// An audio file.
  media,

  /// Anything else.
  other,
}

/// A file name split into what pairing needs.
class LyricsFileName {
  /// The name.
  final String name;

  /// The name without its extension (and without its track suffix for a
  /// media file): what lyrics and media share.
  final String base;

  /// The extension, lower case, compound for the lyrics formats
  /// (`lyrics.json`).
  final String extension;

  /// What the file is.
  final LyricsFileKind kind;

  /// The track suffix of a media file (`vocals`, `no_vocals`,
  /// `instrumental`), null for the plain one.
  final String? track;

  const LyricsFileName._(
    this.name,
    this.base,
    this.extension,
    this.kind,
    this.track,
  );

  /// Split [name].
  factory LyricsFileName.parse(String name) {
    var lower = name.toLowerCase();
    for (var extension in lyricsDocumentExtensions) {
      if (lower.endsWith('.$extension') &&
          lower.length > extension.length + 1) {
        return LyricsFileName._(
          name,
          name.substring(0, name.length - extension.length - 1),
          extension,
          LyricsFileKind.lyrics,
          null,
        );
      }
    }
    var dot = name.lastIndexOf('.');
    if (dot <= 0) {
      return LyricsFileName._(name, name, '', LyricsFileKind.other, null);
    }
    var extension = lower.substring(dot + 1);
    var base = name.substring(0, dot);
    if (!lyricsMediaExtensions.contains(extension)) {
      return LyricsFileName._(
        name,
        base,
        extension,
        LyricsFileKind.other,
        null,
      );
    }
    for (var track in lyricsTrackSuffixes) {
      if (base.toLowerCase().endsWith('-$track')) {
        return LyricsFileName._(
          name,
          base.substring(0, base.length - track.length - 1),
          extension,
          LyricsFileKind.media,
          track,
        );
      }
    }
    return LyricsFileName._(name, base, extension, LyricsFileKind.media, null);
  }

  @override
  String toString() => 'LyricsFileName($name, $base, $kind, $track)';
}

/// A media file of a pairing, with the name of its track.
class LyricsPairedTrack {
  /// The track name: `song` for the plain file, else its suffix.
  final String name;

  /// The file name.
  final String fileName;

  /// A track.
  const LyricsPairedTrack(this.name, this.fileName);

  @override
  bool operator ==(Object other) =>
      other is LyricsPairedTrack &&
      other.name == name &&
      other.fileName == fileName;

  @override
  int get hashCode => Object.hash(name, fileName);

  @override
  String toString() => '$name: $fileName';
}

/// What goes with an opened file.
class LyricsPairing {
  /// The lyrics file, null when there is none.
  final String? lyrics;

  /// The media files, the one to time against first: the plain file, else
  /// the vocals, then the other tracks.
  final List<LyricsPairedTrack> tracks;

  /// A pairing.
  const LyricsPairing({this.lyrics, this.tracks = const []});

  @override
  String toString() => 'LyricsPairing($lyrics, $tracks)';
}

int _extensionRank(List<String> order, String extension) {
  var index = order.indexOf(extension);
  return index < 0 ? order.length : index;
}

/// The files of [candidates] that go with [opened] (itself included).
///
/// A lyrics file `X.*` pairs with `X.mp3` (or another media extension),
/// `X-vocals.*`, `X-no_vocals.*` and `X-instrumental.*`; a media file with
/// the lyrics `X.lyrics.json`, then `X.lyricsfile.yaml`, `X.lrc`, the
/// ChordPro files, `X.txt`, `X.srt`/`.vtt`, and the other tracks.
LyricsPairing pairLyricsFiles(String opened, Iterable<String> candidates) {
  var openedName = LyricsFileName.parse(opened);
  var base = openedName.base;
  var names = {
    opened,
    ...candidates,
  }.map(LyricsFileName.parse).where((name) => name.base == base);

  String? lyrics;
  if (openedName.kind == LyricsFileKind.lyrics) {
    lyrics = opened;
  } else {
    var lyricsFiles =
        names.where((name) => name.kind == LyricsFileKind.lyrics).toList()
          ..sort(
            (a, b) => _extensionRank(
              lyricsDocumentExtensions,
              a.extension,
            ).compareTo(_extensionRank(lyricsDocumentExtensions, b.extension)),
          );
    lyrics = lyricsFiles.firstOrNull?.name;
  }

  // One file per track, the preferred extension (or the one opened).
  var byTrack = <String?, LyricsFileName>{};
  for (var name in names.where((name) => name.kind == LyricsFileKind.media)) {
    var existing = byTrack[name.track];
    if (existing == null ||
        name.name == opened ||
        (existing.name != opened &&
            _extensionRank(lyricsMediaExtensions, name.extension) <
                _extensionRank(lyricsMediaExtensions, existing.extension))) {
      byTrack[name.track] = name;
    }
  }
  var tracks = [
    for (var track in [null, ...lyricsTrackSuffixes])
      if (byTrack[track] case var name?)
        LyricsPairedTrack(track ?? 'song', name.name),
  ];
  return LyricsPairing(lyrics: lyrics, tracks: tracks);
}
