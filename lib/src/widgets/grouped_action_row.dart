import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'busy_bar.dart';
import 'grouped_list.dart';
import 'motion_spinner.dart';

/// How a [GroupedActionRow]'s action is going.
enum GroupedActionPhase {
  /// Running: the row shows the status text with a [BusyBar] and cannot be
  /// tapped.
  working,

  /// Finished well: the status text with a check mark in place of the title.
  done,

  /// Did not work: an error line under the row, which stays tappable.
  failed,

  /// Not a problem, but not settled either: a muted line with an info icon
  /// under the row, such as "Still running on the server."
  neutral,

  /// Not settled: a warning line under the row, which stays tappable.
  warning,
}

/// A button under a [GroupedActionRow]'s status line.
class GroupedActionButton {
  const GroupedActionButton({required this.label, required this.onPressed});

  final String label;

  /// Null disables the button, such as while a check is on its way.
  final VoidCallback? onPressed;
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
///
/// A null [onPressed] disables the row: it reads as a disabled button and
/// ignores taps, and its [status] line and buttons still work. With
/// [spinnerWhileWorking] the working phase leads with a spinner, on the Mac
/// too, where the row has no icon otherwise. The icon and spinner follow the
/// text size.
class GroupedActionRow extends StatelessWidget {
  const GroupedActionRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.status,
    this.spinnerWhileWorking = false,
    this.semanticLabel,
  });

  final String title;
  final AppIconSet icon;
  final VoidCallback? onPressed;

  /// A muted line under the title, wrapping, above the status line. It stays
  /// while the action runs or is done, and is read with the title.
  final String? subtitle;
  final GroupedActionStatus? status;

  /// Replaces the leading icon with a spinner while the action works.
  final bool spinnerWhileWorking;

  /// Read in place of the title, subtitle and status text, for a row whose
  /// state needs a fuller name, such as "Run now, running".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final status = this.status;
    final subtitle = this.subtitle;
    final working = status?.phase == GroupedActionPhase.working;
    final done = status?.phase == GroupedActionPhase.done;
    final disabled = onPressed == null && !working && !done;
    final accent = disabled
        ? colors.subtleText
        : (mac ? scheme.onSurface : colors.link);
    final shownTitle = (working || done) ? status!.text : title;
    final leadingColor = done ? colors.success : accent;
    final leading = done ? AppIcons.checkCircle : icon;
    final spinner = working && spinnerWhileWorking;
    final showLeading = !mac || done || spinner;
    final scaler = MediaQuery.textScalerOf(context);
    final leadingSize = math.max(
      metrics.leadingSize,
      scaler.scale(metrics.leadingSize),
    );
    final textStart = showLeading
        ? metrics.rowPadding + leadingSize + metrics.leadingGap
        : metrics.rowPadding;
    final line = switch (status?.phase) {
      GroupedActionPhase.failed => (AppIcons.error, scheme.error),
      GroupedActionPhase.warning => (AppIcons.warning, colors.warning),
      GroupedActionPhase.neutral => (AppIcons.info, colors.subtleText),
      _ => null,
    };
    final buttonHeight = switch (platformChromeOf(context)) {
      PlatformChrome.macos => 28.0,
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Semantics(
            button: !working && !done,
            enabled: !working && !done && !disabled,
            liveRegion: working || done,
            label: semanticLabel,
            child: InkWell(
              onTap: working || done ? null : onPressed,
              child: ExcludeSemantics(
                excluding: semanticLabel != null,
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
                          spinner
                              ? SizedBox.square(
                                  dimension: leadingSize,
                                  child: const FittedBox(
                                    child: MotionSpinner(),
                                  ),
                                )
                              : ExcludeSemantics(
                                  child: AppIcon(
                                    leading,
                                    size: leadingSize,
                                    color: leadingColor,
                                  ),
                                ),
                          SizedBox(width: metrics.leadingGap),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shownTitle,
                                style: TextStyle(
                                  fontSize: metrics.titleSize,
                                  color: done ? colors.success : accent,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: metrics.subtitleSize,
                                    color: colors.subtleText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                        size: math.max(
                          metrics.subtitleSize,
                          scaler.scale(metrics.subtitleSize),
                        ),
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
                    style: ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(0, buttonHeight),
                      ),
                      visualDensity: VisualDensity.standard,
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
