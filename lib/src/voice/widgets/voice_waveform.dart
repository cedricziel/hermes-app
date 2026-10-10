import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// Stands in for the composer's text field while dictating, after
/// assistant-ui's `ComposerVoice`. While [settling] is false it shows a
/// recording dot, the input [levels] as bars and the [elapsed] time; once the
/// recording has stopped it shows "Transcribing…". The [liveTranscript], when
/// there is one, is the not-yet-final text recognized so far. Under the bars
/// it names who turns the speech into text, when [onDevice] is known.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.levels,
    required this.elapsed,
    this.liveTranscript = '',
    this.settling = false,
    this.onDevice,
  });

  /// Recent levels from 0 to 1, oldest first; the newest is drawn rightmost.
  final List<double> levels;
  final Duration elapsed;
  final String liveTranscript;
  final bool settling;

  /// True for the on-device recognizer, false for Hermes.
  final bool? onDevice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final textTheme = Theme.of(context).textTheme;
    // The dot blinks with the clock rather than with an animation, so the
    // widget settles in tests and stops with the recording.
    final dotOn = (elapsed.inMilliseconds ~/ 500).isEven;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (liveTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                liveTranscript,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: subtle,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                if (!settling)
                  Semantics(
                    label: 'Recording',
                    child: AnimatedOpacity(
                      opacity: dotOn ? 1 : 0.3,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BarsPainter(
                        levels: levels,
                        color: settling
                            ? subtle.withValues(alpha: 0.4)
                            : scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  settling ? 'Transcribing…' : _clock(elapsed),
                  style: textTheme.labelLarge?.copyWith(
                    color: subtle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (onDevice case final onDevice?)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                onDevice ? 'On this device' : 'Hermes',
                style: textTheme.labelSmall?.copyWith(color: subtle),
              ),
            ),
        ],
      ),
    );
  }

  static String _clock(Duration elapsed) {
    final seconds = elapsed.inSeconds % 60;
    return '${elapsed.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  static const _barWidth = 3.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;
    final slots = (size.width / (_barWidth + _gap)).floor();
    final mid = size.height / 2;
    for (var slot = 0; slot < slots; slot++) {
      // Right-aligned: the newest level is the last slot.
      final index = levels.length - slots + slot;
      final level = index < 0 ? 0.0 : levels[index].clamp(0.0, 1.0);
      final half = (size.height / 2 - 1) * level + 1;
      final x = slot * (_barWidth + _gap) + _barWidth / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.levels != levels || old.color != color;
}
