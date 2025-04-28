import 'package:meta/meta.dart';
import 'package:tekaly_lyrics/src/lyrics.dart';
import 'package:tekartik_common_utils/comparable_utils.dart';

/// Located lyrics data line
class LocatedLyricsDataLine {
  /// Line data
  final LyricsLineData lineData;

  /// located parts
  final parts = <LocatedLyricsDataPart>[];

  /// Constructor
  LocatedLyricsDataLine({required this.lineData}) {
    var rawParts = lineData.parts;
    var start = 0;
    for (var part in rawParts) {
      var locatedPart = LocatedLyricsDataPart(partData: part, start: start);
      parts.add(locatedPart);
      start = locatedPart.end;
    }
  }

  /// Line time
  Duration get time => lineData.time;

  /// Text
  String get text => lineData.text;
}

/// Located lyrics data part
class LocatedLyricsDataPart {
  /// Part data
  final LyricsPartData partData;

  /// Start index in the string line
  final int start;

  /// End index in the string line
  int get end => start + partData.text.length;

  /// Constructor
  LocatedLyricsDataPart({required this.partData, required this.start});

  /// Part time
  Duration get time => partData.time;
}

/// Located lyrics data
class LocatedLyricsData {
  /// lines
  final lines = <LocatedLyricsDataLine>[];

  /// Get a line
  LocatedLyricsDataLine getLine(int lineIndex) {
    return lines[lineIndex];
  }

  /// Get a part
  LocatedLyricsDataItemInfo getItemInfo(LocatedLyricsDataItemRef ref) {
    var lineIndex = ref.lineIndex;
    if (lineIndex < 0) {
      return LocatedLyricsDataItemInfo(ref: ref, start: 0, end: 0, text: '');
    }
    var line = lines[lineIndex];
    var partIndex = ref.partIndex;
    if (partIndex < 0) {
      return LocatedLyricsDataItemInfo(ref: ref, start: 0, end: 0, text: '');
    }
    var part = line.parts[partIndex];
    return LocatedLyricsDataItemInfo(
      ref: ref,
      start: part.start,
      end: part.end,
      text: part.partData.text,
    );
  }

  int _findLine(Duration time) {
    var index = lines
        .map((line) => line.time)
        .toList()
        .findInsertionIndex(time);
    if (index < lines.length) {
      /// Actually insert in the line itself
      var line = lines[index];
      if (time < line.time) {
        index--;
      }
    }
    return index;
  }

  LocatedLyricsDataItemRef get _lastRef {
    var lastLineIndex = lines.length - 1;
    var lastLine = lines.last;
    var lastPartIndex = lastLine.parts.length - 1;
    return LocatedLyricsDataItemRef(lastLineIndex, lastPartIndex);
  }

  /// Get previous ref
  LocatedLyricsDataItemRef getPreviousRef(LocatedLyricsDataItemRef ref) {
    var lineIndex = ref.lineIndex;
    if (lineIndex == -1) {
      return LocatedLyricsDataItemRef.before();
    }
    var partIndex = ref.partIndex;
    if (partIndex == -1) {
      if (lineIndex == 0) {
        return LocatedLyricsDataItemRef.before();
      }
      lineIndex--;
      var beforeLine = lines[lineIndex];
      return LocatedLyricsDataItemRef(lineIndex, beforeLine.parts.length - 1);
    }
    return LocatedLyricsDataItemRef(lineIndex, partIndex - 1);
  }

  /// Get next ref
  LocatedLyricsDataItemRef getNextRef(LocatedLyricsDataItemRef ref) {
    var lineIndex = ref.lineIndex;
    if (lineIndex == -1) {
      return LocatedLyricsDataItemRef(0, -1);
    }
    var partIndex = ref.partIndex;
    var line = lines[lineIndex];
    if (partIndex >= (line.parts.length - 1)) {
      if (lineIndex == lines.length - 1) {
        return _lastRef;
      }
      return LocatedLyricsDataItemRef(lineIndex + 1, -1);
    }
    return LocatedLyricsDataItemRef(lineIndex, partIndex + 1);
  }

  /// Locate item info by time
  LocatedLyricsDataItemInfo locateItemInfo(Duration time) {
    var lineIndex = _findLine(time);
    if (lineIndex < 0) {
      return getItemInfo(LocatedLyricsDataItemRef.before());
    }
    if (lineIndex >= lines.length) {
      return getItemInfo(_lastRef);
    }
    var parts = lines[lineIndex].parts;

    var partIndex = parts
        .map((part) => part.time)
        .toList()
        .findInsertionIndex(time);
    if (partIndex < parts.length) {
      /// Actually insert in the part itself
      var part = parts[partIndex];
      if (time < part.time) {
        partIndex--;
      }
    } else {
      /// neither after
      partIndex--;
    }

    var ref = LocatedLyricsDataItemRef(lineIndex, partIndex);
    return getItemInfo(ref);
  }

  /// Constructor
  LocatedLyricsData({required LyricsData lyricsData}) {
    for (var line in lyricsData.lines) {
      lines.add(LocatedLyricsDataLine(lineData: line));
    }
  }

  /// Dev dump
  @doNotSubmit
  void devDump() {
    for (var line in lines) {
      // ignore: avoid_print
      print('line: ${line.lineData.time} ${line.lineData.text}');
      for (var part in line.parts) {
        // ignore: avoid_print
        print('  ${part.partData.time} ${part.partData.text}');
      }
    }
  }
}

/// Item info
class LocatedLyricsDataItemInfo {
  /// Reference to the item
  final LocatedLyricsDataItemRef ref;

  /// Index in the string line
  final int start;

  /// Index in the string line
  final int end;

  /// text part
  final String text;

  /// Constructor
  LocatedLyricsDataItemInfo({
    required this.ref,
    required this.start,
    required this.end,
    required this.text,
  });
}

/// Reference to the item
class LocatedLyricsDataItemRef implements Comparable<LocatedLyricsDataItemRef> {
  /// Line index (from -1)
  final int lineIndex;

  /// Part index (from -1)
  final int partIndex;

  /// Before the start
  LocatedLyricsDataItemRef.before() : lineIndex = -1, partIndex = -1;

  /// Before the line
  LocatedLyricsDataItemRef.lineBefore(this.lineIndex) : partIndex = -1;

  /// Constructor
  LocatedLyricsDataItemRef(this.lineIndex, this.partIndex);

  @override
  String toString() {
    return 'Ref($lineIndex, $partIndex)';
  }

  @override
  int get hashCode => lineIndex.hashCode ^ partIndex.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is LocatedLyricsDataItemRef) {
      return other.lineIndex == lineIndex && other.partIndex == partIndex;
    }
    return false;
  }

  @override
  int compareTo(LocatedLyricsDataItemRef other) {
    var cmp = lineIndex.compareTo(other.lineIndex);
    if (cmp != 0) {
      return cmp;
    }
    return partIndex.compareTo(other.partIndex);
  }
}
