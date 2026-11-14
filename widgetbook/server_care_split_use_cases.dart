import 'package:flutter/material.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/care_row_value.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/server_logs_body.dart';
import 'package:hermes_app/src/server_care/widgets/server_split_view.dart';
import 'package:hermes_app/src/server_care/widgets/server_status_card.dart';
import 'package:hermes_app/src/server_care/widgets/update_status_card.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/server_care/widgets/usage_totals_card.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:widgetbook/widgetbook.dart';

/// The pages a wide Server screen can show beside its list.
enum _Pick { usage, update, logs }

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

/// The overview as the screen builds it: a headline, then rows, with [picked]
/// highlighted and [onPick] called by the rows that open a page.
Widget _overview(_Pick? picked, ValueChanged<_Pick> onPick) => SettingsScaffold(
  title: 'Server',
  subtitle: 'default · 2 profiles',
  body: GroupedListView(
    children: [
      const ServerStatusCard(
        tone: ServerStatusTone.healthy,
        title: 'Everything looks good',
        detail: 'Hermes 0.22.2',
      ),
      GroupedSection(
        header: 'Hermes',
        children: [
          const CareValueRow(
            title: 'Version',
            value: '0.22.2',
            subtitle: 'Released 2 Nov 2026',
          ),
          CareValueRow(
            title: 'Updates',
            value: 'Up to date',
            selected: picked == _Pick.update,
            onTap: () => onPick(_Pick.update),
          ),
        ],
      ),
      GroupedSection(
        header: 'Tools',
        children: [
          GroupedRow(
            title: 'Usage',
            subtitle: 'Tokens, cost and conversations',
            selected: picked == _Pick.usage,
            onTap: () => onPick(_Pick.usage),
          ),
          GroupedRow(
            title: 'Logs',
            subtitle: "Recent lines from Hermes' logs",
            selected: picked == _Pick.logs,
            onTap: () => onPick(_Pick.logs),
          ),
        ],
      ),
      GroupedSection(
        children: [GroupedRow(title: 'Connection details', onTap: () {})],
      ),
    ],
  ),
);

const _lines = [
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
  ),
];

/// The pages with the same bars the real ones have; their bodies are the
/// plain widgets they are made of.
Widget _page(_Pick pick) => switch (pick) {
  _Pick.usage => SettingsScaffold(
    title: 'Usage',
    subtitle: 'default',
    body: GroupedListView(
      children: const [
        SizedBox(height: 12),
        UsageTotalsCard(
          metric: UsageChartMetric.tokens,
          window: UsageChartWindow.days30,
          tokens: 8400000,
          estimatedCost: 12.4,
          conversations: 112,
          inputTokens: 7880000,
          outputTokens: 520000,
          cacheReadTokens: 3100000,
        ),
      ],
    ),
  ),
  _Pick.update => SettingsScaffold(
    title: 'Update',
    body: GroupedListView(
      children: [
        UpdateStatusCard(
          status: const UpdateUpToDate(
            version: '0.22.2',
            checkedAgo: 'just now',
          ),
          onCheckNow: () {},
        ),
      ],
    ),
  ),
  _Pick.logs => DefaultTabController(
    length: 3,
    child: SettingsScaffold(
      title: 'Logs',
      subtitle: 'default · newest first',
      tabs: const ['Errors', 'Agent', 'Gateway'],
      body: ServerLogsBody(
        status: ServerLogsStatus.ready,
        entries: _lines,
        level: LogLevelFilter.all,
        onLevel: (_) {},
        canShowOlder: false,
        onShowOlder: () {},
        onClearFilters: () {},
        onRetry: () {},
        now: DateTime(2026, 11, 14, 10),
      ),
    ),
  ),
};

/// What the Server screen does with the width: beside each other from the
/// wide breakpoint, else the list alone (a row then pushes its page).
class _Demo extends StatefulWidget {
  const _Demo({this.initial, this.empty = false});

  final _Pick? initial;

  /// The server offers no page.
  final bool empty;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  _Pick? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = isWideLayout(context, width: box.maxWidth);
      final shown = widget.empty ? null : _picked ?? _Pick.usage;
      final list = _overview(wide ? shown : null, (p) {
        if (wide) setState(() => _picked = p);
      });
      if (!wide) return list;
      return ServerSplitView(
        list: list,
        detail: shown == null
            ? null
            : KeyedSubtree(key: ValueKey(shown), child: _page(shown)),
        onClose: () => setState(() => _picked = null),
      );
    },
  );
}

List<WidgetbookNode> serverCareSplitNodes() => [
  WidgetbookComponent(
    name: 'ServerSplitView',
    useCases: [
      WidgetbookUseCase(
        name: 'Nothing selected (Usage)',
        builder: (_) => const _Demo(),
      ),
      WidgetbookUseCase(
        name: 'Update selected',
        builder: (_) => const _Demo(initial: _Pick.update),
      ),
      WidgetbookUseCase(
        name: 'Logs selected',
        builder: (_) => const _Demo(initial: _Pick.logs),
      ),
      WidgetbookUseCase(
        name: 'No page offered',
        builder: (_) => const _Demo(empty: true),
      ),
      WidgetbookUseCase(
        name: 'Logs selected, largest text',
        builder: (_) => _largest(const _Demo(initial: _Pick.logs)),
      ),
      WidgetbookUseCase(
        name: 'Usage, largest text',
        builder: (_) => _largest(const _Demo()),
      ),
      for (final (name, platform) in [
        ('iPhone', TargetPlatform.iOS),
        ('Mac', TargetPlatform.macOS),
        ('Material', TargetPlatform.android),
      ])
        WidgetbookUseCase(
          name: 'Update selected ($name)',
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: platform),
            child: const _Demo(initial: _Pick.update),
          ),
        ),
    ],
  ),
];
