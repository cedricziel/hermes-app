import 'package:flutter/material.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/command_row.dart';
import 'package:hermes_app/src/server_care/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_chip.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/log_line_tile.dart';
import 'package:hermes_app/src/server_care/widgets/update_status_card.dart';
import 'package:hermes_app/src/server_care/widgets/update_step_list.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The same widget at twice the text size, as the largest accessibility
/// setting would show it.
Widget _largest(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child,
);

Widget _reduceMotion(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child,
);

const _installLog = [
  'Fetching origin',
  'Updating 4e1c9a2..b7d03f1',
  'Fast-forward',
  ' 14 files changed, 311 insertions(+), 42 deletions(-)',
  'Installing dependencies',
  'Resolved 96 packages in 1.2s',
];

const _changes = [
  UpdateChange(
    summary: 'Keep the messaging gateway running while a profile is renamed',
    byline: 'mira · 3 days ago',
  ),
  UpdateChange(
    summary: 'Show the model name in scheduled task results',
    byline: 'jonas · 4 days ago',
  ),
  UpdateChange(
    summary: 'Fix a crash when a skill has no description',
    byline: 'mira · 6 days ago',
  ),
];

const _traceback = [
  'Traceback (most recent call last):',
  '  File "gateway/run.py", line 212, in run',
  '    await self._poll()',
  '  File "gateway/telegram.py", line 88, in _poll',
  '    updates = await self._client.get_updates()',
  '  File "gateway/http.py", line 41, in get_updates',
  '    raise ConnectionError(self._url)',
  '  File "gateway/http.py", line 37, in _request',
  '    return await self._session.get(url, timeout=30)',
  '  File "aiohttp/client.py", line 560, in _request',
  '    await resp.start(conn)',
  '  File "aiohttp/client_reqrep.py", line 899, in start',
  '    message, payload = await protocol.read()',
  '  File "aiohttp/streams.py", line 616, in read',
  '    await self._waiter',
  'ConnectionError: https://example.invalid/bot/getUpdates',
];

List<Widget> _everyLevel() => const [
  LogLineTile(
    time: '09:12:08',
    level: LogLevel.debug,
    source: 'agent.context',
    message: 'Loaded 14 skills in 62 ms',
  ),
  LogLineTile(
    time: '09:12:05',
    level: LogLevel.info,
    source: 'gateway.run',
    message: 'Connected to 2 messaging channels',
  ),
  LogLineTile(
    time: '09:12:03',
    level: LogLevel.warning,
    source: 'gateway.telegram',
    message: 'Polling is slow: the last request took 14 s',
  ),
  LogLineTile(
    time: '09:11:58',
    level: LogLevel.error,
    source: 'gateway.discord',
    message: 'Could not send a reply: the channel no longer exists',
  ),
  LogLineTile(
    time: '09:11:40',
    level: LogLevel.critical,
    source: 'sessions.store',
    message: 'The session store could not be opened',
  ),
];

List<WidgetbookNode> serverCareUpdateLogsNodes() => [
  WidgetbookComponent(
    name: 'UpdateStepList',
    useCases: [
      WidgetbookUseCase(
        name: 'Starting',
        builder: (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.running),
              UpdateStep.installing(UpdateStepState.pending),
              UpdateStep.restarting(UpdateStepState.pending),
              UpdateStep.checking(UpdateStepState.pending),
            ],
          ),
        ),
      ),
      ...onEachPlatform(
        'Installing',
        (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.done),
              UpdateStep.installing(UpdateStepState.running),
              UpdateStep.restarting(UpdateStepState.pending),
              UpdateStep.checking(UpdateStepState.pending),
            ],
            detailLines: _installLog,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Details open',
        builder: (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.done),
              UpdateStep.installing(UpdateStepState.running),
              UpdateStep.restarting(UpdateStepState.pending),
              UpdateStep.checking(UpdateStepState.pending),
            ],
            detailLines: _installLog,
            detailsInitiallyOpen: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Restarting',
        builder: (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.done),
              UpdateStep.installing(UpdateStepState.done),
              UpdateStep.restarting(UpdateStepState.running),
              UpdateStep.checking(UpdateStepState.pending),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Failed',
        builder: (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.done),
              UpdateStep.installing(UpdateStepState.failed),
              UpdateStep.restarting(UpdateStepState.pending),
              UpdateStep.checking(UpdateStepState.pending),
            ],
            detailLines: _installLog,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'All done',
        builder: (_) => frame(
          const UpdateStepList(
            steps: [
              UpdateStep.starting(UpdateStepState.done),
              UpdateStep.installing(UpdateStepState.done),
              UpdateStep.restarting(UpdateStepState.done),
              UpdateStep.checking(UpdateStepState.done),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(
            const UpdateStepList(
              steps: [
                UpdateStep.starting(UpdateStepState.done),
                UpdateStep.installing(UpdateStepState.done),
                UpdateStep.restarting(UpdateStepState.running),
                UpdateStep.checking(UpdateStepState.pending),
              ],
              detailLines: _installLog,
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'UpdateStatusCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Up to date',
        builder: (_) => frame(
          UpdateStatusCard(
            status: const UpdateUpToDate(
              version: '0.22.2',
              checkedAgo: 'just now',
            ),
            onCheckNow: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Checking',
        builder: (_) => frame(const UpdateStatusCard(status: UpdateChecking())),
      ),
      WidgetbookUseCase(
        name: "Couldn't check",
        builder: (_) => frame(
          UpdateStatusCard(
            status: const UpdateCheckFailed(
              message: "Couldn't reach the update source — try again later.",
            ),
            onCheckNow: () {},
          ),
        ),
      ),
      ...onEachPlatform(
        'Available',
        (_) => frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UpdateStatusCard(
                status: const UpdateAvailable(
                  changeCount: 12,
                  currentVersion: '0.22.2',
                ),
                onUpdate: () {},
              ),
              const UpdateChangeList(changes: _changes),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Rollback',
        builder: (_) => frame(
          UpdateStatusCard(
            status: const UpdateRollback(stableVersion: '0.22.0'),
            onUpdate: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Cannot apply, with command',
        builder: (_) => frame(
          const UpdateStatusCard(
            status: UpdateCannotApply(
              message:
                  'Hermes was installed with pip. Update it on the server '
                  'with the command below.',
              command: 'pip install --upgrade hermes-agent',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Cannot apply, without command',
        builder: (_) => frame(
          const UpdateStatusCard(
            status: UpdateCannotApply(
              message:
                  'This server is managed by your host. It updates Hermes '
                  'for you.',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(
            UpdateStatusCard(
              status: const UpdateRollback(
                stableVersion: '0.22.0',
                changeCount: 12,
                currentVersion: '0.22.2',
              ),
              onUpdate: () {},
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'UpdateOutcomeCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Success',
        builder: (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.success,
            version: '0.23.0',
            onDone: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Partial',
        builder: (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.partial,
            items: const [
              'The Telegram channel needs to be paired again.',
              'One skill could not be updated.',
            ],
            onDone: () {},
          ),
        ),
      ),
      ...onEachPlatform(
        'Failed',
        (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.failed,
            version: '0.22.2',
            detailLines: _installLog,
            onDone: () {},
            onTryAgain: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: "Can't confirm",
        builder: (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.unconfirmed,
            version: '0.23.0',
            onDone: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Old server still running',
        builder: (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.oldServerRunning,
            runningVersion: '0.22.2',
            installedVersion: '0.23.0',
            onCheckAgain: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Not back',
        builder: (_) => frame(
          UpdateOutcomeCard(
            kind: UpdateOutcomeKind.notBack,
            onKeepWaiting: () {},
            onDismiss: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(
            UpdateOutcomeCard(
              kind: UpdateOutcomeKind.oldServerRunning,
              runningVersion: '0.22.2',
              installedVersion: '0.23.0',
              onCheckAgain: () {},
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'CommandRow',
    useCases: [
      WidgetbookUseCase(
        name: 'Cannot apply section',
        builder: (_) => frame(
          const UpdateStatusCard(
            status: UpdateCannotApply(
              message: 'Update Hermes on the server with this command.',
              command: 'hermes update --yes',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Things to fix item',
        builder: (_) => frame(
          const GroupedSection(
            header: 'Things to fix',
            children: [
              GroupedRow(
                title: '1. Install the missing browser',
                titleMaxLines: null,
                subtitle: 'Run this on the server, then check again.',
                subtitleMaxLines: null,
              ),
              _CommandBox(command: 'hermes tools install browser'),
            ],
          ),
        ),
      ),
      ...onEachPlatform(
        'Long command',
        (_) => frame(
          const CommandRow(
            command:
                'curl -fsSL https://example.invalid/install.sh | '
                'bash -s -- --upgrade --channel stable',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(const CommandRow(command: 'hermes update --yes')),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'LogLevelChip',
    useCases: [
      WidgetbookUseCase(
        name: 'Every level',
        builder: (_) => frame(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in LogLevel.values) LogLevelChip(level: level),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in LogLevel.values) LogLevelChip(level: level),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'LogLineTile',
    useCases: [
      ...onEachPlatform(
        'Every level',
        (_) => frame(Column(children: _everyLevel())),
      ),
      WidgetbookUseCase(
        name: 'Traceback',
        builder: (_) => frame(
          const LogLineTile(
            time: '09:11:58',
            level: LogLevel.error,
            source: 'gateway.run',
            message: 'Unhandled error in the Telegram poller',
            continuation: _traceback,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Short traceback',
        builder: (_) => frame(
          const LogLineTile(
            time: '09:11:58',
            level: LogLevel.error,
            source: 'gateway.run',
            message: 'Unhandled error in the Telegram poller',
            continuation: [
              'Traceback (most recent call last):',
              '  File "gateway/run.py", line 212, in run',
              'ConnectionError: https://example.invalid/bot/getUpdates',
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Line without a header',
        builder: (_) => frame(
          const LogLineTile(message: '  ... 3 more frames omitted by Hermes'),
        ),
      ),
      WidgetbookUseCase(
        name: 'Day headers',
        builder: (_) => fill(
          CustomScrollView(
            slivers: [
              LogDaySection(
                label: 'Today',
                itemCount: 6,
                itemBuilder: (_, i) => LogLineTile(
                  time: '09:1$i:03',
                  level: i.isEven ? LogLevel.error : LogLevel.warning,
                  source: 'gateway.run',
                  message: 'Entry number ${6 - i} of today',
                ),
              ),
              LogDaySection(
                label: 'Yesterday',
                itemCount: 6,
                itemBuilder: (_, i) => LogLineTile(
                  time: '21:0$i:41',
                  level: LogLevel.info,
                  source: 'agent.run',
                  message: 'Entry number ${6 - i} of yesterday',
                ),
              ),
              LogDaySection(
                label: '12 Nov',
                itemCount: 4,
                itemBuilder: (_, i) => LogLineTile(
                  time: '07:3$i:12',
                  level: LogLevel.debug,
                  source: 'agent.context',
                  message: 'Entry number ${4 - i} of 12 Nov',
                ),
              ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) => _largest(
          context,
          frame(
            const LogLineTile(
              time: '09:11:58',
              level: LogLevel.warning,
              source: 'gateway.telegram',
              message: 'Polling is slow: the last request took 14 s',
              continuation: _traceback,
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'LogLevelMenuButton',
    useCases: [
      ...onEachPlatform(
        'All levels',
        (_) => frame(const _LevelDemo(LogLevelFilter.all)),
      ),
      WidgetbookUseCase(
        name: 'Warnings and errors',
        builder: (_) => frame(const _LevelDemo(LogLevelFilter.warnings)),
      ),
      WidgetbookUseCase(
        name: 'Errors only',
        builder: (_) => frame(const _LevelDemo(LogLevelFilter.errors)),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (context) =>
            _largest(context, frame(const _LevelDemo(LogLevelFilter.warnings))),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'Logs page states',
    useCases: [
      WidgetbookUseCase(
        name: 'Nothing logged yet',
        builder: (_) => fill(
          const StateMessage(
            icon: AppIcons.transcript,
            title: 'Nothing logged yet',
            detail: "Hermes hasn't written to this log.",
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'No lines match',
        builder: (_) => fill(
          StateMessage(
            icon: AppIcons.search,
            title: 'No lines match',
            detail: 'Try another level or search.',
            action: OutlinedButton(
              onPressed: () {},
              child: const Text('Clear filters'),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: "Can't reach Hermes",
        builder: (_) => fill(
          StateMessage(
            icon: AppIcons.warning,
            title: "Can't reach Hermes",
            action: FilledButton(
              onPressed: () {},
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Refused',
        builder: (_) => fill(
          const StateMessage(
            icon: AppIcons.error,
            title: 'Logs are not available',
            detail: 'Log access is turned off for this profile.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Loading',
        builder: (_) => fill(
          const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingSkeleton(label: 'Loading logs'),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'No lines match, largest text',
        builder: (context) => _largest(
          context,
          fill(
            StateMessage(
              icon: AppIcons.search,
              title: 'No lines match',
              detail: 'Try another level or search.',
              action: OutlinedButton(
                onPressed: () {},
                child: const Text('Clear filters'),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'LoadingSkeleton',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (_) => frame(const LoadingSkeleton(label: 'Loading logs')),
      ),
      WidgetbookUseCase(
        name: 'Reduce Motion',
        builder: (context) => _reduceMotion(
          context,
          frame(const LoadingSkeleton(label: 'Loading logs', lines: 5)),
        ),
      ),
    ],
  ),
];

/// Holds the chosen level, as the page would.
class _LevelDemo extends StatefulWidget {
  const _LevelDemo(this.initial);

  final LogLevelFilter initial;

  @override
  State<_LevelDemo> createState() => _LevelDemoState();
}

class _LevelDemoState extends State<_LevelDemo> {
  late var _value = widget.initial;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: LogLevelMenuButton(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
    ),
  );
}

/// A command under a row of a section, as the Server check page places one.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: GroupedMetrics.of(context).rowPadding,
      vertical: 8,
    ),
    child: CommandRow(command: command),
  );
}
