import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_lyrics_core/lyrics_core.dart';

/// How karaoke lyrics are laid out.
enum KaraokeLyricsLayout {
  /// A page of a few lines, flipped at the page time.
  page,

  /// Every line, the current one kept in view.
  scroll,
}

/// The look of [KaraokeLyricsView].
@immutable
class KaraokeLyricsStyle {
  /// The text style (the font size is computed, see [fontSizeFactor]).
  final TextStyle textStyle;

  /// What is already sung.
  final Color sungColor;

  /// What is still to sing on the current page.
  final Color unsungColor;

  /// The lines not current (sung long ago, or later), dimmed.
  final Color inactiveColor;

  /// The lead-in dots.
  final Color leadInColor;

  /// The font size, as a fraction of the available width.
  final double fontSizeFactor;

  /// Largest font size.
  final double maxFontSize;

  /// The look.
  const KaraokeLyricsStyle({
    this.textStyle = const TextStyle(fontWeight: FontWeight.bold, height: 1.3),
    required this.sungColor,
    required this.unsungColor,
    required this.inactiveColor,
    required this.leadInColor,
    this.fontSizeFactor = 0.055,
    this.maxFontSize = 64,
  });

  /// Light text on a dark background, sung in yellow.
  static const dark = KaraokeLyricsStyle(
    sungColor: Color(0xFFFFD54F),
    unsungColor: Colors.white,
    inactiveColor: Color(0x99FFFFFF),
    leadInColor: Color(0xFFFFD54F),
  );

  /// Dark text on a light background, sung in the given [sung] color.
  static KaraokeLyricsStyle light({Color sung = const Color(0xFF6A1B9A)}) =>
      KaraokeLyricsStyle(
        sungColor: sung,
        unsungColor: Colors.black87,
        inactiveColor: Colors.black38,
        leadInColor: sung,
      );

  /// From a theme: the primary color sings.
  static KaraokeLyricsStyle fromTheme(ThemeData theme) {
    var scheme = theme.colorScheme;
    return KaraokeLyricsStyle(
      sungColor: scheme.primary,
      unsungColor: scheme.onSurface,
      inactiveColor: scheme.onSurface.withValues(alpha: 0.45),
      leadInColor: scheme.primary,
    );
  }
}

/// Karaoke lyrics following a media position.
///
/// [positionMs] is read on every frame: give it a `LyricsClock.positionMs`
/// fed by the player (media time, any output latency already taken off).
/// Nothing repaints while the position stays on the same part progress.
class KaraokeLyricsView extends StatefulWidget {
  /// The lyrics.
  final CvLyrics lyrics;

  /// The media position now, in milliseconds.
  final int Function() positionMs;

  /// Page or scroll.
  final KaraokeLyricsLayout layout;

  /// Lines per page when the lyrics have no explicit pages.
  final int linesPerPage;

  /// The look.
  final KaraokeLyricsStyle style;

  /// A line following a gap at least this long gets lead-in dots.
  final int leadInGapMs;

  /// How long before its line the lead-in dots show.
  final int leadInMs;

  /// Karaoke lyrics.
  const KaraokeLyricsView({
    super.key,
    required this.lyrics,
    required this.positionMs,
    this.layout = KaraokeLyricsLayout.page,
    this.linesPerPage = 2,
    this.style = KaraokeLyricsStyle.dark,
    this.leadInGapMs = 3000,
    this.leadInMs = 3000,
  });

  @override
  State<KaraokeLyricsView> createState() => _KaraokeLyricsViewState();
}

class _KaraokeLyricsViewState extends State<KaraokeLyricsView>
    with SingleTickerProviderStateMixin {
  /// Smallest font size, whatever the box.
  static const _minFontSize = 12.0;

  /// The height of the lead-in dots row, in font sizes.
  static const _leadInHeightFactor = 0.8;

  late LyricsTimeline _timeline;
  late Ticker _ticker;
  var _location = LyricsLocation.start;
  var _positionMs = 0;
  var _leadInDots = 0;
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _buildTimeline();
    _ticker = createTicker((_) => _tick())..start();
  }

  void _buildTimeline() {
    _timeline = LyricsTimeline(
      widget.lyrics,
      options: LyricsTimelineOptions(linesPerPage: widget.linesPerPage),
    );
  }

  @override
  void didUpdateWidget(covariant KaraokeLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics ||
        oldWidget.linesPerPage != widget.linesPerPage) {
      _buildTimeline();
      _location = LyricsLocation.start;
    }
  }

  int _computeLeadInDots(int ms, LyricsLocation location) {
    // The next line to start.
    LyricsTimelineLine? next;
    for (var line in _timeline.lines) {
      var start = line.startMs;
      if (start != null && start > ms) {
        next = line;
        break;
      }
    }
    if (next == null) {
      return 0;
    }
    var start = next.startMs!;
    if (start - ms > widget.leadInMs) {
      return 0;
    }
    // Only after a gap: the previous line ended long enough before.
    int? previousEnd;
    for (var i = next.index - 1; i >= 0; i--) {
      var line = _timeline.lines[i];
      if (line.isTimed) {
        previousEnd = line.sungEndMs ?? line.endMs ?? line.startMs;
        break;
      }
    }
    if (previousEnd != null && start - previousEnd < widget.leadInGapMs) {
      return 0;
    }
    return min(3, ((start - ms) / (widget.leadInMs / 3)).ceil());
  }

  void _tick() {
    var ms = widget.positionMs();
    if (ms == _positionMs) {
      return;
    }
    _positionMs = ms;
    var location = _timeline.locate(ms);
    var dots = _computeLeadInDots(ms, location);
    if (location != _location || dots != _leadInDots) {
      var lineChanged = location.lineIndex != _location.lineIndex;
      setState(() {
        _location = location;
        _leadInDots = dots;
      });
      if (lineChanged && widget.layout == KaraokeLyricsLayout.scroll) {
        _scrollToCurrent();
      }
    }
  }

  void _scrollToCurrent() {
    var index = max(0, _location.lineIndex);
    var context = _lineKeys[index]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _LineState _lineState(int index) {
    var current = _location.lineIndex;
    if (index < current) {
      return const _LineState.sung();
    }
    if (index > current) {
      return const _LineState.unsung();
    }
    return _LineState.current(
      partIndex: _location.partIndex,
      partProgress: _location.partProgress,
      lineProgress: _location.lineProgress,
      singing: _location.singing,
      hasPartTiming: _timeline.lines[index].parts.any(
        (part) => part.startMs != null && part.index > 0,
      ),
    );
  }

  Widget _line(int index, TextStyle textStyle, {required bool onPage}) {
    var line = _timeline.lines[index];
    var state = _lineState(index);
    var style = widget.style;
    var dim = !onPage || (state.kind == _LineKind.sung);
    return _KaraokeLine(
      key: _lineKeys.putIfAbsent(index, GlobalKey.new),
      line: line.line,
      state: state,
      textStyle: textStyle,
      sungColor: dim && !onPage ? style.inactiveColor : style.sungColor,
      unsungColor: onPage ? style.unsungColor : style.inactiveColor,
    );
  }

  Widget _leadIn(double fontSize) => SizedBox(
    height: fontSize * _leadInHeightFactor,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: EdgeInsets.symmetric(horizontal: fontSize * 0.2),
            width: fontSize * 0.35,
            height: fontSize * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _leadInDots
                  ? widget.style.leadInColor
                  : Colors.transparent,
            ),
          ),
      ],
    ),
  );

  /// The height of the lines [firstLine] to [endLine] (excluded) at
  /// [fontSize], the lead-in row included, when laid out [width] wide.
  double _pageHeight(
    int firstLine,
    int endLine,
    double width,
    double fontSize,
    TextDirection textDirection,
  ) {
    var textStyle = widget.style.textStyle.copyWith(fontSize: fontSize);
    var height = fontSize * _leadInHeightFactor;
    for (var i = firstLine; i < endLine; i++) {
      var painter = TextPainter(
        text: TextSpan(
          text: _LineText.of(_timeline.lines[i].line).text,
          style: textStyle,
        ),
        textAlign: TextAlign.center,
        textDirection: textDirection,
      )..layout(maxWidth: width);
      height += painter.height;
      painter.dispose();
    }
    return height;
  }

  /// The font size showing the lines [firstLine] to [endLine] (excluded)
  /// whole in [maxHeight] at [width]: [fontSize] when they fit, smaller
  /// otherwise (never under [_minFontSize]). A page cut at the bottom is
  /// worse than a smaller one: the player gives the lyrics what the video
  /// leaves, little on a phone held sideways or in a short window.
  double _fitFontSize(
    int firstLine,
    int endLine,
    double width,
    double maxHeight,
    double fontSize,
    TextDirection textDirection,
  ) {
    // A smaller font wraps a line less, never more: the height shrinks at
    // least in proportion, one round fits and a second absorbs rounding.
    for (var round = 0; round < 2 && fontSize > _minFontSize; round++) {
      var height = _pageHeight(
        firstLine,
        endLine,
        width,
        fontSize,
        textDirection,
      );
      if (height <= maxHeight) {
        break;
      }
      fontSize = max(_minFontSize, fontSize * maxHeight / height * 0.99);
    }
    return fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 600.0;
        var fontSize = min(
          widget.style.maxFontSize,
          max(_minFontSize, width * widget.style.fontSizeFactor),
        );
        if (_timeline.lines.isEmpty) {
          return const SizedBox.shrink();
        }
        if (widget.layout == KaraokeLyricsLayout.page && _timeline.isTimed) {
          var page = _timeline
              .pages[_location.pageIndex.clamp(0, _timeline.pages.length - 1)];
          if (constraints.maxHeight.isFinite) {
            fontSize = _fitFontSize(
              page.firstLine,
              page.endLine,
              width,
              constraints.maxHeight,
              fontSize,
              Directionality.of(context),
            );
          }
          var textStyle = widget.style.textStyle.copyWith(fontSize: fontSize);
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _leadIn(fontSize),
                  for (var i = page.firstLine; i < page.endLine; i++)
                    _line(i, textStyle, onPage: true),
                ],
              ),
            ),
          );
        }
        var textStyle = widget.style.textStyle.copyWith(fontSize: fontSize);
        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: fontSize * 2),
          child: Column(
            children: [
              _leadIn(fontSize),
              for (var i = 0; i < _timeline.lines.length; i++)
                _line(
                  i,
                  textStyle,
                  onPage:
                      !_timeline.isTimed ||
                      _timeline.lines[i].pageIndex == _location.pageIndex,
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _LineKind { sung, unsung, current }

@immutable
class _LineState {
  final _LineKind kind;
  final int partIndex;
  final double partProgress;
  final double lineProgress;
  final bool singing;
  final bool hasPartTiming;

  const _LineState.sung()
    : kind = _LineKind.sung,
      partIndex = -1,
      partProgress = 0,
      lineProgress = 1,
      singing = false,
      hasPartTiming = false;

  const _LineState.unsung()
    : kind = _LineKind.unsung,
      partIndex = -1,
      partProgress = 0,
      lineProgress = 0,
      singing = false,
      hasPartTiming = false;

  const _LineState.current({
    required this.partIndex,
    required this.partProgress,
    required this.lineProgress,
    required this.singing,
    required this.hasPartTiming,
  }) : kind = _LineKind.current;

  @override
  bool operator ==(Object other) =>
      other is _LineState &&
      other.kind == kind &&
      other.partIndex == partIndex &&
      other.partProgress == partProgress &&
      other.lineProgress == lineProgress &&
      other.singing == singing;

  @override
  int get hashCode =>
      Object.hash(kind, partIndex, partProgress, lineProgress, singing);
}

/// The text of a line and where each part is in it.
class _LineText {
  final String text;
  final List<int> starts;
  final List<int> ends;

  _LineText(this.text, this.starts, this.ends);

  factory _LineText.of(CvLyricsLine line) {
    var sb = StringBuffer();
    var starts = <int>[];
    var ends = <int>[];
    var parts = line.partList;
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      starts.add(sb.length);
      sb.write(part.textOrEmpty);
      ends.add(sb.length);
      if (i < parts.length - 1 && !part.isJoined && part.textOrEmpty != '') {
        sb.write(' ');
      }
    }
    return _LineText(sb.toString(), starts, ends);
  }
}

class _KaraokeLine extends StatelessWidget {
  final CvLyricsLine line;
  final _LineState state;
  final TextStyle textStyle;
  final Color sungColor;
  final Color unsungColor;

  const _KaraokeLine({
    super.key,
    required this.line,
    required this.state,
    required this.textStyle,
    required this.sungColor,
    required this.unsungColor,
  });

  @override
  Widget build(BuildContext context) {
    var lineText = _LineText.of(line);
    return LayoutBuilder(
      builder: (context, constraints) {
        var painter = TextPainter(
          text: TextSpan(text: lineText.text, style: textStyle),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        var size = Size(constraints.maxWidth, painter.height);
        return Semantics(
          label: lineText.text,
          child: CustomPaint(
            size: size,
            painter: _KaraokeLinePainter(
              lineText: lineText,
              state: state,
              textStyle: textStyle,
              sungColor: sungColor,
              unsungColor: unsungColor,
              textDirection: Directionality.of(context),
            ),
          ),
        );
      },
    );
  }
}

class _KaraokeLinePainter extends CustomPainter {
  final _LineText lineText;
  final _LineState state;
  final TextStyle textStyle;
  final Color sungColor;
  final Color unsungColor;
  final TextDirection textDirection;

  _KaraokeLinePainter({
    required this.lineText,
    required this.state,
    required this.textStyle,
    required this.sungColor,
    required this.unsungColor,
    required this.textDirection,
  });

  TextPainter _painter(Color color, double width) => TextPainter(
    text: TextSpan(
      text: lineText.text,
      style: textStyle.copyWith(color: color),
    ),
    textAlign: TextAlign.center,
    textDirection: textDirection,
  )..layout(minWidth: width, maxWidth: width);

  @override
  void paint(Canvas canvas, Size size) {
    var text = lineText.text;
    if (state.kind == _LineKind.sung) {
      _painter(sungColor, size.width).paint(canvas, Offset.zero);
      return;
    }
    var unsung = _painter(unsungColor, size.width)..paint(canvas, Offset.zero);
    if (state.kind == _LineKind.unsung || text.isEmpty) {
      return;
    }
    // The sung part: whole parts before the current one, then the current
    // one up to its progress (the whole line by its progress when only the
    // line is timed).
    var path = Path();
    void addRange(int from, int to, double fraction) {
      if (to <= from) {
        return;
      }
      var boxes = unsung.getBoxesForSelection(
        TextSelection(baseOffset: from, extentOffset: to),
      );
      // The fraction runs through the boxes in reading order.
      var total = boxes.fold<double>(
        0,
        (sum, box) => sum + box.right - box.left,
      );
      var remaining = total * fraction;
      for (var box in boxes) {
        var width = box.right - box.left;
        if (remaining <= 0) {
          break;
        }
        var take = min(width, remaining);
        path.addRect(
          Rect.fromLTRB(box.left, box.top, box.left + take, box.bottom),
        );
        remaining -= take;
      }
    }

    if (state.hasPartTiming && state.partIndex >= 0) {
      var partIndex = state.partIndex;
      addRange(0, lineText.starts[partIndex], 1);
      addRange(
        lineText.starts[partIndex],
        lineText.ends[partIndex],
        state.singing ? state.partProgress : 1,
      );
    } else {
      addRange(0, text.length, state.singing ? state.lineProgress : 1);
    }
    canvas.save();
    canvas.clipPath(path);
    _painter(sungColor, size.width).paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KaraokeLinePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.lineText.text != lineText.text ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.sungColor != sungColor ||
      oldDelegate.unsungColor != unsungColor;
}
