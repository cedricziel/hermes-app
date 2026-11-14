import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../settings/account_actions.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'attention.dart';
import 'care_result.dart';
import 'server_care_controller.dart';
import 'server_status.dart';
import 'update_check_controller.dart';
import 'update_page.dart';
import 'usage_page.dart';
import 'widgets/care_row_value.dart';
import 'widgets/server_status_card.dart';
import 'widgets/usage_format.dart';

/// Pushes the Server screen as a settings page. [source] says where the
/// person came from (a fixed name such as `menu`), for the breadcrumb.
Future<void> showServerScreen(BuildContext context, {required String source}) {
  // The pushed route sits above the shell's provider, so it is passed on.
  final care = context.read<ServerCareController>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<ServerCareController>.value(
        value: care,
        child: ServerScreen(source: source),
      ),
    ),
  );
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

  @override
  void initState() {
    super.initState();
    final care = context.read<ServerCareController>();
    Breadcrumbs crumbs;
    try {
      crumbs = context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      crumbs = Breadcrumbs.none;
    }
    crumbs('server_care.opened', {'source': widget.source});
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
    _update.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final care = context.read<ServerCareController>();
    await Future.wait([care.refresh(), _update.check()]);
  }

  /// Pushed routes sit above the shell's provider, so the controller goes
  /// with them.
  void _open(Widget page) {
    final care = context.read<ServerCareController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ServerCareController>.value(
          value: care,
          child: page,
        ),
      ),
    );
  }

  String? _subtitle(ServerCareController care) {
    final profile = care.profile;
    if (profile == null) return null;
    final count = care.status?.profiles.length ?? 0;
    return count > 1 ? '$profile · $count profiles' : profile;
  }

  @override
  Widget build(BuildContext context) {
    final care = context.watch<ServerCareController>();
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final body = ListenableBuilder(
      listenable: _update,
      builder: (context, _) => GroupedListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: _children(context, care),
      ),
    );
    return SettingsScaffold(
      title: 'Server',
      subtitle: _subtitle(care),
      actions: [
        SettingsBarAction(
          key: const Key('server-refresh'),
          label: 'Refresh',
          icon: AppIcons.refresh,
          onPressed: care.loading ? null : _refresh,
        ),
      ],
      body: mac ? body : RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }

  List<Widget> _children(BuildContext context, ServerCareController care) {
    final status = care.status;
    // A failed read hides what the status said earlier: it may be out of
    // date.
    final showStatus = status != null && care.failure == null;
    return [
      _headline(care),
      if (showStatus || !care.supported) ..._hermes(care, status),
      if (showStatus) ..._gateway(status),
      if (showStatus) ..._machine(status),
      if (care.offers(CarePart.usage))
        GroupedSection(
          header: 'Tools',
          children: [
            GroupedRow(
              title: 'Usage',
              subtitle: 'Tokens and cost by day and model',
              onTap: () => _open(const UsagePage()),
            ),
          ],
        ),
      GroupedSection(
        children: [
          GroupedRow(
            title: 'Connection details',
            onTap: () => showConnectionDetails(context),
          ),
        ],
      ),
    ];
  }

  Widget _headline(ServerCareController care) {
    final status = care.status;
    final attention = care.attention;
    final retry = ServerStatusButton(label: 'Try again', onPressed: _refresh);
    // A read that failed for any reason but a missing connection says so
    // instead of keeping an older, cheerful answer.
    final failed =
        care.failure != null && care.failure != CareFailureKind.offline;
    if (attention == null || failed || care.profileLookupFailed) {
      if (!care.supported) {
        return const ServerStatusCard(
          tone: ServerStatusTone.info,
          title: "This server can't report its status",
          detail: 'Update Hermes on the server to see more here.',
        );
      }
      if (care.failure != null || care.profileLookupFailed) {
        return ServerStatusCard(
          tone: ServerStatusTone.warning,
          title: "Couldn't read Hermes' status",
          detail: 'Try again in a moment.',
          button: retry,
        );
      }
      return const ServerStatusCard(
        tone: ServerStatusTone.loading,
        title: 'Checking Hermes…',
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
    return switch (attention) {
      Attention.offline => card(
        ServerStatusTone.warning,
        "Can't reach Hermes",
        "Check that the server is on and that you're connected to its "
            'network.',
        retry,
      ),
      Attention.storageUnreadable => card(
        ServerStatusTone.error,
        "Hermes can't read its session store",
        "Chats and usage may be missing until it's repaired.",
      ),
      Attention.gatewayFailed => card(
        ServerStatusTone.error,
        'The messaging gateway stopped with an error',
        'Messaging channels and scheduled tasks are paused.',
      ),
      Attention.gatewayUnresponsive => card(
        ServerStatusTone.warning,
        "The messaging gateway isn't responding",
        _staleDetail(status),
      ),
      Attention.gatewayOff => card(
        ServerStatusTone.warning,
        'The messaging gateway is off',
        "Messaging channels and scheduled tasks don't run while it's off.",
      ),
      Attention.diskCritical => card(
        ServerStatusTone.error,
        'Disk almost full: ${_free(status?.disk.freeMb) ?? 'little'} free',
        'Hermes may stop saving chats. Free up space on the server.',
      ),
      Attention.unexpectedRestart => card(
        ServerStatusTone.warning,
        'Hermes restarted unexpectedly, probably out of memory',
      ),
      Attention.channelsOffline => card(
        ServerStatusTone.warning,
        _channelsOffline(status),
      ),
      Attention.memoryLow => card(
        ServerStatusTone.info,
        'Memory is low on the server',
      ),
      Attention.diskLow => card(
        ServerStatusTone.info,
        'Disk space is getting low: ${_free(status?.disk.freeMb) ?? 'little'} '
        'free',
      ),
      Attention.allGood => card(
        ServerStatusTone.healthy,
        'Everything looks good',
        switch (status?.version) {
          final v? => 'Hermes $v',
          null => null,
        },
      ),
    };
  }

  static String _staleDetail(ServerStatus? status) {
    final seconds = status?.gatewayHeartbeatStaleSeconds;
    if (seconds == null) return "It's running but hasn't checked in.";
    final minutes = (seconds / 60).round().clamp(1, 1 << 30);
    final unit = minutes == 1 ? 'minute' : 'minutes';
    return "It's running but hasn't checked in for $minutes $unit.";
  }

  static String _channelsOffline(ServerStatus? status) {
    final configured = status?.platformsConfigured;
    final connected = status?.platformsConnected;
    if (configured == null || connected == null || connected >= configured) {
      return 'Some messaging channels are offline';
    }
    final offline = configured - connected;
    return '$offline of $configured messaging channels are '
        'offline';
  }

  /// "8.4 GB", "52 GB", "512 MB".
  static String? _free(int? mb) {
    if (mb == null) return null;
    if (mb < 1000) return '$mb MB';
    final gb = mb / 1000;
    final text = gb >= 100 || gb == gb.roundToDouble()
        ? gb.round().toString()
        : gb.toStringAsFixed(1);
    return '$text GB';
  }

  List<Widget> _hermes(ServerCareController care, ServerStatus? status) {
    final version = status?.version;
    final released = _released(status?.releaseDate);
    final update = _update.rowText(fallbackVersion: version);
    final rows = [
      if (version != null)
        CareValueRow(title: 'Version', value: version, subtitle: released),
      if (_update.supported)
        CareValueRow(
          title: 'Updates',
          value: update.value,
          subtitle: update.subtitle,
          onTap: () => _open(UpdatePage(controller: _update, version: version)),
        ),
    ];
    return rows.isEmpty
        ? []
        : [GroupedSection(header: 'Hermes', children: rows)];
  }

  static String? _released(String? date) {
    final parsed = date == null ? null : DateTime.tryParse(date);
    if (parsed == null) return null;
    return 'Released ${formatDayShort(parsed)} ${parsed.year}';
  }

  List<Widget> _gateway(ServerStatus status) {
    final configured = status.platformsConfigured ?? 0;
    final connected = status.platformsConnected;
    final shared = status.gatewaySharedWith;
    final state = status.gatewayHeartbeatStaleSeconds != null
        ? 'Not responding'
        : switch (status.gatewayState) {
            GatewayState.running => 'Running',
            GatewayState.starting => 'Starting',
            GatewayState.degraded => 'Running, some channels offline',
            GatewayState.draining => 'Draining',
            GatewayState.stopped => 'Off',
            GatewayState.startupFailed => 'Failed to start',
            GatewayState.other => status.gatewayStateRaw ?? 'Unknown',
            null => status.gatewayRunning ? 'Running' : 'Off',
          };
    return [
      GroupedSection(
        header: 'Messaging gateway',
        footer:
            'Runs your messaging channels and scheduled tasks. Chats in this '
            "app don't depend on it.",
        children: [
          CareValueRow(title: 'State', value: state),
          // While the gateway is off, how many channels are connected says
          // nothing a person can use next to "Off".
          if (status.gatewayRunning && configured > 0 && connected != null)
            CareValueRow(
              title: 'Channels',
              value: '$connected of $configured connected',
            ),
          if (shared.length > 1)
            CareValueRow(title: 'Shared with', value: shared.join(', ')),
        ],
      ),
    ];
  }

  List<Widget> _machine(ServerStatus status) {
    final disk = status.disk;
    final free = _free(disk.freeMb);
    final used = disk.usedPercent;
    final memory = switch (status.memory.pressure) {
      Pressure.ok => 'OK',
      Pressure.elevated => 'Getting low',
      Pressure.critical => 'Low',
      Pressure.unknown => null,
    };
    final rows = [
      if (free != null)
        CareValueRow(
          title: 'Disk',
          value: '$free free',
          subtitle: used == null ? null : '${used.round()}% used',
          warning: switch (disk.pressure) {
            Pressure.elevated => 'Disk space is getting low.',
            Pressure.critical =>
              'Disk is almost full. Hermes may stop saving chats.',
            _ => null,
          },
        ),
      if (memory != null) CareValueRow(title: 'Memory', value: memory),
      if (status.storageOk != null || status.storageCorrupt)
        CareValueRow(
          title: 'Session store',
          value: status.storageOk == true && !status.storageCorrupt
              ? 'OK'
              : "Can't be read",
          error: status.storageOk == true && !status.storageCorrupt
              ? null
              : "Chats and usage may be missing until it's repaired.",
        ),
    ];
    return rows.isEmpty
        ? []
        : [GroupedSection(header: 'Server', children: rows)];
  }
}
