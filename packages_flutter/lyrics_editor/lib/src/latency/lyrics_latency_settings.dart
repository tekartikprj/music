/// The latencies of this device: how late the sound comes out (the lyrics
/// display follows it) and how late a tap is on what it marks (the timing
/// editor takes it off), with a tap calibration.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../lyrics_editor_host.dart';

/// The beat of the calibration.
const _beatPeriod = Duration(milliseconds: 750);

/// The taps a calibration takes.
const _calibrationTaps = 8;

/// The latency settings body.
class LyricsLatencySettings extends StatefulWidget {
  /// The settings edited.
  final LyricsEditorSettings settings;

  /// The latency settings body.
  const LyricsLatencySettings({super.key, required this.settings});

  @override
  State<LyricsLatencySettings> createState() => _LyricsLatencySettingsState();
}

class _LyricsLatencySettingsState extends State<LyricsLatencySettings> {
  final _stopwatch = Stopwatch();
  Timer? _beatTimer;
  var _flash = false;
  final _offsets = <int>[];

  bool get _calibrating => _beatTimer != null;

  void _startCalibration() {
    _offsets.clear();
    _stopwatch
      ..reset()
      ..start();
    _beatTimer = Timer.periodic(_beatPeriod, (_) {
      setState(() => _flash = true);
      Timer(const Duration(milliseconds: 120), () {
        if (mounted) {
          setState(() => _flash = false);
        }
      });
    });
    setState(() {});
  }

  void _stopCalibration() {
    _beatTimer?.cancel();
    _beatTimer = null;
    _stopwatch.stop();
    setState(() {});
  }

  void _calibrationTap() {
    if (!_calibrating) {
      return;
    }
    var period = _beatPeriod.inMilliseconds;
    var elapsed = _stopwatch.elapsedMilliseconds;
    // The offset from the nearest beat (beats at period, 2 period...).
    var offset = elapsed % period;
    if (offset > period / 2) {
      offset -= period;
    }
    _offsets.add(offset);
    if (_offsets.length >= _calibrationTaps) {
      _stopCalibration();
      // The first taps find the beat: the last ones only.
      var kept = _offsets.skip(2).toList()..sort();
      var median = kept[kept.length ~/ 2];
      unawaited(widget.settings.setTapLatencyMs(median.clamp(0, 400)));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var settings = widget.settings;
    var theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Sound output', style: theme.textTheme.titleMedium),
        Text(
          'How late the sound comes out of the speakers: a Bluetooth '
          'speaker or headset adds 150 to 300 ms. The lyrics follow the '
          'sound, not the player.',
          style: theme.textTheme.bodySmall,
        ),
        ValueListenableBuilder<int>(
          valueListenable: settings.audioLatencyMs,
          builder: (context, value, _) => _MsSlider(
            value: value,
            max: 500,
            onChanged: settings.setAudioLatencyMs,
          ),
        ),
        const SizedBox(height: 24),
        Text('Tap', style: theme.textTheme.titleMedium),
        Text(
          'How late a tap is on what it marks (the reaction time), taken '
          'off the times of the timing editor.',
          style: theme.textTheme.bodySmall,
        ),
        ValueListenableBuilder<int>(
          valueListenable: settings.tapLatencyMs,
          builder: (context, value, _) => _MsSlider(
            value: value,
            max: 400,
            onChanged: settings.setTapLatencyMs,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _calibrating
              ? 'Tap on every flash (${_offsets.length} / $_calibrationTaps)'
              : 'Calibrate: tap along with the flashing beat, '
                    '$_calibrationTaps times.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTapDown: (_) => _calibrationTap(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _flash
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _calibrating ? 'TAP' : '',
              style: theme.textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _calibrating ? _stopCalibration : _startCalibration,
            child: Text(_calibrating ? 'Stop' : 'Calibrate'),
          ),
        ),
      ],
    );
  }
}

class _MsSlider extends StatelessWidget {
  final int value;
  final int max;
  final Future<void> Function(int value) onChanged;

  const _MsSlider({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(0, max).toDouble(),
            max: max.toDouble(),
            divisions: max ~/ 10,
            label: '$value ms',
            onChanged: (value) => unawaited(onChanged(value.round())),
          ),
        ),
        SizedBox(width: 64, child: Text('$value ms')),
      ],
    );
  }
}
