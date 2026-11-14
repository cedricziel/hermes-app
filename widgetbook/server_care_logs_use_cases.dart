import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/server_logs_body.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

final _now = DateTime(2026, 11, 14, 10);

Widget _largest(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child,
);

const _traceback = [
  'Traceback (most recent call last):',
  '  File "gateway/run.py", line 212, in run',
  '    await self._poll()',
  '  File "gateway/telegram.py", line 88, in _poll',
  '    updates = await self._client.get_updates()',
  '  File "gateway/http.py", line 41, in get_updates',
  '    raise ConnectionError(self._url)',
  '  File "aiohttp/client.py", line 560, in _request',
  '    await resp.start(conn)',
  'ConnectionError: https://example.invalid/bot/getUpdates',
];

/// Newest first, across today, yesterday and an older day, with every level
/// and a traceback.
List<LogLine> _lines() => const [
  LogLine(
    raw: '',
    time: '2026-11-14 09:12:08,114',
    level: LogLevel.debug,
    source: 'agent.context',
    message: 'Loaded 14 skills in 62 ms',
  ),
  LogLine(
    raw: '',
    time: '2026-11-14 09:12:05,002',
    level: LogLevel.info,
    source: 'gateway.run',
    message: 'Connected to 2 messaging channels',
  ),
  LogLine(
    raw: '',
    time: '2026-11-14 09:12:03,411',
    level: LogLevel.warning,
    source: 'gateway.telegram',
    message: 'Polling is slow: the last request took 14 s',
  ),
  LogLine(
    raw: '',
    time: '2026-11-14 09:11:58,090',
    level: LogLevel.error,
    source: 'gateway.discord',
    message: 'Could not send a reply: the channel no longer exists',
    continuation: _traceback,
  ),
  LogLine(
    raw: '',
    time: '2026-11-13 21:40:12,731',
    level: LogLevel.critical,
    source: 'sessions.store',
    message: 'The session store could not be opened',
  ),
  LogLine(
    raw: '',
    time: '2026-11-13 21:03:44,205',
    level: LogLevel.info,
    source: 'agent.run',
    message: 'Scheduled task finished',
  ),
  LogLine(
    raw: '',
    time: '2026-11-12 07:30:01,500',
    level: LogLevel.warning,
    source: 'agent.loop',
    message: 'Retrying after a timeout',
  ),
  LogLine(raw: '  ... 3 more frames omitted by Hermes'),
];

/// The page as the person sees it: the bar with its tabs and search under
/// the title, and [body] below.
Widget _page(Widget Function(BuildContext context) body, {String query = ''}) =>
    Builder(
      builder: (context) {
        final l10n = context.l10n;
        return DefaultTabController(
          length: 3,
          child: pushed(
            SettingsScaffold(
              title: l10n.serverCareLogsTitle,
              subtitle: l10n.serverCareLogsSubtitle('default'),
              previousTitle: l10n.serverCareTitle,
              tabs: [
                l10n.serverCareLogsFileErrors,
                l10n.serverCareLogsFileAgent,
                l10n.serverCareLogsFileGateway,
              ],
              search: SettingsSearch(
                query: query,
                onChanged: (_) {},
                hint: l10n.serverCareLogsSearchHint,
              ),
              body: body(context),
            ),
          ),
        );
      },
    );

ServerLogsBody _body(
  ServerLogsStatus status, {
  List<LogLine> entries = const [],
  LogLevelFilter level = LogLevelFilter.all,
  bool canShowOlder = false,
  int? lastLinesCount,
  String? refusedMessage,
}) => ServerLogsBody(
  status: status,
  entries: entries,
  level: level,
  onLevel: (_) {},
  canShowOlder: canShowOlder,
  lastLinesCount: lastLinesCount,
  refusedMessage: refusedMessage,
  onShowOlder: () {},
  onClearFilters: () {},
  onRetry: () {},
  now: _now,
);

List<WidgetbookNode> serverCareLogsNodes() => [
  WidgetbookComponent(
    name: 'Logs page',
    useCases: [
      ...onEachPlatform(
        'Lines',
        (_) => _page(
          (_) => _body(
            ServerLogsStatus.ready,
            entries: _lines(),
            canShowOlder: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Lines, errors only, with a search',
        builder: (_) => _page(
          (_) => _body(
            ServerLogsStatus.ready,
            entries: _lines().sublist(3, 5),
            level: LogLevelFilter.errors,
          ),
          query: 'discord',
        ),
      ),
      WidgetbookUseCase(
        name: 'Last 500 lines',
        builder: (_) => _page(
          (_) => _body(
            ServerLogsStatus.ready,
            entries: _lines(),
            lastLinesCount: 500,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Loading',
        builder: (_) => _page((_) => _body(ServerLogsStatus.loading)),
      ),
      WidgetbookUseCase(
        name: 'Empty',
        builder: (_) => _page((_) => _body(ServerLogsStatus.empty)),
      ),
      WidgetbookUseCase(
        name: 'No match',
        builder: (_) => _page(
          (_) => _body(ServerLogsStatus.noMatch, level: LogLevelFilter.errors),
          query: 'timeout',
        ),
      ),
      ...onEachPlatform(
        "Can't reach Hermes",
        (_) => _page((_) => _body(ServerLogsStatus.offline)),
      ),
      WidgetbookUseCase(
        name: 'Refused',
        builder: (_) => _page(
          (_) => _body(
            ServerLogsStatus.refused,
            refusedMessage: 'The log file cannot be read by the dashboard.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Failed',
        builder: (_) => _page((_) => _body(ServerLogsStatus.failed)),
      ),
      WidgetbookUseCase(
        name: 'Lines, largest text',
        builder: (_) => _page(
          (context) => _largest(
            context,
            _body(
              ServerLogsStatus.ready,
              entries: _lines(),
              canShowOlder: true,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'No match, largest text',
        builder: (_) => _page(
          (context) => _largest(
            context,
            _body(ServerLogsStatus.noMatch, level: LogLevelFilter.warnings),
          ),
          query: 'timeout',
        ),
      ),
    ],
  ),
];
