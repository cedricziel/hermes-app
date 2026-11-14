import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/busy_bar.dart';
import '../../widgets/grouped_list.dart';

/// How a [GroupedActionRow]'s action is going.
enum GroupedActionPhase {
  /// Running: the row shows the status text with a [BusyBar] and cannot be
  /// tapped.
  working,

  /// Finished well: the status text with a check mark in place of the title.
  done,

  /// Did not work: an error line under the row, which stays tappable.
  failed,

  /// Not settled: a warning line under the row, which stays tappable.
  warning,
}

/// A button under a [GroupedActionRow]'s status line.
class GroupedActionButton {
  const GroupedActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// What a [GroupedActionRow] says about its action.
class GroupedActionStatus {
  const GroupedActionStatus({
    required this.phase,
    required this.text,
    this.buttons = const [],
  });

  final GroupedActionPhase phase;
  final String text;

  /// Compact outlined buttons under an error or warning line.
  final List<GroupedActionButton> buttons;
}

/// A row of a [GroupedSection] that does something when tapped, such as
/// "Restart gateway": link-coloured with a leading [icon] on iOS and Material
/// (never red, since it asks first), a plain row on the Mac. Its [status]
/// shows the action's progress and outcome in the row.
class GroupedActionRow extends StatelessWidget {
  const GroupedActionRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.status,
  });

  final String title;
  final AppIconSet icon;
  final VoidCallback onPressed;
  final GroupedActionStatus? status;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final status = this.status;
    final working = status?.phase == GroupedActionPhase.working;
    final done = status?.phase == GroupedActionPhase.done;
    final accent = mac ? scheme.onSurface : scheme.primary;
    final shownTitle = (working || done) ? status!.text : title;
    final leadingColor = done ? colors.success : accent;
    final leading = done ? AppIcons.checkCircle : icon;
    final showLeading = !mac || done;
    final textStart = showLeading
        ? metrics.rowPadding + metrics.leadingSize + metrics.leadingGap
        : metrics.rowPadding;
    final line = switch (status?.phase) {
      GroupedActionPhase.failed => (AppIcons.error, scheme.error),
      GroupedActionPhase.warning => (AppIcons.warning, colors.warning),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Semantics(
            button: !working && !done,
            enabled: !working && !done,
            liveRegion: working || done,
            child: InkWell(
              onTap: working || done ? null : onPressed,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.rowPadding,
                    vertical: metrics.rowVerticalPadding,
                  ),
                  child: Row(
                    children: [
                      if (showLeading) ...[
                        ExcludeSemantics(
                          child: AppIcon(
                            leading,
                            size: metrics.leadingSize,
                            color: leadingColor,
                          ),
                        ),
                        SizedBox(width: metrics.leadingGap),
                      ],
                      Expanded(
                        child: Text(
                          shownTitle,
                          style: TextStyle(
                            fontSize: metrics.titleSize,
                            color: done ? colors.success : accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (working)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              textStart,
              0,
              metrics.rowPadding,
              12,
            ),
            child: const BusyBar(minHeight: 3),
          ),
        if (status != null && line != null)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              textStart,
              0,
              metrics.rowPadding,
              status.buttons.isEmpty ? 10 : 6,
            ),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: ExcludeSemantics(
                      child: AppIcon(
                        line.$1,
                        size: metrics.subtitleSize,
                        color: line.$2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      status.text,
                      style: TextStyle(
                        fontSize: metrics.subtitleSize,
                        color: line.$2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (status != null && status.buttons.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              textStart,
              0,
              metrics.rowPadding,
              12,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final button in status.buttons)
                  OutlinedButton(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: button.onPressed,
                    child: Text(button.label),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
