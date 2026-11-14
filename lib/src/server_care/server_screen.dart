import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_repositories.dart';
import '../settings/account_actions.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_action_row.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'attention.dart';
import 'care_result.dart';
import 'connection_bound.dart';
import 'gateway_actions.dart';
import 'gateway_restart.dart';
import 'hermes_update_run.dart';
import 'replies_in_progress.dart';
import 'server_care_repository.dart';
import 'server_care_controller.dart';
import 'server_logs_page.dart';
import 'server_status.dart';
import 'update_check_controller.dart';
import 'update_page.dart';
import 'usage_page.dart';
import 'widgets/care_row_value.dart';
import 'widgets/server_split_view.dart';
import 'widgets/server_status_card.dart';

/// Pushes the Server screen as a settings page. [source] says where the
/// person came from (a fixed name such as `menu`), for the breadcrumb.
Future<void> showServerScreen(BuildContext context, {required String source}) {
  // The pushed route sits above the shell's provider, so it is passed on.
  final care = context.read<ServerCareController>();
  final run = context.read<GatewayRestart>();
  final update = context.read<HermesUpdateRun>();
  final replies = maybeRepliesInProgress(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _carry(care, run, update, replies, ServerScreen(source: source)),
    ),
  );
}

Widget _carry(
  ServerCareController care,
  GatewayRestart run,
  HermesUpdateRun update,
  RepliesInProgress? replies,
  Widget page,
) => MultiProvider(
  providers: [
    if (replies != null) Provider<RepliesInProgress>.value(value: replies),
    ChangeNotifierProvider<ServerCareController>.value(value: care),
    ChangeNotifierProvider<GatewayRestart>.value(value: run),
    ChangeNotifierProvider<HermesUpdateRun>.value(value: update),
  ],
  // A page outlives the shell on the root navigator: it goes when the
  // connection it was opened for ends.
  child: ConnectionBound(child: page),
);

/// The pages the Server screen opens, in the order the first one offered is
/// shown by default on a wide window. A page is added here and in
/// [_ServerScreenState._destinations]; nothing else knows the list.
enum _Page { usage, update, logs }

/// A page to show, and what it opens on. Equal requests are the same page, so
/// asking again for the one on screen keeps it.
typedef _Request = ({_Page page, CareLogFile? file, String? profile});

class _Destination {
  const _Destination(this.page, {required this.offered, required this.build});

  final _Page page;

  /// Whether the server has what the page reads.
  final bool Function() offered;
  final Widget Function(_Request request) build;
}

/// Is Hermes OK, and what is it running on: a headline, then the Hermes
/// version and updates, the messaging gateway, the machine, and the tools.
class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key, this.source = 'menu'});

  final String source;

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late final UpdateCheckController _update;
  late final GatewayRestart _run;
  late final HermesUpdateRun _updateRun;
  bool _updateWasBusy = false;
  Timer? _doneTimer;

  /// Whether the screen shows its pages beside the list; set by the layout.
  bool _wide = false;

  /// The page the person picked on a wide window; null shows the default.
  _Request? _picked;

  @override
  void initState() {
    super.initState();
    final care = context.read<ServerCareController>();
    _run = context.read<GatewayRestart>()..addListener(_runChanged);
    _updateRun = context.read<HermesUpdateRun>();
    _updateWasBusy = _updateRun.busy;
    _updateRun.addListener(_updateRunChanged);
    Breadcrumbs crumbs;
    try {
      crumbs = context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      crumbs = Breadcrumbs.none;
    }
    crumbs('server_care.opened', {'source': widget.source});
    // A run that finished while the screen was closed has said its piece.
    if (_run.phase == GatewayPhase.done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _run.phase == GatewayPhase.done) _run.dismiss();
      });
    }
    _update = UpdateCheckController(
      repository: HermesRepositories.of(context).serverCare,
      onUnsupported: () => care.reportUnsupported(CarePart.update),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      care.refresh();
      _update.check();
    });
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _run.removeListener(_runChanged);
    _updateRun.removeListener(_updateRunChanged);
    _update.dispose();
    super.dispose();
  }

  /// "Running again" stays for a moment, then the row goes back to its action.
  void _runChanged() {
    if (_run.phase != GatewayPhase.done) {
      // A new run must not be cleared by an earlier run's timer.
      _doneTimer?.cancel();
      _doneTimer = null;
    }
    if (_run.phase == GatewayPhase.done && _doneTimer == null) {
      _doneTimer = Timer(const Duration(seconds: 4), () {
        _doneTimer = null;
        if (_run.phase == GatewayPhase.done) _run.dismiss();
      });
    }
  }

  /// An update that ended leaves the check stale: ask again.
  void _updateRunChanged() {
    final busy = _updateRun.busy;
    final ended = _updateWasBusy && !busy && mounted;
    _updateWasBusy = busy;
    if (ended) _update.check(force: true);
  }

  /// The run belongs to the profile shown; one for another profile says
  /// nothing here.
  bool _runIsHere(ServerCareController care) =>
      _run.profile == null || _run.profile == care.profile;

  void _tryAgain(GatewayAction action) {
    _run.dismiss();
    runGatewayAction(context, action);
  }

  Future<void> _refresh() async {
    final care = context.read<ServerCareController>();
    await Future.wait([care.refresh(), _update.check()]);
  }

  /// Pushed routes sit above the shell's provider, so the controller goes
  /// with them.
  void _open(Widget page) {
    final care = context.read<ServerCareController>();
    final run = context.read<GatewayRestart>();
    final update = context.read<HermesUpdateRun>();
    final replies = maybeRepliesInProgress(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _carry(care, run, update, replies, page),
      ),
    );
  }

  late final List<_Destination> _destinations = [
    _Destination(
      _Page.usage,
      offered: () =>
          context.read<ServerCareController>().offers(CarePart.usage),
      build: (_) => const UsagePage(),
    ),
    _Destination(
      _Page.update,
      offered: () => _update.supported,
      build: (_) => UpdatePage(
        controller: _update,
        version: context.read<ServerCareController>().status?.version,
      ),
    ),
    _Destination(
      _Page.logs,
      offered: () => context.read<ServerCareController>().offers(CarePart.logs),
      build: (r) => ServerLogsPage(
        initialFile: r.file ?? CareLogFile.errors,
        profile: r.profile,
      ),
    ),
  ];

  _Destination _destination(_Page page) =>
      _destinations.firstWhere((d) => d.page == page);

  /// The page beside the list: the one picked while the server still offers
  /// it, else the first it offers (Usage), else none.
  _Request? _shown() {
    final picked = _picked;
    if (picked != null && _destination(picked.page).offered()) return picked;
    for (final d in _destinations) {
      if (d.offered()) return (page: d.page, file: null, profile: null);
    }
    return null;
  }

  /// Shows [request]: beside the list on a wide window, else on its own route.
  void _show(_Request request) {
    if (!_wide) return _open(_destination(request.page).build(request));
    if (_picked != request) setState(() => _picked = request);
  }

  /// A row of the overview: keeps the page of that kind that is on screen.
  void _showPage(_Page page) {
    if (_wide && _shown()?.page == page) return;
    _show((page: page, file: null, profile: null));
  }

  /// A page with nothing left to show: the pane falls back to the default.
  void _closePane() {
    if (mounted && _picked != null) setState(() => _picked = null);
  }

  /// Opens the Logs page on [file], if the server has the route.
  void _showLogs(CareLogFile file, {String? profile}) =>
      _show((page: _Page.logs, file: file, profile: profile));

  String? _subtitle(AppLocalizations l10n, ServerCareController care) {
    final profile = care.profile;
    if (profile == null) return null;
    final count = care.status?.profiles.length ?? 0;
    return count > 1
        ? l10n.serverCareProfilesSubtitle(profile, count)
        : profile;
  }

  @override
  Widget build(BuildContext context) {
    final care = context.watch<ServerCareController>();
    // The rows read the run's state; the screen rebuilds with it.
    context.watch<GatewayRestart>();
    context.watch<HermesUpdateRun>();
    // Whether the server has an update check decides which page is offered.
    return ListenableBuilder(
      listenable: _update,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final wide = isWideLayout(context, width: box.maxWidth);
          _wide = wide;
          final overview = _overview(context, care);
          if (!wide) return overview;
          final shown = _shown();
          return ServerSplitView(
            list: overview,
            detail: shown == null
                ? null
                // A page of another request is another element: the old one
                // is disposed and lets go of what it holds.
                : KeyedSubtree(
                    key: ValueKey(shown),
                    child: _destination(shown.page).build(shown),
                  ),
            onClose: _closePane,
          );
        },
      ),
    );
  }

  Widget _overview(BuildContext context, ServerCareController care) {
    final l10n = context.l10n;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final body = ListenableBuilder(
      listenable: _update,
      builder: (context, _) => GroupedListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: _children(context, care),
      ),
    );
    return SettingsScaffold(
      title: l10n.serverCareTitle,
      subtitle: _subtitle(l10n, care),
      actions: [
        SettingsBarAction(
          key: const Key('server-refresh'),
          label: l10n.serverCareRefresh,
          icon: AppIcons.refresh,
          onPressed: care.loading ? null : _refresh,
        ),
      ],
      body: mac ? body : RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }

  List<Widget> _children(BuildContext context, ServerCareController care) {
    final l10n = context.l10n;
    final status = care.status;
    // A failed read hides what the status said earlier: it may be out of
    // date.
    final showStatus = status != null && care.failure == null;
    final shown = _wide ? _shown()?.page : null;
    return [
      _headline(l10n, care),
      // The update check does not depend on the status, so its row stays
      // when the status could not be read.
      ..._hermes(l10n, care, showStatus ? status : null, shown),
      if (showStatus) ..._gateway(l10n, status),
      if (showStatus) ..._machine(l10n, status),
      if (care.offers(CarePart.usage) || care.offers(CarePart.logs))
        GroupedSection(
          header: l10n.serverCareToolsHeader,
          children: [
            if (care.offers(CarePart.usage))
              GroupedRow(
                title: l10n.serverCareUsageTitle,
                subtitle: l10n.serverCareUsageRowSubtitle,
                selected: shown == _Page.usage,
                onTap: () => _showPage(_Page.usage),
              ),
            if (care.offers(CarePart.logs))
              GroupedRow(
                title: l10n.serverCareLogsTitle,
                subtitle: l10n.serverCareLogsRowSubtitle,
                selected: shown == _Page.logs,
                onTap: () => _showPage(_Page.logs),
              ),
          ],
        ),
      GroupedSection(
        children: [
          GroupedRow(
            title: l10n.serverCareConnectionDetails,
            onTap: () => showConnectionDetails(context),
          ),
        ],
      ),
    ];
  }

  Widget _headline(AppLocalizations l10n, ServerCareController care) {
    final status = care.status;
    final attention = care.attention;
    // While a restart or start runs, the headline says so, with no button.
    // care.gatewayBusy outlasts the run by the final status read, so the
    // headline does not flip to the old state in that gap.
    if ((_run.busy || care.gatewayBusy) && _runIsHere(care)) {
      return ServerStatusCard(
        tone: ServerStatusTone.loading,
        title: (_run.action ?? _run.lastAction) == GatewayAction.start
            ? l10n.serverCareGatewayHeadlineStarting
            : l10n.serverCareGatewayHeadlineRestarting,
      );
    }
    ServerStatusButton restartButton() => ServerStatusButton(
      label: l10n.serverCareGatewayRestart,
      onPressed: () => runGatewayAction(context, GatewayAction.restart),
    );
    ServerStatusButton? showLogs(CareLogFile file) => care.offers(CarePart.logs)
        ? ServerStatusButton(
            label: l10n.serverCareShowLogs,
            outlined: true,
            onPressed: () => _showLogs(file),
          )
        : null;
    final retry = ServerStatusButton(
      label: l10n.serverCareTryAgain,
      onPressed: _refresh,
    );
    // A read that failed for any reason but a missing connection says so
    // instead of keeping an older, cheerful answer.
    final failed =
        care.failure != null && care.failure != CareFailureKind.offline;
    if (attention == null || failed || care.profileLookupFailed) {
      if (!care.supported) {
        return ServerStatusCard(
          tone: ServerStatusTone.info,
          title: l10n.serverCareHeadlineUnsupported,
          detail: l10n.serverCareHeadlineUnsupportedDetail,
        );
      }
      if (care.failure != null || care.profileLookupFailed) {
        return ServerStatusCard(
          tone: ServerStatusTone.warning,
          title: l10n.serverCareHeadlineReadFailed,
          detail: l10n.serverCareHeadlineReadFailedDetail,
          button: retry,
        );
      }
      return ServerStatusCard(
        tone: ServerStatusTone.loading,
        title: l10n.serverCareHeadlineChecking,
      );
    }
    ServerStatusCard card(
      ServerStatusTone tone,
      String title, [
      String? detail,
      ServerStatusButton? button,
    ]) => ServerStatusCard(
      tone: tone,
      title: title,
      detail: detail,
      button: button,
    );
    final free = _free(status?.disk.freeMb, l10n.localeName);
    return switch (attention) {
      Attention.offline => card(
        ServerStatusTone.warning,
        l10n.serverCareHeadlineOffline,
        l10n.serverCareHeadlineOfflineDetail,
        retry,
      ),
      Attention.storageUnreadable => card(
        ServerStatusTone.error,
        l10n.serverCareHeadlineStorageUnreadable,
        l10n.serverCareStorageMissingDetail,
      ),
      Attention.gatewayFailed => card(
        ServerStatusTone.error,
        l10n.serverCareHeadlineGatewayFailed,
        l10n.serverCareHeadlineGatewayFailedDetail,
        restartButton(),
      ),
      Attention.gatewayUnresponsive => card(
        ServerStatusTone.warning,
        l10n.serverCareHeadlineGatewayUnresponsive,
        _staleDetail(l10n, status),
        restartButton(),
      ),
      Attention.gatewayOff => card(
        ServerStatusTone.warning,
        l10n.serverCareHeadlineGatewayOff,
        l10n.serverCareHeadlineGatewayOffDetail,
        ServerStatusButton(
          label: l10n.serverCareGatewayStart,
          onPressed: () => runGatewayAction(context, GatewayAction.start),
        ),
      ),
      Attention.diskCritical => card(
        ServerStatusTone.error,
        free == null
            ? l10n.serverCareHeadlineDiskCriticalUnknown
            : l10n.serverCareHeadlineDiskCritical(free),
        l10n.serverCareHeadlineDiskCriticalDetail,
      ),
      // What happened before the restart is in the agent's own log; why a
      // channel is offline is in the gateway's.
      Attention.unexpectedRestart => card(
        ServerStatusTone.warning,
        l10n.serverCareHeadlineRestarted,
        null,
        showLogs(CareLogFile.agent),
      ),
      Attention.channelsOffline => card(
        ServerStatusTone.warning,
        _channelsOffline(l10n, status),
        null,
        showLogs(CareLogFile.gateway),
      ),
      Attention.memoryLow => card(
        ServerStatusTone.info,
        l10n.serverCareHeadlineMemoryLow,
      ),
      Attention.diskLow => card(
        ServerStatusTone.info,
        free == null
            ? l10n.serverCareHeadlineDiskLowUnknown
            : l10n.serverCareHeadlineDiskLow(free),
      ),
      Attention.allGood => card(
        ServerStatusTone.healthy,
        l10n.serverCareHeadlineAllGood,
        switch (status?.version) {
          final v? => l10n.serverCareHeadlineAllGoodDetail(v),
          null => null,
        },
      ),
    };
  }

  static String _staleDetail(AppLocalizations l10n, ServerStatus? status) {
    final seconds = status?.gatewayHeartbeatStaleSeconds;
    if (seconds == null) return l10n.serverCareHeadlineGatewayStale;
    final minutes = (seconds / 60).round().clamp(1, 1 << 30);
    return l10n.serverCareHeadlineGatewayStaleFor(minutes);
  }

  static String _channelsOffline(AppLocalizations l10n, ServerStatus? status) {
    final configured = status?.platformsConfigured;
    final connected = status?.platformsConnected;
    if (configured == null || connected == null || connected >= configured) {
      return l10n.serverCareHeadlineChannelsOffline;
    }
    return l10n.serverCareHeadlineChannelsOfflineCount(
      configured - connected,
      configured,
    );
  }

  /// "8.4 GB", "52 GB", "512 MB"; the decimal mark follows [locale].
  static String? _free(int? mb, String locale) {
    if (mb == null) return null;
    if (mb < 1000) {
      return '${NumberFormat.decimalPattern(locale).format(mb)} MB';
    }
    final gb = mb / 1000;
    final text = gb >= 100 || gb == gb.roundToDouble()
        ? NumberFormat('0', locale).format(gb.round())
        : NumberFormat('0.0', locale).format(gb);
    return '$text GB';
  }

  List<Widget> _hermes(
    AppLocalizations l10n,
    ServerCareController care,
    ServerStatus? status,
    _Page? shown,
  ) {
    final version = status?.version;
    final released = _released(l10n, status?.releaseDate);
    final update = _updateRun.busy
        ? (value: l10n.serverCareUpdateRowUpdating, subtitle: null)
        : _updateRow(l10n, fallbackVersion: version);
    final rows = [
      if (version != null)
        CareValueRow(
          title: l10n.serverCareVersionRow,
          value: version,
          subtitle: released,
        ),
      if (_update.supported)
        CareValueRow(
          title: l10n.serverCareUpdatesRow,
          value: update.value,
          subtitle: update.subtitle,
          selected: shown == _Page.update,
          onTap: () => _showPage(_Page.update),
        ),
    ];
    return rows.isEmpty
        ? []
        : [GroupedSection(header: 'Hermes', children: rows)];
  }

  CareRowText _updateRow(AppLocalizations l10n, {String? fallbackVersion}) {
    final row = _update.rowState(fallbackVersion: fallbackVersion);
    return (
      value: switch (row.kind) {
        UpdateRowKind.none => null,
        UpdateRowKind.checking => l10n.serverCareUpdateChecking,
        UpdateRowKind.upToDate => l10n.serverCareUpdateUpToDate,
        UpdateRowKind.failed => l10n.serverCareUpdateCouldntCheck,
        UpdateRowKind.available => l10n.serverCareUpdateAvailable,
      },
      subtitle: switch (row.changeCount) {
        final count? when row.kind == UpdateRowKind.available =>
          l10n.serverCareUpdateChanges(count),
        _ => null,
      },
    );
  }

  static String? _released(AppLocalizations l10n, String? date) {
    final parsed = date == null ? null : DateTime.tryParse(date);
    if (parsed == null) return null;
    return l10n.serverCareReleased(parsed);
  }

  List<Widget> _gateway(AppLocalizations l10n, ServerStatus status) {
    final configured = status.platformsConfigured ?? 0;
    final connected = status.platformsConnected;
    final shared = status.gatewaySharedWith;
    final state = status.gatewayHeartbeatStaleSeconds != null
        ? l10n.serverCareGatewayStateNotResponding
        : switch (status.gatewayState) {
            GatewayState.running => l10n.serverCareGatewayStateRunning,
            GatewayState.starting => l10n.serverCareGatewayStateStarting,
            GatewayState.degraded => l10n.serverCareGatewayStateDegraded,
            GatewayState.draining => l10n.serverCareGatewayStateDraining,
            GatewayState.stopped => l10n.serverCareGatewayStateOff,
            GatewayState.startupFailed => l10n.serverCareGatewayStateFailed,
            GatewayState.other =>
              status.gatewayStateRaw ?? l10n.serverCareGatewayStateUnknown,
            null =>
              status.gatewayRunning
                  ? l10n.serverCareGatewayStateRunning
                  : l10n.serverCareGatewayStateOff,
          };
    return [
      GroupedSection(
        header: l10n.serverCareGatewayHeader,
        footer: l10n.serverCareGatewayFooter,
        children: [
          CareValueRow(title: l10n.serverCareGatewayStateRow, value: state),
          // While the gateway is off, how many channels are connected says
          // nothing a person can use next to "Off".
          if (status.gatewayRunning && configured > 0 && connected != null)
            CareValueRow(
              title: l10n.serverCareChannelsRow,
              value: l10n.serverCareChannelsConnected(connected, configured),
            ),
          if (shared.length > 1)
            CareValueRow(
              title: l10n.serverCareGatewaySharedWith,
              value: shared.join(', '),
            ),
          GroupedActionRow(
            title: _restartsGateway(status)
                ? l10n.serverCareGatewayRestart
                : l10n.serverCareGatewayStart,
            icon: _restartsGateway(status) ? AppIcons.refresh : AppIcons.play,
            onPressed: () => runGatewayAction(
              context,
              _restartsGateway(status)
                  ? GatewayAction.restart
                  : GatewayAction.start,
            ),
            status: !_runIsHere(context.read<ServerCareController>())
                ? null
                : gatewayRowStatus(
                    l10n,
                    _run,
                    onTryAgain: () =>
                        _tryAgain(_run.action ?? GatewayAction.restart),
                    onShowLogs:
                        context.read<ServerCareController>().offers(
                          CarePart.logs,
                        )
                        ? () => _showLogs(
                            CareLogFile.gateway,
                            profile: _run.profile,
                          )
                        : null,
                  ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _machine(AppLocalizations l10n, ServerStatus status) {
    final disk = status.disk;
    final free = _free(disk.freeMb, l10n.localeName);
    final used = disk.usedPercent;
    final memory = switch (status.memory.pressure) {
      Pressure.ok => l10n.serverCareOk,
      Pressure.elevated => l10n.serverCareMemoryGettingLow,
      Pressure.critical => l10n.serverCareMemoryLow,
      Pressure.unknown => null,
    };
    final rows = [
      if (free != null)
        CareValueRow(
          title: l10n.serverCareDiskRow,
          value: l10n.serverCareDiskFree(free),
          subtitle: used == null
              ? null
              : l10n.serverCareDiskPercentUsed(used.round()),
          warning: switch (disk.pressure) {
            Pressure.elevated => l10n.serverCareDiskWarningLow,
            Pressure.critical => l10n.serverCareDiskWarningCritical,
            _ => null,
          },
        ),
      if (memory != null)
        CareValueRow(title: l10n.serverCareMemoryRow, value: memory),
      if (status.storageOk != null || status.storageCorrupt)
        CareValueRow(
          title: l10n.serverCareSessionStoreRow,
          value: status.storageOk == true && !status.storageCorrupt
              ? l10n.serverCareOk
              : l10n.serverCareSessionStoreUnreadable,
          error: status.storageOk == true && !status.storageCorrupt
              ? null
              : l10n.serverCareStorageMissingDetail,
        ),
    ];
    return rows.isEmpty
        ? []
        : [
            GroupedSection(
              header: l10n.serverCareMachineHeader,
              children: rows,
            ),
          ];
  }
}

/// A gateway that is running, or one that failed to start, is restarted (after
/// a question); only one that is off is started.
bool _restartsGateway(ServerStatus status) =>
    status.gatewayRunning || Attention.of(status) == Attention.gatewayFailed;
