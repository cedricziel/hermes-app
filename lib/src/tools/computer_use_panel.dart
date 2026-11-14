import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/grouped_list.dart';
import 'computer_use_controller.dart';
import 'toolset_copy.dart';
import 'toolset_installs.dart';
import 'tools_controller.dart' show ToolsLoadState;
import 'tools_panel_env.dart';
import 'widgets/install_progress.dart';
import 'widgets/readiness_row.dart';
import 'widgets/tools_load_state.dart';
import 'widgets/tools_note.dart';

const _computerUse = 'computer_use';

/// "Readiness" in the Computer use details: what the server's computer has,
/// "Allow access" on a Mac server that is missing a permission, and, only when
/// the profile's Bot Screen is offered, "Open the bot's screen".
///
/// Allow access asks first and sends nothing until the user confirms; the
/// result is the status read again at the end, never the log. The section is
/// gone when Hermes has no such route, whatever the toolset list says. The
/// install step of the driver is the Set up area's, which is the one place
/// "Install on server" is.
class ComputerUsePanel extends StatefulWidget {
  const ComputerUsePanel({super.key, required this.env});

  final ToolsPanelEnv env;

  @override
  State<ComputerUsePanel> createState() => _ComputerUsePanelState();
}

class _ComputerUsePanelState extends State<ComputerUsePanel> {
  late ComputerUseController _controller;
  ToolsInstallState? _handledEnd;

  @override
  void initState() {
    super.initState();
    _controller = ComputerUseController(
      widget.env.repository,
      telemetry: widget.env.repository.telemetry,
      confirmGrant: () =>
          widget.env.ask(toolsetAllowAccessQuestion(context.l10n)),
    );
    unawaited(_controller.load());
    widget.env.refresh.add(_controller.load);
    widget.env.installs.addListener(_onInstalls);
  }

  @override
  void didUpdateWidget(ComputerUsePanel old) {
    super.didUpdateWidget(old);
    if (old.env.repository.profile != widget.env.repository.profile) {
      _controller.switchProfile(widget.env.repository);
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    widget.env.refresh.remove(_controller.load);
    widget.env.installs.removeListener(_onInstalls);
    _controller.dispose();
    super.dispose();
  }

  /// The driver's install ended: the readiness reads again.
  void _onInstalls() {
    final state = widget.env.installs.state;
    if (state == null ||
        state.toolset != _computerUse ||
        state.active ||
        identical(state, _handledEnd)) {
      return;
    }
    _handledEnd = state;
    unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.env.botScreen;
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, ?link?.changes]),
      builder: (context, _) {
        final l10n = context.l10n;
        final state = _controller.loadState;
        if (state == ToolsLoadState.unsupported ||
            state == ToolsLoadState.profileGone) {
          return const SizedBox.shrink();
        }
        final status = _controller.status;
        if (!_controller.hasLoaded || status == null) {
          return GroupedSection(
            header: l10n.toolsReadinessHeader,
            children: [
              if (state == ToolsLoadState.loading)
                ToolsLoadingRow(l10n.toolsReadinessLoading)
              else
                ToolsFailureRow(
                  text: l10n.toolsReadFailed,
                  onRetry: () => unawaited(_controller.load()),
                ),
            ],
          );
        }
        final offered = link != null && link.offered();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReadinessSection(
              items: readinessItems(l10n, status),
              details: [
                for (final check in status.checks)
                  ReadinessDetail(
                    label: check.label,
                    text: check.message ?? check.status,
                  ),
              ],
              errorText: status.error,
              onOpenBotScreen: offered ? link.open : null,
              onAllowAccess: _controller.canOfferGrant
                  ? () => unawaited(_controller.grant())
                  : null,
            ),
            ?_grant(context),
          ],
        );
      },
    );
  }

  /// The permission window's progress and what went wrong with it.
  Widget? _grant(BuildContext context) {
    final l10n = context.l10n;
    final desktop = toolsOnDesktop(context);
    switch (_controller.grantPhase) {
      case ComputerUseGrantPhase.idle:
      case ComputerUseGrantPhase.starting:
      case ComputerUseGrantPhase.finished:
        return null;
      case ComputerUseGrantPhase.running:
        return InstallProgress(
          header: l10n.toolsGrantHeader,
          runningTitle: l10n.toolsGrantRunning,
          phase: InstallPhase.running,
          lines: _controller.grantLines,
          extra: _controller.followFailing
              ? ToolsNote(
                  tone: ToolsNoteTone.warning,
                  text: l10n.toolsGrantFollowRetrying,
                )
              : null,
        );
      case ComputerUseGrantPhase.checking:
        return InstallProgress(
          header: l10n.toolsGrantHeader,
          phase: InstallPhase.checking,
          lines: const [],
        );
      case ComputerUseGrantPhase.unconfirmed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_controller.followLost)
              ToolsNote(
                tone: ToolsNoteTone.warning,
                text: l10n.toolsGrantFollowLost,
                actionLabel: l10n.toolsCheckAgain,
                onAction: _controller.checkAgain,
              ),
            ToolsNote(
              tone: ToolsNoteTone.warning,
              text: desktop
                  ? l10n.toolsRowUnconfirmedRetry
                  : l10n.toolsRowUnconfirmedPull,
              actionLabel: desktop ? l10n.toolsTryAgain : null,
              onAction: desktop ? () => unawaited(_controller.load()) : null,
            ),
          ],
        );
      case ComputerUseGrantPhase.refused:
        return ToolsNote(
          tone: ToolsNoteTone.error,
          text: (_controller.refusalDetail?.trim().isNotEmpty ?? false)
              ? _controller.refusalDetail!
              : l10n.toolsGrantFailed,
        );
      case ComputerUseGrantPhase.failed:
        return ToolsNote(
          tone: ToolsNoteTone.error,
          text: l10n.toolsGrantFailed,
        );
    }
  }
}
