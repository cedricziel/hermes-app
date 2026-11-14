import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/widgets/private_surface.dart';
import 'package:hermes_app/src/server_care/widgets/server_check_body.dart';
import 'package:hermes_app/src/server_care/widgets/server_check_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _largest(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child,
);

/// The page as the person sees it: the bar under the title, [body] below.
Widget _page(ServerCheckView view, {bool largest = false}) => Builder(
  builder: (context) {
    final l10n = context.l10n;
    final body = ServerCheckBody(
      view: view,
      onRun: () {},
      onKeepWaiting: () {},
      onDismiss: () {},
    );
    return pushed(
      SettingsScaffold(
        title: l10n.serverCareCheckPageTitle,
        subtitle: 'default',
        previousTitle: l10n.serverCareTitle,
        body: largest ? _largest(context, body) : body,
      ),
    );
  },
);

const _problems = [
  CheckFinding(
    title: 'Telegram token rejected (401)',
    detail: 'The bot token in config.yaml is no longer valid',
    group: 'Messaging',
  ),
  CheckFinding(
    title: 'Discord channel not found',
    group: 'Messaging',
    note: 'Re-invite the bot, then restart the gateway',
  ),
];

const _warnings = [
  CheckFinding(
    title: 'Config version 30 is behind 31',
    detail: "run 'hermes config migrate'",
    note: 'Older keys still work',
    group: 'Configuration',
  ),
  CheckFinding(
    title: 'Disk is 91% full',
    detail: '4.1 GB free',
    group: 'System',
  ),
  CheckFinding(title: 'No skills directory yet', group: 'Skills'),
];

const _fixes = [
  CheckFix(
    text: "Re-run 'hermes setup telegram'",
    command: 'hermes setup telegram',
  ),
  CheckFix(text: 'Invite the Discord bot to the channel again'),
  CheckFix(
    text: "Migrate the config with 'hermes config migrate'",
    command: 'hermes config migrate',
  ),
];

const _passed = [
  CheckPassedGroup(
    title: 'Configuration',
    items: [
      'config.yaml found',
      'API keys present',
      'Model provider reachable',
      'Config is valid YAML',
    ],
  ),
  CheckPassedGroup(
    title: 'Storage',
    items: [
      'Session store opens',
      'Memory store opens',
      'Skills directory writable',
    ],
  ),
  CheckPassedGroup(
    title: 'Messaging',
    items: ['Gateway process found', 'Telegram connected'],
  ),
];

const _unknown = [
  CheckUnknownLine(
    text: 'Plugin cache rebuilt (3 entries)',
    group: 'Configuration',
  ),
  CheckUnknownLine(text: 'something unexpected', group: 'Messaging'),
];

ServerCheckView _problemsView() => const ServerCheckView.result(
  problems: _problems,
  warnings: _warnings,
  fixes: _fixes,
  passed: _passed,
  checkedAgo: 'just now',
);

/// The Tools section of the Server screen with the check row in [row]'s state.
Widget _toolsSection(ServerCheckRow row, {bool largest = false}) => Builder(
  builder: (context) {
    final section = GroupedSection(
      header: 'Tools',
      children: [
        GroupedRow(title: 'Usage', onTap: () {}),
        GroupedRow(title: 'Logs', onTap: () {}),
        row,
      ],
    );
    return frame(largest ? _largest(context, section) : section);
  },
);

List<WidgetbookNode> serverCareCheckNodes() => [
  WidgetbookComponent(
    name: 'ServerCheckRow',
    useCases: [
      ...onEachPlatform(
        'Before a run',
        (_) => _toolsSection(
          ServerCheckRow(state: ServerCheckRowState.idle, onTap: () {}),
        ),
      ),
      ...onEachPlatform(
        'Checking…',
        (_) => _toolsSection(
          ServerCheckRow(state: ServerCheckRowState.running, onTap: () {}),
        ),
      ),
      WidgetbookUseCase(
        name: 'Last result',
        builder: (_) => _toolsSection(
          ServerCheckRow(
            state: ServerCheckRowState.result,
            summary: '2 problems and 3 warnings',
            ago: '5 minutes ago',
            onTap: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Checking…, largest text',
        builder: (_) => _toolsSection(
          ServerCheckRow(state: ServerCheckRowState.running, onTap: () {}),
          largest: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'Last result, largest text',
        builder: (_) => _toolsSection(
          ServerCheckRow(
            state: ServerCheckRowState.result,
            summary: '2 problems and 3 warnings',
            ago: '5 minutes ago',
            onTap: () {},
          ),
          largest: true,
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'Server check page',
    useCases: [
      ...onEachPlatform(
        'Before a run',
        (_) => _page(const ServerCheckView.intro()),
      ),
      WidgetbookUseCase(
        name: 'Running, nothing yet',
        builder: (_) => _page(const ServerCheckView.running()),
      ),
      WidgetbookUseCase(
        name: 'Running, 14 checks so far',
        builder: (_) => _page(const ServerCheckView.running(checksSoFar: 14)),
      ),
      ...onEachPlatform('Problems and warnings', (_) => _page(_problemsView())),
      WidgetbookUseCase(
        name: 'One problem',
        builder: (_) => _page(
          const ServerCheckView.result(
            problems: [
              CheckFinding(
                title: 'Hermes cannot read its session store',
                detail: 'state.db is locked',
                group: 'Storage',
              ),
            ],
            fixes: [CheckFix(text: 'Stop the other Hermes process')],
            passed: _passed,
            checkedAgo: '5 minutes ago',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Warnings only',
        builder: (_) => _page(
          const ServerCheckView.result(
            warnings: _warnings,
            passed: _passed,
            checkedAgo: 'just now',
          ),
        ),
      ),
      ...onEachPlatform(
        'All passed',
        (_) => _page(
          const ServerCheckView.result(
            allPassed: true,
            passed: _passed,
            checkedAgo: 'just now',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Unknown lines among the findings',
        builder: (_) => _page(
          const ServerCheckView.result(
            problems: _problems,
            fixes: _fixes,
            unknown: _unknown,
            passed: _passed,
            checkedAgo: 'just now',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Output the app does not know',
        builder: (_) => _page(
          const ServerCheckView.result(
            unknown: [
              CheckUnknownLine(text: 'Hermes 0.31 doctor: 12 probes run'),
              CheckUnknownLine(text: 'probe storage: ok'),
              CheckUnknownLine(text: 'probe gateway: degraded (1 channel)'),
            ],
            checkedAgo: 'just now',
          ),
        ),
      ),
      ...onEachPlatform(
        'Taking longer',
        (_) => _page(const ServerCheckView.timeout()),
      ),
      WidgetbookUseCase(
        name: "Couldn't start (Hermes' words)",
        builder: (_) => _page(
          const ServerCheckView.failed(
            failure: ServerCheckFailureKind.refused,
            message: 'doctor is already running',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Stopped early',
        builder: (_) => _page(
          const ServerCheckView.failed(
            failure: ServerCheckFailureKind.exited,
            message: 'Traceback (most recent call last):\nValueError: boom',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: "Can't reach Hermes",
        builder: (_) => _page(
          const ServerCheckView.failed(
            failure: ServerCheckFailureKind.unreachable,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Problems, largest text',
        builder: (_) => _page(_problemsView(), largest: true),
      ),
      WidgetbookUseCase(
        name: 'All passed, largest text',
        builder: (_) => _page(
          const ServerCheckView.result(
            allPassed: true,
            passed: _passed,
            checkedAgo: 'just now',
          ),
          largest: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'Taking longer, largest text',
        builder: (_) => _page(const ServerCheckView.timeout(), largest: true),
      ),
      WidgetbookUseCase(
        name: 'Blank while the app is inactive',
        builder: (_) =>
            PrivateSurface(blank: true, child: _page(_problemsView())),
      ),
    ],
  ),
];
