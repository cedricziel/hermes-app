import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'tools_target.dart';

/// How a [ToolsNote] reads: an icon and a colour that go together, so the
/// kind is never told by colour alone.
enum ToolsNoteTone {
  /// Something failed or Hermes refused.
  error,

  /// Something could not be confirmed, or needs attention.
  warning,

  /// Muted and plain.
  info,
}

/// A line under a section about the last thing that was tried there: an
/// error, a warning, Hermes' own refusal. It is a live region, so a screen
/// reader announces it when it appears, and may carry one action ("Try
/// again", "Check again").
///
/// It takes the words from the caller; Hermes' text is shown as given.
class ToolsNote extends StatelessWidget {
  const ToolsNote({
    super.key,
    required this.tone,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final ToolsNoteTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final (icon, color) = switch (tone) {
      ToolsNoteTone.error => (
        AppIcons.error,
        Theme.of(context).colorScheme.error,
      ),
      ToolsNoteTone.warning => (AppIcons.questionCircleFilled, colors.warning),
      ToolsNoteTone.info => (AppIcons.info, colors.subtleText),
    };
    final action = actionLabel;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        8,
        metrics.rowPadding,
        0,
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
                icon: icon,
                text: text,
                color: color,
                size: metrics.subtitleSize,
                scaleIcon: true,
              ),
            ),
          ),
          if (action != null && onAction != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onAction,
                style: toolsButtonStyle(context),
                child: Text(action),
              ),
            ),
        ],
      ),
    );
  }
}
