import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_repositories.dart';
import '../settings/account_actions.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'attention.dart';
import 'care_result.dart';
import 'gateway_actions.dart';
import 'gateway_restart.dart';
import 'server_care_controller.dart';
import 'server_status.dart';
import 'update_check_controller.dart';
import 'update_page.dart';
import 'usage_page.dart';
import 'widgets/care_row_value.dart';
import 'widgets/grouped_action_row.dart';
import 'widgets/server_status_card.dart';

/// Pushes the Server screen as a settings page. [source] says where the
/// person came from (a fixed name such as `menu`), for the breadcrumb.
Future<void> showServerScreen(BuildContext context, {required String source}) {
  // The pushed route sits above the shell's provider, so it is passed on.
  final care = context.read<ServerCareController>();
  final run = context.read<GatewayRestart>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _carry(care, run, ServerScreen(source: source)),
    ),
  );
}

Widget _carry(ServerCareController care, GatewayRestart run, Widget page) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerCareController>.value(value: care),
        ChangeNotifierProvider<GatewayRestart>.value(value: run),
      ],
      child: page,
    );

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
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    final care = context.read<ServerCareController>();
    _run = context.read<GatewayRestart>()..addListener(_runChanged);
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => _carry(care, run, page)));
  }

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
    return [
      _headline(l10n, care),
      // The update check does not depend on the status, so its row stays
      // when the status could not be read.
      ..._hermes(l10n, care, showStatus ? status : null),
      if (showStatus) ..._gateway(l10n, status),
      if (showStatus) ..._machine(l10n, status),
      if (care.offers(CarePart.usage))
        GroupedSection(
          header: l10n.serverCareToolsHeader,
          children: [
            GroupedRow(
              title: l10n.serverCareUsageTitle,
              subtitle: l10n.serverCareUsageRowSubtitle,
              onTap: () => _open(const UsagePage()),
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
    if (_run.busy && _runIsHere(care)) {
      return ServerStatusCard(
        tone: ServerStatusTone.loading,
        title: _run.action == GatewayAction.start
            ? l10n.serverCareGatewayHeadlineStarting
            : l10n.serverCareGatewayHeadlineRestarting,
      );
    }
    ServerStatusButton restartButton() => ServerStatusButton(
      label: l10n.serverCareGatewayRestart,
      onPressed: () => runGatewayAction(context, GatewayAction.restart),
    );
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
      Attention.unexpectedRestart => card(
        ServerStatusTone.warning,
        l10n.serverCareHeadlineRestarted,
      ),
      Attention.channelsOffline => card(
        ServerStatusTone.warning,
        _channelsOffline(l10n, status),
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
  ) {
    final version = status?.version;
    final released = _released(l10n, status?.releaseDate);
    final update = _updateRow(l10n, fallbackVersion: version);
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
          onTap: () => _open(UpdatePage(controller: _update, version: version)),
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
