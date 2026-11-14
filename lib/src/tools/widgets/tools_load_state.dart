import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'tools_switch.dart';
import 'tools_target.dart';

/// A row of a section while something is read: a spinner and [text]. The row
/// is a live region, so a screen reader announces it as it appears. With
/// reduced motion the spinner is a still hourglass.
class ToolsLoadingRow extends StatelessWidget {
  const ToolsLoadingRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.rowPadding,
            vertical: 14,
          ),
          child: Row(
            spacing: 10,
            children: [
              const ToolsSpinner(),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: context.hermesColors.subtleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of a section for something that could not be read: an error line
/// and Try again. The line is a live region.
class ToolsFailureRow extends StatelessWidget {
  const ToolsFailureRow({super.key, required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: metrics.rowVerticalPadding + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            container: true,
            label: text,
            child: ExcludeSemantics(
              child: GroupedStatusLine(
                icon: AppIcons.error,
                text: text,
                color: Theme.of(context).colorScheme.error,
                size: metrics.titleSize,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: toolsButtonStyle(context),
            child: Text(context.l10n.toolsTryAgain),
          ),
        ],
      ),
    );
  }
}

/// A row of a section with nothing to show: [text], muted.
class ToolsNothingRow extends StatelessWidget {
  const ToolsNothingRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 14,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: metrics.titleSize,
          color: context.hermesColors.subtleText,
        ),
      ),
    );
  }
}
