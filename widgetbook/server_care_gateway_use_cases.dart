import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/gateway_actions.dart';
import 'package:hermes_app/src/server_care/server_status.dart';
import 'package:hermes_app/src/server_care/widgets/gateway_restart_dialog.dart';
import 'package:hermes_app/src/server_care/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/server_care/widgets/server_status_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// The gateway's restart and start states, in the language the locale addon
// picks. The copy is the screen's own (ARB keys), so a German check here is a
// German check of the screen.

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

Future<void> _later() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

const _alone = ServerStatus(gatewayRunning: true);
const _busy = ServerStatus(gatewayRunning: true, activeAgents: 2);
const _shared = ServerStatus(
  gatewayRunning: true,
  activeAgents: 3,
  gatewaySharedWith: ['default', 'work'],
);

/// The dialog open over a dimmed page, as the screen shows it.
Widget _dialog(ServerStatus status) => Builder(
  builder: (context) {
    final l10n = context.l10n;
    final shared = status.gatewaySharedWith.length > 1;
    return Container(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: GatewayRestartDialog(
        title: l10n.serverCareGatewayConfirmRestartTitle,
        lines: gatewayConfirmationLines(l10n, status),
        confirmLabel: shared
            ? l10n.serverCareGatewayConfirmRestartAll
            : l10n.serverCareGatewayConfirmRestart,
        cancelLabel: l10n.serverCareCancel,
      ),
    );
  },
);

WidgetbookComponent _confirmation() => WidgetbookComponent(
  name: 'GatewayRestartDialog',
  useCases: [
    for (final (name, status) in [
      ('Plain', _alone),
      ('With running conversations', _busy),
      ('Shared gateway, Restart for all', _shared),
    ])
      ...onEachPlatform(name, (_) => _dialog(status)),
    WidgetbookUseCase(
      name: 'Shared gateway, largest text',
      builder: (_) => _largest(_dialog(_shared)),
    ),
    // The Material dialog sets its own surface on the dark scaffold, so its
    // edge shows against the scrim; forced dark here whatever the toolbar says.
    WidgetbookUseCase(
      name: 'Material dark, edge visible',
      builder: (_) => Theme(
        data: buildHermesDarkTheme(platform: TargetPlatform.android),
        child: _dialog(_shared),
      ),
    ),
  ],
);

ServerStatusCard _headline(
  ServerStatusTone tone,
  String title, {
  String? detail,
  String? button,
}) => ServerStatusCard(
  tone: tone,
  title: title,
  detail: detail,
  button: button == null
      ? null
      : ServerStatusButton(label: button, onPressed: _later),
);

List<(String, Widget Function(BuildContext))> get _headlines => [
  (
    'Restarting',
    (c) => _headline(
      ServerStatusTone.loading,
      c.l10n.serverCareGatewayHeadlineRestarting,
    ),
  ),
  (
    'Starting',
    (c) => _headline(
      ServerStatusTone.loading,
      c.l10n.serverCareGatewayHeadlineStarting,
    ),
  ),
  (
    'Failed, Restart button',
    (c) => _headline(
      ServerStatusTone.error,
      c.l10n.serverCareHeadlineGatewayFailed,
      detail: c.l10n.serverCareHeadlineGatewayFailedDetail,
      button: c.l10n.serverCareGatewayRestart,
    ),
  ),
  (
    'Off, Start button',
    (c) => _headline(
      ServerStatusTone.warning,
      c.l10n.serverCareHeadlineGatewayOff,
      detail: c.l10n.serverCareHeadlineGatewayOffDetail,
      button: c.l10n.serverCareGatewayStart,
    ),
  ),
];

WidgetbookComponent _headlineCards() => WidgetbookComponent(
  name: 'Gateway headline',
  useCases: [
    for (final (name, build) in _headlines)
      WidgetbookUseCase(name: name, builder: (c) => frame(build(c))),
    WidgetbookUseCase(
      name: 'Failed, largest text',
      builder: (c) => _largest(frame(_headlines[2].$2(c))),
    ),
  ],
);

GroupedActionButton _showLogs(BuildContext c) =>
    GroupedActionButton(label: c.l10n.serverCareShowLogs, onPressed: _later);

GroupedActionButton _tryAgain(BuildContext c) =>
    GroupedActionButton(label: c.l10n.serverCareTryAgain, onPressed: _later);

Widget _row(
  BuildContext context, {
  required bool restart,
  GroupedActionStatus? status,
}) {
  final l10n = context.l10n;
  return frame(
    GroupedSection(
      header: l10n.serverCareGatewayHeader,
      children: [
        GroupedActionRow(
          title: restart
              ? l10n.serverCareGatewayRestart
              : l10n.serverCareGatewayStart,
          icon: restart ? AppIcons.refresh : AppIcons.play,
          onPressed: _later,
          status: status,
        ),
      ],
    ),
  );
}

List<(String, bool, GroupedActionStatus? Function(BuildContext))>
get _rowStates => [
  ('Idle, Restart', true, (_) => null),
  ('Idle, Start', false, (_) => null),
  (
    'Restarting',
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: c.l10n.serverCareGatewayRestarting,
    ),
  ),
  (
    'Starting',
    false,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: c.l10n.serverCareGatewayStarting,
    ),
  ),
  (
    'Waiting for the gateway',
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: c.l10n.serverCareGatewayWaiting,
    ),
  ),
  (
    'Running again',
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.done,
      text: c.l10n.serverCareGatewayBack,
    ),
  ),
  (
    "Didn't restart",
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text: c.l10n.serverCareGatewayRestartFailed,
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
  (
    "Didn't start",
    false,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text: c.l10n.serverCareGatewayStartFailed,
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
  (
    "Refused, Hermes' own text",
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text: 'gateway restart already in progress for another profile',
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
  (
    "Couldn't confirm the restart (kept running, never seen down)",
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.warning,
      text: c.l10n.serverCareGatewayUnconfirmed,
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
  (
    "Hasn't come back",
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.warning,
      text: c.l10n.serverCareGatewaySlow,
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
  (
    // A child that exited non-zero: the last five lines of its log, as Hermes
    // wrote them, in place of the generic sentence.
    'Exited, five-line log tail',
    true,
    (c) => GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text:
          'hermes gateway restart: stopping gateway (pid 4321)\n'
          'hermes gateway restart: waiting for the old process to exit\n'
          'hermes gateway restart: old process did not exit after 30 s\n'
          'hermes gateway restart: sending SIGKILL\n'
          "hermes gateway restart: error: couldn't remove the lock file",
      buttons: [_showLogs(c), _tryAgain(c)],
    ),
  ),
];

/// A row state by its name, so the largest-text cases cannot drift when a
/// state is added to the list.
(String, bool, GroupedActionStatus? Function(BuildContext)) _rowState(
  String name,
) => _rowStates.firstWhere((state) => state.$1 == name);

WidgetbookComponent _gatewayRow() => WidgetbookComponent(
  name: 'Gateway row',
  useCases: [
    for (final (name, restart, status) in _rowStates)
      ...onEachPlatform(
        name,
        (c) => _row(c, restart: restart, status: status(c)),
      ),
    WidgetbookUseCase(
      name: "Refused, largest text",
      builder: (c) => _largest(
        _row(
          c,
          restart: true,
          status: _rowState("Refused, Hermes' own text").$3(c),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Exited, five-line log tail, largest text',
      builder: (c) => _largest(
        _row(
          c,
          restart: true,
          status: _rowState('Exited, five-line log tail').$3(c),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: "Couldn't confirm, largest text",
      builder: (c) => _largest(
        _row(
          c,
          restart: true,
          status: _rowState(
            "Couldn't confirm the restart (kept running, never seen down)",
          ).$3(c),
        ),
      ),
    ),
  ],
);

List<WidgetbookNode> serverCareGatewayNodes() => [
  _confirmation(),
  _headlineCards(),
  _gatewayRow(),
];
