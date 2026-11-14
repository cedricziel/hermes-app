import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'care_result.dart';
import 'server_care_controller.dart';
import 'usage_controller.dart';
import 'widgets/loading_skeleton.dart';
import 'widgets/usage_chart.dart';
import 'widgets/usage_controls.dart';
import 'widgets/usage_day_list.dart';
import 'widgets/usage_model_list.dart';
import 'widgets/usage_totals_card.dart';

/// "How much is Hermes using, and on what?": the window's totals, a bar per
/// day, and the models behind it.
class UsagePage extends StatefulWidget {
  const UsagePage({super.key, this.onRunCheck});

  /// Opens the server check. The store-unreadable state offers "Run a check"
  /// only when this is given.
  final VoidCallback? onRunCheck;

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  late final ServerCareController _care;
  late final UsageController _controller;
  String? _careProfile;
  bool _asTable = false;

  /// The server has no usage route: the row on the Server screen goes, and a
  /// page opened from it closes rather than explain a missing part.
  void _usageMissing() {
    _care.reportUnsupported(CarePart.usage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void initState() {
    super.initState();
    _care = context.read<ServerCareController>();
    _careProfile = _care.profile;
    _controller = UsageController(
      repository: HermesRepositories.of(context).serverCare,
      profile: _careProfile,
      onUnsupported: _usageMissing,
      lookupFailed: () => _care.profileLookupFailed,
    );
    _care.addListener(_followChatProfile);
    Breadcrumbs crumbs;
    try {
      crumbs = context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      crumbs = Breadcrumbs.none;
    }
    // Only the window: no profile, no figures.
    crumbs('server_care.usage.opened', {'days': _controller.window.days});
    _controller.load();
  }

  /// The chat switched profile while the page was open.
  void _followChatProfile() {
    if (_care.profile == _careProfile) {
      // Looking up the profile just failed: show it, with a retry.
      if (_care.profile == null && _care.profileLookupFailed) {
        _controller.load();
      }
      return;
    }
    _careProfile = _care.profile;
    _controller.setProfile(_careProfile);
  }

  @override
  void dispose() {
    _care.removeListener(_followChatProfile);
    _controller.dispose();
    super.dispose();
  }

  SettingsSubtitleMenu<String>? _profileMenu() {
    final profile = _controller.profile;
    final profiles = _care.status?.profiles ?? const <String>[];
    if (profile == null || profiles.length < 2) return null;
    return SettingsSubtitleMenu<String>(
      label: 'Profile',
      onSelected: _controller.setProfile,
      itemBuilder: (_) => [
        for (final p in profiles)
          CheckedPopupMenuItem(value: p, checked: p == profile, child: Text(p)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => SettingsScaffold(
      title: 'Usage',
      subtitle: _controller.profile,
      subtitleMenu: _profileMenu(),
      previousTitle: 'Server',
      actions: [
        SettingsBarAction(
          key: const Key('usage-refresh'),
          label: 'Refresh',
          icon: AppIcons.refresh,
          onPressed: _controller.loading ? null : _controller.load,
        ),
      ],
      body: _body(context),
    ),
  );

  Widget _body(BuildContext context) {
    final c = _controller;
    final report = c.report;
    if (report == null && !c.loading) {
      final state = _failureState(context);
      if (state != null) return state;
    }
    final list = GroupedListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        UsageControls(
          window: c.window,
          metric: c.metric,
          onWindow: c.setWindow,
          onMetric: c.setMetric,
        ),
        // A refresh that failed leaves the last answer up, and says so.
        if (report != null && c.failure != null)
          const GroupedSection(
            children: [
              GroupedRow(
                title: "Couldn't refresh usage",
                warning: 'Showing the last answer. Try again in a moment.',
                titleMaxLines: null,
              ),
            ],
          ),
        if (report == null)
          const _Skeleton()
        else if (report.isEmpty)
          SizedBox(
            height: 280,
            child: StateMessage(
              icon: AppIcons.info,
              title: 'No usage in the last ${c.window.days} days',
              detail:
                  'Usage appears here after Hermes answers a chat, a '
                  'message or a scheduled task.',
            ),
          )
        else ...[
          const SizedBox(height: 12),
          UsageTotalsCard(
            metric: c.metric,
            window: c.window,
            tokens: report.totals.tokens,
            estimatedCost: report.totals.estimatedCost,
            conversations: report.totals.sessions,
            inputTokens: report.totals.inputTokens,
            outputTokens: report.totals.outputTokens,
            cacheReadTokens: report.totals.cacheReadTokens,
            billedCost: report.totals.actualCost > 0
                ? report.totals.actualCost
                : null,
          ),
          if (_asTable)
            UsageDayList(key: ValueKey(c.revision), days: c.dayEntries)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: UsageChart(
                key: ValueKey((c.revision, c.window, c.metric)),
                days: c.chartDays,
                initialSelectedIndex: c.latestDataIndex,
                metric: c.metric,
                window: c.window,
              ),
            ),
          GroupedSection(
            children: [
              GroupedSwitchRow(
                title: 'Show as table',
                value: _asTable,
                onChanged: (v) => setState(() => _asTable = v),
              ),
            ],
          ),
          UsageModelList(models: c.modelEntries, footer: kUsageFooter),
        ],
      ],
    );
    // The Mac has the Refresh button; a pull is for touch.
    return platformChromeOf(context) == PlatformChrome.macos
        ? list
        : RefreshIndicator(onRefresh: c.load, child: list);
  }

  /// The whole-page states for a read that gave nothing to show.
  Widget? _failureState(BuildContext context) {
    final c = _controller;
    if (c.unsupported) {
      return const StateMessage(
        icon: AppIcons.info,
        title: "Usage isn't available",
        detail: "This Hermes server doesn't report usage.",
      );
    }
    final failure = c.failure;
    if (failure == null) return null;
    // Without a profile, trying again means looking the profile up again;
    // only a tap does that, never the page by itself.
    final retry = FilledButton(
      onPressed: c.profile == null ? _care.refresh : c.load,
      child: const Text('Try again'),
    );
    return switch (failure) {
      CareFailureKind.storeUnreadable => StateMessage(
        icon: AppIcons.error,
        title: "Usage can't be read",
        detail: "The server's session store needs repair.",
        action: widget.onRunCheck == null
            ? null
            : FilledButton(
                onPressed: widget.onRunCheck,
                child: const Text('Run a check'),
              ),
      ),
      CareFailureKind.offline => StateMessage(
        icon: AppIcons.error,
        title: "Can't reach Hermes",
        action: retry,
      ),
      CareFailureKind.refused => StateMessage(
        icon: AppIcons.error,
        title: "Usage can't be loaded",
        detail: c.failureMessage,
        action: retry,
      ),
      _ => StateMessage(
        icon: AppIcons.error,
        title: "Usage can't be loaded",
        detail: 'Hermes did not answer as expected.',
        action: retry,
      ),
    };
  }
}

/// The window and metric choices: stacked on a phone, side by side from a
/// desktop width.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      LoadingSkeleton(label: 'Loading usage', lines: 2),
      SizedBox(height: 16),
      UsageChartSkeleton(),
    ],
  );
}
