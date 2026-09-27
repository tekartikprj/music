/// Media time text: `m:ss.mmm` (or `h:mm:ss.mmm`) both ways, millisecond
/// exact, plus the variants the lyrics formats use (LRC centiseconds, SRT
/// commas).
library;

/// Format [ms] as `m:ss.mmm`, `h:mm:ss.mmm` from one hour on.
///
/// [digits] is the number of fraction digits (3: milliseconds, 2: the
/// centiseconds of a classic LRC file, 0: none). A negative value is written
/// as zero, media time never is.
String formatLyricsTime(int ms, {int digits = 3, bool padMinutes = false}) {
  if (ms < 0) {
    ms = 0;
  }
  var hours = ms ~/ 3600000;
  var minutes = (ms ~/ 60000) % 60;
  var seconds = (ms ~/ 1000) % 60;
  var millis = ms % 1000;
  var sb = StringBuffer();
  if (hours > 0) {
    sb.write('$hours:${minutes.toString().padLeft(2, '0')}');
  } else {
    sb.write(padMinutes ? minutes.toString().padLeft(2, '0') : '$minutes');
  }
  sb.write(':${seconds.toString().padLeft(2, '0')}');
  if (digits > 0) {
    var fraction = millis.toString().padLeft(3, '0').substring(0, digits);
    sb.write('.$fraction');
  }
  return sb.toString();
}

final _timeRegExp = RegExp(
  r'^(?:(\d+):)?(\d+):(\d{1,2})(?:[.,](\d{1,3}))?$|^(\d+)(?:[.,](\d{1,3}))$',
);

/// Parse a media time: `m:ss`, `m:ss.x` to `m:ss.xxx`, `h:mm:ss.mmm`,
/// `hh:mm:ss,mmm` (SRT) or bare seconds with a fraction (`12.5`).
///
/// The fraction is a decimal fraction of a second: `.5` is 500 ms, `.05` is
/// 50 ms. Returns null when [text] is not a time.
int? parseLyricsTime(String text) {
  var match = _timeRegExp.firstMatch(text.trim());
  if (match == null) {
    return null;
  }
  int fractionMs(String? fraction) {
    if (fraction == null) {
      return 0;
    }
    return int.parse(fraction.padRight(3, '0'));
  }

  if (match.group(5) != null) {
    return int.parse(match.group(5)!) * 1000 + fractionMs(match.group(6));
  }
  var hours = int.parse(match.group(1) ?? '0');
  var minutes = int.parse(match.group(2)!);
  var seconds = int.parse(match.group(3)!);
  if (seconds >= 60 || (match.group(1) != null && minutes >= 60)) {
    return null;
  }
  return ((hours * 60 + minutes) * 60 + seconds) * 1000 +
      fractionMs(match.group(4));
}
