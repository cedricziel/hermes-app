import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../widgets/adaptive_dialog.dart';
import 'gateway_restart.dart';
import 'server_care_controller.dart';
import 'server_status.dart';
import 'widgets/grouped_action_row.dart';

/// The lines of the restart confirmation, from what the status says: the app's
/// chats keep running, messaging pauses, how many messaging conversations
/// stop, and, on a shared gateway, whose bots reconnect too. Profile names are
/// the server's own list, shown and never logged.
List<String> gatewayConfirmationLines(
  AppLocalizations l10n,
  ServerStatus? status,
) {
  final shared = status?.gatewaySharedWith ?? const <String>[];
  return [
    l10n.serverCareGatewayConfirmKeepRunning,
    l10n.serverCareGatewayConfirmPause,
    if ((status?.activeAgents ?? 0) > 0)
      l10n.serverCareGatewayConfirmConversations(status!.activeAgents),
    if (shared.length > 1)
      l10n.serverCareGatewayConfirmShared(shared.join(', ')),
  ];
}

/// Asks first for a restart (it stops conversations on messaging channels
/// without draining), then runs [action]. A start needs no confirmation. A
/// press while a run is going joins it. Does nothing while no profile is
/// known.
Future<void> runGatewayAction(
  BuildContext context,
  GatewayAction action,
) async {
  final care = context.read<ServerCareController>();
  final run = context.read<GatewayRestart>();
  final l10n = context.l10n;
  final profile = care.profile;
  if (profile == null) return;
  // One run at a time; another profile's is not this one's to join.
  if (run.busy && run.profile != profile) return;
  if (!run.busy && action == GatewayAction.restart) {
    final shared = (care.status?.gatewaySharedWith.length ?? 0) > 1;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.serverCareGatewayConfirmRestartTitle,
      message: gatewayConfirmationLines(l10n, care.status).join('\n\n'),
      confirmLabel: shared
          ? l10n.serverCareGatewayConfirmRestartAll
          : l10n.serverCareGatewayConfirmRestart,
      cancelLabel: l10n.serverCareCancel,
      filled: false,
    );
    if (!confirmed || !context.mounted) return;
  }
  if (!run.busy && action == GatewayAction.restart) run.confirmed(action);
  await run.run(action, profile: profile);
}

/// What the gateway row says about a run: the progress while it goes, the
/// outcome after, with Hermes' own text for a refusal. Null when idle.
GroupedActionStatus? gatewayRowStatus(
  AppLocalizations l10n,
  GatewayRestart run, {
  required VoidCallback onTryAgain,
}) {
  final starting = run.action == GatewayAction.start;
  return switch (run.phase) {
    GatewayPhase.idle => null,
    GatewayPhase.starting => GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: starting
          ? l10n.serverCareGatewayStarting
          : l10n.serverCareGatewayRestarting,
    ),
    GatewayPhase.waiting || GatewayPhase.returning => GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: l10n.serverCareGatewayWaiting,
    ),
    GatewayPhase.done => GroupedActionStatus(
      phase: GroupedActionPhase.done,
      text: l10n.serverCareGatewayBack,
    ),
    GatewayPhase.failed => GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text:
          run.message ??
          (starting
              ? l10n.serverCareGatewayStartFailed
              : l10n.serverCareGatewayRestartFailed),
      buttons: [
        GroupedActionButton(
          label: l10n.serverCareTryAgain,
          onPressed: onTryAgain,
        ),
      ],
    ),
    GatewayPhase.slow => GroupedActionStatus(
      phase: GroupedActionPhase.warning,
      text: l10n.serverCareGatewaySlow,
      buttons: [
        GroupedActionButton(
          label: l10n.serverCareTryAgain,
          onPressed: onTryAgain,
        ),
      ],
    ),
  };
}
