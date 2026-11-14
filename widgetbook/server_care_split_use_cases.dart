import 'package:flutter/material.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/care_row_value.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/server_check_body.dart';
import 'package:hermes_app/src/server_care/widgets/server_check_row.dart';
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

import 'frame.dart';

/// The pages a wide Server screen can show beside its list.
enum _Pick { usage, update, logs, check }

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2)),
    child: child,
  ),
);

/// The overview as the screen builds it: a headline, then rows, with [picked]
/// highlighted and [onPick] called by the rows that open a page.
Widget _overview(
  _Pick? picked,
  ValueChanged<_Pick> onPick, {
  required bool split,
  required bool german,
}) {
  String t(String en, String de) => german ? de : en;
  // No chevron beside a page: the fill and the selected state say it.
  final bool? chevron = split ? false : null;
  return SettingsScaffold(
    title: t('Server', 'Server'),
    subtitle: t('default · 2 profiles', 'default · 2 Profile'),
    body: GroupedListView(
      children: [
        ServerStatusCard(
          tone: ServerStatusTone.healthy,
          title: t('Everything looks good', 'Alles in Ordnung'),
          detail: 'Hermes 0.22.2',
        ),
        GroupedSection(
          header: 'Hermes',
          children: [
            CareValueRow(
              title: 'Version',
              value: '0.22.2',
              subtitle: t(
                'Released 2 Nov 2026',
                'Veröffentlicht am 2. Nov. 2026',
              ),
            ),
            CareValueRow(
              title: 'Updates',
              value: t('Up to date', 'Auf dem neuesten Stand'),
              selected: picked == _Pick.update,
              chevron: chevron,
              onTap: () => onPick(_Pick.update),
            ),
          ],
        ),
        GroupedSection(
          header: t('Tools', 'Werkzeuge'),
          children: [
            GroupedRow(
              title: t('Usage', 'Nutzung'),
              subtitle: t(
                'Tokens, cost and conversations',
                'Tokens, Kosten und Unterhaltungen nach Tag und Modell',
              ),
              selected: picked == _Pick.usage,
              chevron: chevron,
              onTap: () => onPick(_Pick.usage),
            ),
            GroupedRow(
              title: t('Logs', 'Protokolle'),
              subtitle: t(
                "Recent lines from Hermes' logs",
                'Aktuelle Zeilen aus den Protokollen von Hermes',
              ),
              selected: picked == _Pick.logs,
              chevron: chevron,
              onTap: () => onPick(_Pick.logs),
            ),
            ServerCheckRow(
              state: ServerCheckRowState.idle,
              selected: picked == _Pick.check,
              chevron: chevron,
              onTap: () => onPick(_Pick.check),
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedRow(
              title: t('Connection details', 'Verbindungsdetails'),
              onTap: () {},
            ),
          ],
        ),
      ],
    ),
  );
}

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
  _Pick.check => SettingsScaffold(
    title: 'Server check',
    subtitle: 'default',
    body: ServerCheckBody(
      view: const ServerCheckView.intro(),
      onRun: () {},
      onKeepWaiting: () {},
      onDismiss: () {},
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
  const _Demo({this.initial, this.empty = false, this.german = false});

  final _Pick? initial;

  /// The overview in German, whose words are longer.
  final bool german;

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
      final list = _overview(
        wide ? shown : null,
        (p) {
          if (wide) setState(() => _picked = p);
        },
        split: wide,
        german: widget.german,
      );
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
        name: 'Server check selected',
        builder: (_) => const _Demo(initial: _Pick.check),
      ),
      WidgetbookUseCase(
        name: 'German, long strings, Logs selected',
        builder: (_) => const _Demo(initial: _Pick.logs, german: true),
      ),
      WidgetbookUseCase(
        name: 'German, long strings, largest text',
        builder: (_) => _largest(const _Demo(german: true)),
      ),
      WidgetbookUseCase(
        name: 'Narrow: the list alone, rows push their page',
        builder: (_) => fill(const _Demo(), width: 390),
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
