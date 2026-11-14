import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/server_care/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/server_care/widgets/usage_day_list.dart';
import 'package:hermes_app/src/server_care/widgets/usage_model_list.dart';
import 'package:hermes_app/src/server_care/widgets/usage_totals_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Thirty days ending 12 Nov 2026: 8.4M tokens, 112 conversations, the highest
// day (5 Nov) at 1.2M and the newest at 812K with 9 conversations.
const _thirtyDayThousands = [
  160, 190, 0, 0, 250, 328, 280, 210, 240, 0, //
  110, 270, 310, 290, 230, 180, 0, 130, 240, 300, //
  280, 380, 1200, 470, 330, 280, 0, 410, 520, 812,
];
const _thirtyDayConversations = [
  2, 2, 0, 0, 3, 6, 3, 2, 3, 0, //
  1, 3, 3, 3, 3, 2, 0, 1, 3, 3, //
  3, 5, 18, 8, 6, 3, 0, 8, 9, 9,
];

/// Dollars per token that make 812K tokens cost $1.20.
const _dollarsPerToken = 1.2 / 812000;

/// The thousands of tokens and the conversations of the day [back] days
/// before 12 Nov; older than thirty days is a repeating pattern.
(int, int) _tokensAndConversations(int back) {
  if (back < 30) {
    final i = 29 - back;
    return (_thirtyDayThousands[i] * 1000, _thirtyDayConversations[i]);
  }
  if (back % 13 == 5) return (0, 0);
  final thousands = ((back * 37 + 11) % 17) * 45 + 40;
  return (thousands * 1000, 1 + thousands ~/ 120);
}

DateTime _dayBack(int back) => DateTime(2026, 11, 12 - back);

List<UsageChartDay> _chartDays(UsageChartMetric metric, {int count = 30}) => [
  for (var i = 0; i < count; i++)
    () {
      final back = count - 1 - i;
      final (tokens, conversations) = _tokensAndConversations(back);
      return UsageChartDay(
        day: _dayBack(back),
        value: metric == UsageChartMetric.tokens
            ? tokens.toDouble()
            : tokens * _dollarsPerToken,
        conversations: conversations,
      );
    }(),
];

List<UsageChartDay> _oneTallDay(UsageChartMetric metric) => [
  for (var i = 0; i < 30; i++)
    UsageChartDay(
      day: _dayBack(29 - i),
      value: i == 14 ? (metric == UsageChartMetric.tokens ? 2400000 : 3.55) : 0,
      conversations: i == 14 ? 31 : 0,
    ),
];

List<UsageChartDay> _noUsage() => [
  for (var i = 0; i < 30; i++) UsageChartDay(day: _dayBack(29 - i), value: 0),
];

List<UsageDayEntry> _dayEntries(int count) => [
  for (var back = 0; back < count; back++)
    () {
      final (tokens, conversations) = _tokensAndConversations(back);
      return UsageDayEntry(
        day: _dayBack(back),
        tokens: tokens,
        cost: tokens * _dollarsPerToken,
        conversations: conversations,
      );
    }(),
];

const _models = [
  UsageModelEntry(
    model: 'acme-large-2',
    tokens: 7700000,
    cost: 10.8,
    conversations: 98,
    share: 7.7 / 8.4,
  ),
  UsageModelEntry(
    model: 'local/open-weights-7b-instruct-q4-with-a-long-identifier-2026-11',
    tokens: 500000,
    cost: 1.3,
    conversations: 11,
    share: 0.5 / 8.4,
  ),
  UsageModelEntry(
    model: 'acme-mini-1',
    tokens: 200000,
    cost: 0.3,
    conversations: 3,
    share: 0.2 / 8.4,
  ),
];

Widget _largest(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: child,
  ),
);

Widget _reduceMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

Widget _chart(
  List<UsageChartDay> days, {
  UsageChartMetric metric = UsageChartMetric.tokens,
  UsageChartWindow window = UsageChartWindow.days30,
  int? selected,
}) => frame(
  UsageChart(
    days: days,
    metric: metric,
    window: window,
    initialSelectedIndex: selected,
  ),
);

UsageTotalsCard _totals({
  UsageChartMetric metric = UsageChartMetric.tokens,
  double? billed,
}) => UsageTotalsCard(
  metric: metric,
  window: UsageChartWindow.days30,
  tokens: 8400000,
  estimatedCost: 12.4,
  conversations: 112,
  inputTokens: 7880000,
  outputTokens: 520000,
  cacheReadTokens: 3100000,
  billedCost: billed,
);

/// The page as it reads once loaded, with the table switch working. The page
/// itself is wired in a later change; this is its parts in order.
class _LoadedPage extends StatefulWidget {
  const _LoadedPage({
    this.metric = UsageChartMetric.tokens,
    this.table = false,
  });

  final UsageChartMetric metric;
  final bool table;

  @override
  State<_LoadedPage> createState() => _LoadedPageState();
}

class _LoadedPageState extends State<_LoadedPage> {
  late bool _table = widget.table;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _totals(
        metric: widget.metric,
        billed: widget.metric == UsageChartMetric.cost ? 10.02 : null,
      ),
      const SizedBox(height: 16),
      if (_table)
        UsageDayList(days: _dayEntries(30))
      else
        UsageChart(
          days: _chartDays(widget.metric),
          metric: widget.metric,
          window: UsageChartWindow.days30,
        ),
      GroupedSection(
        children: [
          GroupedSwitchRow(
            title: 'Show as table',
            value: _table,
            onChanged: (v) => setState(() => _table = v),
          ),
        ],
      ),
      UsageModelList(models: _models, footer: kUsageFooter),
    ],
  );
}

Widget _loaded({
  UsageChartMetric metric = UsageChartMetric.tokens,
  bool table = false,
}) => frame(_LoadedPage(metric: metric, table: table), maxWidth: 640);

const _chartIcon = AppIconSet(Icons.bar_chart, CupertinoIcons.chart_bar);

List<WidgetbookNode> serverCareUsageNodes() => [
  WidgetbookComponent(
    name: 'UsageChart',
    useCases: [
      WidgetbookUseCase(
        name: '30 days, tokens',
        builder: (_) => _chart(_chartDays(UsageChartMetric.tokens)),
      ),
      WidgetbookUseCase(
        name: '30 days, cost',
        builder: (_) => _chart(
          _chartDays(UsageChartMetric.cost),
          metric: UsageChartMetric.cost,
        ),
      ),
      WidgetbookUseCase(
        name: '7 days, tokens',
        builder: (_) => _chart(
          _chartDays(UsageChartMetric.tokens, count: 7),
          window: UsageChartWindow.days7,
        ),
      ),
      WidgetbookUseCase(
        name: '90 days, tokens (scrolls)',
        builder: (_) => _chart(
          _chartDays(UsageChartMetric.tokens, count: 90),
          window: UsageChartWindow.days90,
        ),
      ),
      WidgetbookUseCase(
        name: '90 days, cost (scrolls)',
        builder: (_) => _chart(
          _chartDays(UsageChartMetric.cost, count: 90),
          metric: UsageChartMetric.cost,
          window: UsageChartWindow.days90,
        ),
      ),
      WidgetbookUseCase(
        name: 'Empty, no usage',
        builder: (_) => _chart(_noUsage()),
      ),
      WidgetbookUseCase(
        name: 'One tall day',
        builder: (_) => _chart(_oneTallDay(UsageChartMetric.tokens)),
      ),
      WidgetbookUseCase(
        name: 'Selected bar',
        builder: (_) =>
            _chart(_chartDays(UsageChartMetric.tokens), selected: 22),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (_) => _largest(
          _chart(
            _chartDays(UsageChartMetric.cost),
            metric: UsageChartMetric.cost,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Reduce Motion',
        builder: (_) =>
            _reduceMotion(_chart(_chartDays(UsageChartMetric.tokens))),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'UsageTotalsCard',
    useCases: [
      ...onEachPlatform('Tokens', (_) => frame(_totals())),
      WidgetbookUseCase(
        name: 'Estimated cost, billed',
        builder: (_) =>
            frame(_totals(metric: UsageChartMetric.cost, billed: 10.02)),
      ),
      WidgetbookUseCase(
        name: 'Estimated cost, no billed amount',
        builder: (_) => frame(_totals(metric: UsageChartMetric.cost)),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (_) => _largest(
          frame(_totals(metric: UsageChartMetric.cost, billed: 10.02)),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'UsageDayList',
    useCases: [
      ...onEachPlatform(
        'First 10 days',
        (_) => frame(UsageDayList(days: _dayEntries(30))),
      ),
      WidgetbookUseCase(
        name: 'Seven days (nothing more to show)',
        builder: (_) => frame(UsageDayList(days: _dayEntries(7))),
      ),
      WidgetbookUseCase(
        name: '90 days',
        builder: (_) => frame(UsageDayList(days: _dayEntries(90))),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (_) => _largest(frame(UsageDayList(days: _dayEntries(12)))),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'UsageModelList',
    useCases: [
      ...onEachPlatform(
        'Three models',
        (_) => frame(UsageModelList(models: _models, footer: kUsageFooter)),
      ),
      WidgetbookUseCase(
        name: 'Largest text',
        builder: (_) => _largest(
          frame(UsageModelList(models: _models, footer: kUsageFooter)),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'Usage page',
    useCases: [
      ...onEachPlatform('Loaded, tokens', (_) => _loaded()),
      WidgetbookUseCase(
        name: 'Loaded, cost',
        builder: (_) => _loaded(metric: UsageChartMetric.cost),
      ),
      WidgetbookUseCase(
        name: 'Loaded, as table',
        builder: (_) => _loaded(table: true),
      ),
      WidgetbookUseCase(
        name: 'Loaded, largest text',
        builder: (_) => _largest(_loaded()),
      ),
      WidgetbookUseCase(
        name: 'Loading',
        builder: (_) => frame(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoadingSkeleton(label: 'Loading usage'),
              SizedBox(height: 16),
              UsageChartSkeleton(),
            ],
          ),
          maxWidth: 640,
        ),
      ),
      WidgetbookUseCase(
        name: 'Loading, Reduce Motion',
        builder: (_) => _reduceMotion(
          frame(
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoadingSkeleton(label: 'Loading usage'),
                SizedBox(height: 16),
                UsageChartSkeleton(),
              ],
            ),
            maxWidth: 640,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Empty',
        builder: (_) => fill(
          const StateMessage(
            icon: _chartIcon,
            title: 'No usage in the last 30 days',
            detail: 'Usage appears here after Hermes answers a chat, a message or a scheduled task.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Store unreadable',
        builder: (_) => fill(
          StateMessage(
            icon: AppIcons.error,
            title: "Usage can't be read",
            detail: "The server's session store needs repair.",
            action: FilledButton(
              onPressed: () =>
                  Future<void>.delayed(const Duration(milliseconds: 300)),
              child: const Text('Run a check'),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Offline',
        builder: (_) => fill(
          StateMessage(
            icon: AppIcons.warning,
            title: "Can't reach Hermes",
            detail: "Check that the server is on and that you're connected to its network.",
            action: FilledButton(
              onPressed: () =>
                  Future<void>.delayed(const Duration(milliseconds: 300)),
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Offline, largest text',
        builder: (_) => _largest(
          fill(
            StateMessage(
              icon: AppIcons.warning,
              title: "Can't reach Hermes",
              detail: "Check that the server is on and that you're connected to its network.",
              action: FilledButton(
                onPressed: () {},
                child: const Text('Try again'),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
];
