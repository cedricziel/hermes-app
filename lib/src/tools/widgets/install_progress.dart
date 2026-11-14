import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/install_parts.dart';
import 'tools_target.dart';

/// Where an install on the server stands.
enum InstallPhase {
  /// The app started it and Hermes reports its lines.
  running,

  /// Switching a tool on made Hermes start it.
  startedBySwitch,
  done,
  failed,

  /// The app lost track and could not read how it ended.
  unknown,
}

/// How many of the installer's lines are shown.
const kInstallLinesShown = 6;

/// The "Install on server" section while and after an install runs. A running
/// install shows a spinner, the title, a muted line saying the user can leave
/// and the installer's last six lines, each its own selectable monospace
/// line, all as one live region. A failed one says nothing changed, shows the
/// lines and offers a filled Try again.
class InstallProgress extends StatelessWidget {
  const InstallProgress({
    super.key,
    required this.phase,
    required this.lines,
    this.onTryAgain,
  });

  final InstallPhase phase;
  final List<String> lines;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final shown = lines.length > kInstallLinesShown
        ? lines.sublist(lines.length - kInstallLinesShown)
        : lines;
    Widget status(AppIconSet icon, Color color, String text) => Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: GroupedStatusLine(
          icon: icon,
          text: text,
          color: color,
          size: metrics.titleSize,
        ),
      ),
    );
    final body = switch (phase) {
      InstallPhase.running ||
      InstallPhase.startedBySwitch => InstallRunningBody(
        title: phase == InstallPhase.running
            ? l10n.toolsInstallRunning
            : l10n.toolsInstallStartedBySwitch,
        lines: shown,
        note: l10n.toolsInstallLeave,
        selectableLines: true,
        liveRegion: true,
      ),
      InstallPhase.done => status(
        AppIcons.checkCircleFilled,
        colors.success,
        l10n.toolsInstallDone,
      ),
      InstallPhase.unknown => status(
        AppIcons.questionCircleFilled,
        colors.warning,
        l10n.toolsInstallUnknown,
      ),
      InstallPhase.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            container: true,
            label:
                '${l10n.toolsInstallFailed} ${l10n.toolsInstallFailedNothing}',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GroupedStatusLine(
                    icon: AppIcons.error,
                    text: l10n.toolsInstallFailed,
                    color: Theme.of(context).colorScheme.error,
                    size: metrics.titleSize,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.toolsInstallFailedNothing,
                    style: TextStyle(
                      fontSize: metrics.subtitleSize,
                      color: colors.subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 8),
            InstallLogLines(shown, selectable: true),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onTryAgain,
            style: toolsButtonStyle(context, wide: true),
            child: Text(l10n.toolsTryAgain),
          ),
        ],
      ),
    };
    return GroupedSection(
      header: l10n.toolsInstallHeader,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.rowPadding,
            vertical: 12,
          ),
          child: body,
        ),
      ],
    );
  }
}

/// The "Install on server" button. It is the filled button exactly when the
/// provider [needsSetup], with the helper "Needed before this works. The app
/// asks first."; otherwise it is the quiet "Run the install step again" that
/// sits under Advanced. While another install runs it is disabled and says
/// so.
class ToolsInstallButton extends StatelessWidget {
  const ToolsInstallButton({
    super.key,
    required this.needsSetup,
    required this.onPressed,
    this.anotherRunning = false,
  });

  final bool needsSetup;
  final VoidCallback? onPressed;
  final bool anotherRunning;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final onPressed = anotherRunning ? null : this.onPressed;
    if (!needsSetup) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: onPressed,
          style: toolsButtonStyle(context),
          child: Text(
            anotherRunning
                ? l10n.toolsInstallAnotherRunning
                : l10n.toolsInstallAgain,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onPressed,
          style: toolsButtonStyle(context, wide: true),
          icon: ExcludeSemantics(child: AppIcon(AppIcons.download, size: 18)),
          label: Text(
            anotherRunning
                ? l10n.toolsInstallAnotherRunning
                : l10n.toolsInstallButton,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            6,
            metrics.rowPadding,
            0,
          ),
          child: Text(
            l10n.toolsInstallHelper,
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ],
    );
  }
}
