import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../log_line.dart';

/// A neutral pill with the level as a word and a coloured icon. The colour
/// only reinforces the word.
class LogLevelChip extends StatelessWidget {
  const LogLevelChip({super.key, required this.level});

  final LogLevel level;

  static String wordFor(LogLevel level) => switch (level) {
    LogLevel.debug => 'Debug',
    LogLevel.info => 'Info',
    LogLevel.warning => 'Warning',
    LogLevel.error => 'Error',
    LogLevel.critical => 'Critical',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final (icon, color) = switch (level) {
      LogLevel.debug => (AppIcons.terminal, colors.subtleText),
      LogLevel.info => (AppIcons.info, colors.subtleText),
      LogLevel.warning => (AppIcons.warning, colors.warning),
      LogLevel.error => (AppIcons.error, scheme.error),
      LogLevel.critical => (AppIcons.errorFilled, scheme.error),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            AppIcon(icon, size: 14, color: color),
            Text(
              wordFor(level),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
