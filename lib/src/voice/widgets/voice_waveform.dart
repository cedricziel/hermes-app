import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// The middle of the composer's controls row while dictating, after the
/// Claude app: a recording dot, the input [levels] as bars and the name of
/// the engine listening ([onDevice]). Once the recording has stopped the bars
/// dim and it says "Transcribing…". The words themselves go into the text
/// field above.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.levels,
    required this.elapsed,
    this.settling = false,
    this.onDevice,
  });

  /// Recent levels from 0 to 1, oldest first; the newest is drawn rightmost.
  final List<double> levels;

  /// How long the recording runs; the dot blinks with it.
  final Duration elapsed;
  final bool settling;

  /// True for the on-device recognizer, false for Hermes; null names none.
  final bool? onDevice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final label = settling
        ? 'Transcribing…'
        : switch (onDevice) {
            true => 'On this device',
            false => 'Hermes',
            null => null,
          };
    // The dot blinks with the clock rather than with an animation, so the
    // widget settles in tests and stops with the recording.
    final dotOn = (elapsed.inMilliseconds ~/ 500).isEven;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (!settling) ...[
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
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size(double.infinity, 24),
                painter: _BarsPainter(
                  levels: levels,
                  color: settling
                      ? subtle.withValues(alpha: 0.4)
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            // Narrow rows (large text, small phones) cut the name short
            // rather than the controls around it.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: subtle),
              ),
            ),
          ],
        ],
      ),
    );
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
