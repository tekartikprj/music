import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_core/lyrics_core.dart';

/// Lyrics as songbook text: the lines, the chords above their syllables, the
/// section labels, a gap between the pages.
///
/// Not scrollable itself: put it in a scroll view.
class SongbookLyricsView extends StatelessWidget {
  /// The lyrics.
  final CvLyrics lyrics;

  /// Show the chords.
  final bool showChords;

  /// Move the chords by this many semitones.
  final int transpose;

  /// The text style (the chords take the primary color).
  final TextStyle? textStyle;

  /// The chord style.
  final TextStyle? chordStyle;

  /// The songbook text.
  const SongbookLyricsView({
    super.key,
    required this.lyrics,
    this.showChords = true,
    this.transpose = 0,
    this.textStyle,
    this.chordStyle,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var textStyle = this.textStyle ?? theme.textTheme.bodyLarge!;
    var chordStyle =
        this.chordStyle ??
        textStyle.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: (textStyle.fontSize ?? 16) * 0.85,
        );
    var withChords = showChords && lyrics.hasChords;
    var children = <Widget>[];
    String? previousSection;
    var lines = lyrics.lineList;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (i > 0 && line.isNewPage) {
        children.add(SizedBox(height: (textStyle.fontSize ?? 16) * 0.8));
      }
      var section = line.section.v;
      if (section != null && section != previousSection) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              section,
              style: textStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        );
      }
      previousSection = section;
      children.add(
        _SongbookLine(
          line: line,
          withChords: withChords,
          transpose: transpose,
          textStyle: textStyle,
          chordStyle: chordStyle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SongbookLine extends StatelessWidget {
  final CvLyricsLine line;
  final bool withChords;
  final int transpose;
  final TextStyle textStyle;
  final TextStyle chordStyle;

  const _SongbookLine({
    required this.line,
    required this.withChords,
    required this.transpose,
    required this.textStyle,
    required this.chordStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (!withChords) {
      return Text(line.text, style: textStyle);
    }
    // Words (joined parts), each part with its chord above it.
    var words = <Widget>[];
    var current = <Widget>[];
    var parts = line.partList;
    for (var p = 0; p < parts.length; p++) {
      var part = parts[p];
      var chord = part.chord.v;
      var text = part.textOrEmpty;
      var last = p == parts.length - 1;
      current.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chord == null ? '' : '${transposeLyricsChord(chord, transpose)} ',
              style: chordStyle,
            ),
            Text(
              // An empty part (a chord alone) keeps some room.
              text.isEmpty ? '  ' : (part.isJoined || last ? text : '$text '),
              style: textStyle,
            ),
          ],
        ),
      );
      if (!part.isJoined || last) {
        words.add(Row(mainAxisSize: MainAxisSize.min, children: current));
        current = <Widget>[];
      }
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: words);
  }
}
