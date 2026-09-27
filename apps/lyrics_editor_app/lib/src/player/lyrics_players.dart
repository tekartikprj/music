/// The player of an opened document: its YouTube video, its audio tracks,
/// or a clock when it has no media.
library;

import 'package:tekaly_lyrics_editor/lyrics_editor.dart';

import '../data/lyrics_opener.dart';
import 'audio_lyrics_player.dart';
import 'youtube_lyrics_player.dart';

/// Creates the player of a document.
typedef LyricsPlayerFactory =
    Future<LyricsPlayer> Function(LyricsOpenedDocument document);

/// The player of [document].
Future<LyricsPlayer> createLyricsPlayer(LyricsOpenedDocument document) async {
  var youtube = document.youtube;
  if (youtube != null) {
    return await YoutubeLyricsPlayer.open(youtube);
  }
  if (document.tracks.isNotEmpty) {
    return await AudioLyricsPlayer.open(document.tracks);
  }
  return ClockLyricsPlayer();
}

/// Only clocks (the tests, a device with no audio).
Future<LyricsPlayer> createClockLyricsPlayer(
  LyricsOpenedDocument document,
) async => ClockLyricsPlayer();
