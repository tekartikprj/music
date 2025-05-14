import 'package:tekartik_common_utils/duration_utils.dart';

/// Helper functions for duration
extension TekartikLyricsIntExt on num {
  /// Convert from minutes
  Duration get mn => minutes;

  /// Convert from seconds
  Duration get s => seconds;
}
