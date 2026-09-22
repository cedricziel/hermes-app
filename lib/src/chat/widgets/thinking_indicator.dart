import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// A spinner, the elapsed time and what the reply is doing right now —
/// assistant-ui's stand-in for a message that has nothing else to show yet.
/// Ticks once a second for as long as it is mounted.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({
    super.key,
    required this.startedAt,
    required this.activity,
  });

  /// When the reply began, for the elapsed time.
  final DateTime startedAt;

  /// What the reply is doing right now, e.g. "Thinking…" or
  /// "Running shell…".
  final String activity;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.hermesColors.subtleText;
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatThinkingElapsed(elapsed)} · ${widget.activity}',
          style: TextStyle(fontSize: 12.5, color: color),
        ),
      ],
    );
  }
}

/// The duration text: "12s" under a minute, "2m 5s" from a minute on. Never
/// negative, for a start time that is momentarily ahead of the clock.
String formatThinkingElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
}
