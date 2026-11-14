import 'package:flutter/material.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:hermes_app/src/server_care/widgets/care_row_value.dart';
import 'package:hermes_app/src/server_care/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/server_care/widgets/server_attention_dot.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/server_care/widgets/server_status_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'mac_sidebar_use_cases.dart' show mac;

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

Widget _reduceMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

Future<void> _later() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

ServerStatusButton _fix(String label) =>
    ServerStatusButton(label: label, onPressed: _later);

ServerStatusButton get _showLogs =>
    ServerStatusButton(label: 'Show logs', onPressed: _later, outlined: true);

Widget _card(
  ServerStatusTone tone,
  String title, {
  String? detail,
  ServerStatusButton? button,
}) => frame(
  ServerStatusCard(tone: tone, title: title, detail: detail, button: button),
);

/// The Server screen's headline for each row of the design's table.
final _headlines =
    <(String, ServerStatusTone, String, String?, ServerStatusButton?)>[
      ('Loading', ServerStatusTone.loading, 'Checking Hermes…', null, null),
      (
        'Unreachable',
        ServerStatusTone.warning,
        "Can't reach Hermes",
        "Check that the server is on and that you're connected to its "
            'network.',
        _fix('Try again'),
      ),
      (
        'Store unreadable',
        ServerStatusTone.error,
        "Hermes can't read its session store",
        "Chats and usage may be missing until it's repaired.",
        _fix('Run a check'),
      ),
      (
        'Gateway failed',
        ServerStatusTone.error,
        'The messaging gateway stopped with an error',
        'Messaging channels and scheduled tasks are paused.',
        _fix('Restart gateway'),
      ),
      (
        'Gateway stale',
        ServerStatusTone.warning,
        "The messaging gateway isn't responding",
        "It's running but hasn't checked in for 7 minutes.",
        _fix('Restart gateway'),
      ),
      (
        'Gateway off',
        ServerStatusTone.warning,
        'The messaging gateway is off',
        "Messaging channels and scheduled tasks don't run while it's off.",
        _fix('Start gateway'),
      ),
      (
        'Disk critical',
        ServerStatusTone.error,
        'Disk almost full: 1.2 GB free',
        'Hermes may stop saving chats. Free up space on the server.',
        null,
      ),
      (
        'Out-of-memory restart',
        ServerStatusTone.warning,
        'Hermes restarted unexpectedly, probably out of memory',
        null,
        _showLogs,
      ),
      (
        'Channels offline',
        ServerStatusTone.warning,
        '1 of 2 messaging channels are offline',
        null,
        _showLogs,
      ),
      (
        'Memory low',
        ServerStatusTone.info,
        'Memory is low on the server',
        null,
        null,
      ),
      (
        'Disk elevated',
        ServerStatusTone.info,
        'Disk space is getting low: 8.4 GB free',
        null,
        null,
      ),
      (
        'Healthy',
        ServerStatusTone.healthy,
        'Everything looks good',
        'Hermes 0.22.2 · checked just now',
        null,
      ),
    ];

WidgetbookComponent _statusCard() => WidgetbookComponent(
  name: 'ServerStatusCard',
  useCases: [
    for (final (name, tone, title, detail, button) in _headlines)
      WidgetbookUseCase(
        name: name,
        builder: (_) => _card(tone, title, detail: detail, button: button),
      ),
    WidgetbookUseCase(
      name: 'Gateway restart running (no button)',
      builder: (_) => _card(
        ServerStatusTone.warning,
        "The messaging gateway isn't responding",
        detail: "It's running but hasn't checked in for 7 minutes.",
      ),
    ),
    ...onEachPlatform(
      'Gateway failed',
      (_) => _card(
        ServerStatusTone.error,
        'The messaging gateway stopped with an error',
        detail: 'Messaging channels and scheduled tasks are paused.',
        button: _fix('Restart gateway'),
      ),
    ),
    ...onEachPlatform(
      'Healthy',
      (_) => _card(
        ServerStatusTone.healthy,
        'Everything looks good',
        detail: 'Hermes 0.22.2 · checked just now',
      ),
    ),
    WidgetbookUseCase(
      name: 'Unreachable, largest text',
      builder: (_) => _largest(
        _card(
          ServerStatusTone.warning,
          "Can't reach Hermes",
          detail:
              "Check that the server is on and that you're connected to its "
              'network.',
          button: _fix('Try again'),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Out-of-memory restart, largest text',
      builder: (_) => _largest(
        _card(
          ServerStatusTone.warning,
          'Hermes restarted unexpectedly, probably out of memory',
          button: _showLogs,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Loading, Reduce Motion',
      builder: (_) =>
          _reduceMotion(_card(ServerStatusTone.loading, 'Checking Hermes…')),
    ),
    WidgetbookUseCase(
      name: 'Server check: problems',
      builder: (_) => _card(
        ServerStatusTone.error,
        '2 problems and 3 warnings',
        detail: 'Checked just now',
        button: ServerStatusButton(
          label: 'Run again',
          onPressed: _later,
          outlined: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Server check: all passed',
      builder: (_) => _card(
        ServerStatusTone.healthy,
        'All checks passed',
        detail: 'Checked just now',
        button: ServerStatusButton(
          label: 'Run again',
          onPressed: _later,
          outlined: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Server check: problems, largest text',
      builder: (_) => _largest(
        _card(
          ServerStatusTone.error,
          '2 problems and 3 warnings',
          detail: 'Checked just now',
          button: ServerStatusButton(
            label: 'Run again',
            onPressed: _later,
            outlined: true,
          ),
        ),
      ),
    ),
  ],
);

Widget _actionSection(
  String title,
  AppIconSet icon, {
  GroupedActionStatus? status,
}) => frame(
  GroupedSection(
    header: 'Messaging gateway',
    children: [
      GroupedActionRow(
        title: title,
        icon: icon,
        onPressed: _later,
        status: status,
      ),
    ],
  ),
);

GroupedActionButton _button(String label) =>
    GroupedActionButton(label: label, onPressed: _later);

List<(String, String, AppIconSet, GroupedActionStatus?)> get _actionStates => [
  ('Restart gateway', 'Restart gateway', AppIcons.refresh, null),
  ('Start gateway', 'Start gateway', AppIcons.play, null),
  (
    'Restarting…',
    'Restart gateway',
    AppIcons.refresh,
    const GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: 'Restarting…',
    ),
  ),
  (
    'Waiting for the gateway…',
    'Restart gateway',
    AppIcons.refresh,
    const GroupedActionStatus(
      phase: GroupedActionPhase.working,
      text: 'Waiting for the gateway…',
    ),
  ),
  (
    'Running again',
    'Restart gateway',
    AppIcons.refresh,
    const GroupedActionStatus(
      phase: GroupedActionPhase.done,
      text: 'Running again',
    ),
  ),
  (
    "Didn't restart",
    'Restart gateway',
    AppIcons.refresh,
    GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text: "The gateway didn't restart",
      buttons: [_button('Show logs'), _button('Try again')],
    ),
  ),
  (
    "Hasn't come back yet",
    'Restart gateway',
    AppIcons.refresh,
    GroupedActionStatus(
      phase: GroupedActionPhase.warning,
      text: "The gateway hasn't come back yet",
      buttons: [_button('Show logs')],
    ),
  ),
  (
    'Refused',
    'Restart gateway',
    AppIcons.refresh,
    const GroupedActionStatus(
      phase: GroupedActionPhase.failed,
      text: 'Another restart is already in progress.',
    ),
  ),
];

WidgetbookComponent _actionRow() => WidgetbookComponent(
  name: 'GroupedActionRow',
  useCases: [
    for (final (name, title, icon, status) in _actionStates)
      ...onEachPlatform(
        name,
        (_) => _actionSection(title, icon, status: status),
      ),
    WidgetbookUseCase(
      name: "Didn't restart, largest text",
      builder: (_) => _largest(
        _actionSection(
          'Restart gateway',
          AppIcons.refresh,
          status: _actionStates[5].$4,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Restarting…, Reduce Motion',
      builder: (_) => _reduceMotion(
        _actionSection(
          'Restart gateway',
          AppIcons.refresh,
          status: _actionStates[2].$4,
        ),
      ),
    ),
  ],
);

Widget _serverSections({
  bool diskElevated = false,
  bool updating = false,
  GroupedActionStatus? gatewayStatus,
}) => frame(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        header: 'Hermes',
        children: [
          const CareValueRow(
            title: 'Version',
            value: '0.22.2',
            subtitle: 'Released 2 Nov 2026',
          ),
          Column(
            children: [
              CareValueRow(
                title: 'Updates',
                value: updating ? 'Updating…' : 'Update available',
                subtitle: updating ? null : '12 changes',
                onTap: _later,
              ),
              if (updating)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: BusyBar(minHeight: 3),
                ),
            ],
          ),
        ],
      ),
      GroupedSection(
        header: 'Messaging gateway',
        footer:
            "Runs your messaging channels and scheduled tasks. Chats in this "
            "app don't depend on it.",
        children: [
          const CareValueRow(
            title: 'State',
            value: 'Running, some channels offline',
          ),
          const CareValueRow(title: 'Channels', value: '1 of 2 connected'),
          const CareValueRow(title: 'Shared with', value: 'default, work'),
          GroupedActionRow(
            title: 'Restart gateway',
            icon: AppIcons.refresh,
            onPressed: _later,
            status: gatewayStatus,
          ),
        ],
      ),
      GroupedSection(
        header: 'Server',
        children: [
          CareValueRow(
            title: 'Disk',
            value: diskElevated ? '8.4 GB free' : '38 GB free',
            subtitle: diskElevated ? '91% used' : '62% used',
            warning: diskElevated ? 'Disk space is getting low.' : null,
          ),
          const CareValueRow(title: 'Memory', value: 'OK'),
          const CareValueRow(title: 'Session store', value: 'OK'),
        ],
      ),
      GroupedSection(
        header: 'Tools',
        children: [
          CareValueRow(
            title: 'Usage',
            subtitle: 'Tokens and cost by day and model',
            onTap: _later,
          ),
          CareValueRow(
            title: 'Logs',
            subtitle: "Recent lines from Hermes' logs",
            onTap: _later,
          ),
          CareValueRow(
            title: 'Run a check',
            subtitle: '2 problems · checked 5 min ago',
            onTap: _later,
          ),
        ],
      ),
    ],
  ),
);

WidgetbookComponent _serverRows() => WidgetbookComponent(
  name: 'Server screen sections',
  useCases: [
    ...onEachPlatform('Default text', (_) => _serverSections()),
    WidgetbookUseCase(
      name: 'Largest text',
      builder: (_) => _largest(_serverSections()),
    ),
    WidgetbookUseCase(
      name: 'Disk elevated, update running',
      builder: (_) => _serverSections(diskElevated: true, updating: true),
    ),
    WidgetbookUseCase(
      name: 'Disk elevated, largest text',
      builder: (_) => _largest(_serverSections(diskElevated: true)),
    ),
    WidgetbookUseCase(
      name: 'Gateway restart failed, largest text',
      builder: (_) =>
          _largest(_serverSections(gatewayStatus: _actionStates[5].$4)),
    ),
  ],
);

Widget _accountAvatar({required bool attention}) => Builder(
  builder: (context) => ServerAttentionBadge(
    show: attention,
    child: CircleAvatar(
      radius: 14,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: AppIcon(
        AppIcons.person,
        size: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  ),
);

Widget _menuItem(Widget child) => ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 48),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Align(alignment: Alignment.centerLeft, child: child),
  ),
);

/// The account menu's items as a popup lays them out; a real
/// [PopupMenuItem] only builds inside an open menu.
Widget _menuRow({required bool attention}) => frame(
  maxWidth: 280,
  Builder(
    builder: (context) => Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _menuItem(const Text('Connection details')),
          _menuItem(
            ServerMenuItemLabel(
              label: attention ? 'Server · needs attention' : 'Server',
              needsAttention: attention,
            ),
          ),
          _menuItem(const Text('About')),
        ],
      ),
    ),
  ),
);

Widget _macRow(String? caption) => mac(
  Builder(
    builder: (context) => fill(
      width: 240,
      Container(
        color: context.hermesColors.sidebar,
        padding: const EdgeInsets.all(8),
        child: MacSourceListRow(
          icon: AppIcons.server,
          label: 'Server',
          caption: caption,
          onTap: () {},
        ),
      ),
    ),
  ),
);

WidgetbookComponent _attentionDot() => WidgetbookComponent(
  name: 'ServerAttentionDot',
  useCases: [
    WidgetbookUseCase(
      name: 'On the account avatar',
      builder: (_) => frame(
        Row(
          spacing: 24,
          children: [
            _accountAvatar(attention: false),
            _accountAvatar(attention: true),
          ],
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Menu row: needs attention',
      builder: (_) => _menuRow(attention: true),
    ),
    WidgetbookUseCase(
      name: 'Menu row: fine',
      builder: (_) => _menuRow(attention: false),
    ),
    WidgetbookUseCase(
      name: 'Menu row, largest text',
      builder: (_) => _largest(_menuRow(attention: true)),
    ),
    WidgetbookUseCase(
      name: 'Mac sidebar: no caption',
      builder: (_) => _macRow(null),
    ),
    WidgetbookUseCase(
      name: 'Mac sidebar: Needs attention',
      builder: (_) => _macRow('Needs attention'),
    ),
    WidgetbookUseCase(
      name: 'Mac sidebar: Updating…',
      builder: (_) => _macRow('Updating…'),
    ),
    WidgetbookUseCase(
      name: 'Mac sidebar: Restarting…',
      builder: (_) => _macRow('Restarting…'),
    ),
  ],
);

Widget _banner(ServerRestartBanner banner) =>
    fill(Padding(padding: const EdgeInsets.only(top: 8), child: banner));

WidgetbookComponent _restartBanner() => WidgetbookComponent(
  name: 'ServerRestartBanner',
  useCases: [
    WidgetbookUseCase(
      name: 'Restarting',
      builder: (_) => _banner(ServerRestartBanner.restarting(onTap: () {})),
    ),
    WidgetbookUseCase(
      name: 'Ready',
      builder: (_) =>
          _banner(ServerRestartBanner.ready(version: '0.23.0', onClose: () {})),
    ),
    WidgetbookUseCase(
      name: 'Ready, Reduce Motion (stays until closed)',
      builder: (_) => _reduceMotion(
        _banner(
          ServerRestartBanner.ready(
            version: '0.23.0',
            onClose: () {},
            onAutoDismiss: () {},
          ),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Restarting, largest text',
      builder: (_) =>
          _largest(_banner(ServerRestartBanner.restarting(onTap: () {}))),
    ),
    WidgetbookUseCase(
      name: 'Ready, largest text',
      builder: (_) => _largest(
        _banner(ServerRestartBanner.ready(version: '0.23.0', onClose: () {})),
      ),
    ),
  ],
);

List<WidgetbookNode> serverCareStatusNodes() => [
  _statusCard(),
  _actionRow(),
  _serverRows(),
  _attentionDot(),
  _restartBanner(),
];
