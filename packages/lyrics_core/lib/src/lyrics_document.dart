/// What the lyrics editor opens and saves: the lyrics, with a title, an
/// artist and a reference to the media they go with.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cv/cv.dart';

import 'lyrics_model.dart';

/// The kinds of media a document can go with.
abstract final class CvLyricsMediaKind {
  /// An audio (or video) file, [CvLyricsMedia.path].
  static const file = 'file';

  /// An audio url, [CvLyricsMedia.url].
  static const url = 'url';

  /// A YouTube video, [CvLyricsMedia.videoId] (and [CvLyricsMedia.url]).
  static const youtube = 'youtube';

  /// No media: the lyrics are timed against a clock.
  static const none = 'none';
}

/// One of the audio files of a document sharing the same timeline, such as
/// the song with vocals and without.
class CvLyricsTrack extends CvModelBase {
  /// The track name (`vocals`, `instrumental`).
  final name = CvField<String>('name');

  /// The file, relative to the document.
  final path = CvField<String>('path');

  @override
  CvFields get fields => [name, path];

  /// A track.
  CvLyricsTrack();

  /// A track with its values.
  factory CvLyricsTrack.of(String name, String path) => CvLyricsTrack()
    ..name.v = name
    ..path.v = path;
}

/// The media a document goes with.
class CvLyricsMedia extends CvModelBase {
  /// See [CvLyricsMediaKind].
  final kind = CvField<String>('kind');

  /// The file, relative to the document, for a [CvLyricsMediaKind.file].
  final path = CvField<String>('path');

  /// The url, for a [CvLyricsMediaKind.url] or a YouTube link.
  final url = CvField<String>('url');

  /// The YouTube video id.
  final videoId = CvField<String>('videoId');

  /// The tracks, when there are several audio files (the first one is the
  /// one timed).
  final tracks = CvModelListField<CvLyricsTrack>('tracks');

  @override
  CvFields get fields => [kind, path, url, videoId, tracks];

  /// A media reference.
  CvLyricsMedia();

  /// A media file.
  factory CvLyricsMedia.file(String path, {List<CvLyricsTrack>? tracks}) =>
      CvLyricsMedia()
        ..kind.v = CvLyricsMediaKind.file
        ..path.v = path
        ..tracks.v = tracks;

  /// A YouTube video.
  factory CvLyricsMedia.youtube(String videoId, {String? url}) =>
      CvLyricsMedia()
        ..kind.v = CvLyricsMediaKind.youtube
        ..videoId.v = videoId
        ..url.v = url;

  /// No media.
  factory CvLyricsMedia.none() =>
      CvLyricsMedia()..kind.v = CvLyricsMediaKind.none;
}

/// What the lyrics editor opens and saves: the lyrics, plus a title, an
/// artist, a reference to the media and where the lyrics came from.
class CvLyricsDocument extends CvModelBase {
  /// The title (LRC `[ti:]`, ChordPro `{title:}`...).
  final title = CvField<String>('title');

  /// The artist.
  final artist = CvField<String>('artist');

  /// The album.
  final album = CvField<String>('album');

  /// No lyrics on purpose, not "not written yet".
  final instrumental = CvField<bool>('instrumental');

  /// The media the lyrics go with.
  final media = CvModelField<CvLyricsMedia>('media');

  /// The lyrics.
  final lyrics = CvModelField<CvLyrics>('lyrics');

  /// Where the lyrics were imported from, to import them again: a file name,
  /// or `lrclib:<id>`.
  final source = CvField<String>('source');

  @override
  CvFields get fields => [
    title,
    artist,
    album,
    instrumental,
    media,
    lyrics,
    source,
  ];

  /// A document.
  CvLyricsDocument();

  /// A document with its values.
  factory CvLyricsDocument.of(
    CvLyrics lyrics, {
    String? title,
    String? artist,
    String? album,
    CvLyricsMedia? media,
    String? source,
  }) => CvLyricsDocument()
    ..lyrics.v = lyrics
    ..title.v = title
    ..artist.v = artist
    ..album.v = album
    ..media.v = media
    ..source.v = source;
}

/// Document helpers.
extension CvLyricsDocumentExt on CvLyricsDocument {
  /// The lyrics, empty ones when null.
  CvLyrics get lyricsOrEmpty => lyrics.v ?? CvLyrics.of(const []);

  /// A deep copy.
  CvLyricsDocument copy() {
    initTekalyLyricsBuilders();
    return clone();
  }

  /// The native format (`.lyrics.json`): the document as indented JSON.
  String toJsonText() =>
      '${const JsonEncoder.withIndent('  ').convert(toMap())}\n';
}

/// Reads a document saved with [CvLyricsDocumentExt.toJsonText].
CvLyricsDocument parseLyricsDocumentJson(String text) {
  var map = jsonDecode(text);
  if (map is! Map) {
    throw const FormatException('not a lyrics document');
  }
  return lyricsDocumentFromMap(map);
}

/// A document from its map (`toMap()`).
CvLyricsDocument lyricsDocumentFromMap(Map map) {
  initTekalyLyricsBuilders();
  return map.cv<CvLyricsDocument>();
}

/// The text of a lyrics file: UTF-8 (its byte order mark dropped), Latin-1
/// when it is not valid UTF-8 (old LRC files).
String decodeLyricsBytes(Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  var content = bytes.sublist(start);
  try {
    return utf8.decode(content);
  } on FormatException {
    return latin1.decode(content);
  }
}
