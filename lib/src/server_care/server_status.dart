import 'json_read.dart';

/// The gateway's state as `/api/status` reports it; a string this app does not
/// know is kept as [GatewayState.other] with the raw text.
enum GatewayState {
  running,
  starting,
  degraded,
  draining,
  stopped,
  startupFailed,
  other,
}

GatewayState _gatewayState(String? raw) => switch (raw) {
  'running' => GatewayState.running,
  'starting' => GatewayState.starting,
  'degraded' => GatewayState.degraded,
  'draining' => GatewayState.draining,
  'stopped' => GatewayState.stopped,
  'startup_failed' => GatewayState.startupFailed,
  _ => GatewayState.other,
};

/// How worried a resource reading is. `unknown` also covers an old server that
/// sends nothing.
enum Pressure {
  ok,
  elevated,
  critical,
  unknown;

  static Pressure parse(Object? raw) => switch (raw) {
    'ok' => ok,
    'elevated' => elevated,
    'critical' => critical,
    _ => unknown,
  };
}

class DiskStatus {
  const DiskStatus({
    this.pressure = Pressure.unknown,
    this.freeMb,
    this.usedPercent,
  });

  final Pressure pressure;
  final int? freeMb;
  final double? usedPercent;
}

class MemoryStatus {
  const MemoryStatus({
    this.pressure = Pressure.unknown,
    this.lastBootSuspectedOom = false,
  });

  final Pressure pressure;
  final bool lastBootSuspectedOom;
}

/// What `GET /api/status` says about the machine Hermes runs on. Every field
/// that an older server may not send is nullable or has a neutral default:
/// unknown is never read as a problem.
class ServerStatus {
  const ServerStatus({
    this.version,
    this.releaseDate,
    this.canUpdateHermes,
    this.gatewayRunning = false,
    this.gatewayState,
    this.gatewayStateRaw,
    this.gatewayHeartbeatStaleSeconds,
    this.gatewaySharedWith = const [],
    this.activeAgents = 0,
    this.configVersion,
    this.latestConfigVersion,
    this.storageOk,
    this.storageCorrupt = false,
    this.platformsConfigured,
    this.platformsConnected,
    this.disk = const DiskStatus(),
    this.memory = const MemoryStatus(),
    this.profiles = const [],
  });

  /// Reads [json] leniently; null when it is not an object at all.
  static ServerStatus? parse(Object? json) {
    final root = readMap(json);
    if (root == null) return null;
    final components = readMap(root['components']);
    final storage = readMap(components?['storage']);
    final platforms = readMap(components?['platforms']);
    final disk = readMap(root['disk']);
    final memory = readMap(root['memory']);
    final stateRaw = readString(root['gateway_state']);
    final storageStatus = readString(storage?['status']);
    final storageReason = readString(storage?['reason']);
    return ServerStatus(
      version: readVersion(root['version']),
      releaseDate: readString(root['release_date']),
      canUpdateHermes: readBool(root['can_update_hermes']),
      gatewayRunning: readBool(root['gateway_running']) ?? false,
      gatewayState: stateRaw == null ? null : _gatewayState(stateRaw),
      gatewayStateRaw: stateRaw,
      gatewayHeartbeatStaleSeconds: readDouble(
        root['gateway_heartbeat_stale_s'],
      ),
      gatewaySharedWith: readStrings(root['gateway_shared_with']),
      activeAgents: readInt(root['active_agents']) ?? 0,
      configVersion: readInt(root['config_version']),
      latestConfigVersion: readInt(root['latest_config_version']),
      storageOk: storageStatus == null ? null : storageStatus == 'ok',
      storageCorrupt: storageReason == 'corrupt',
      platformsConfigured: readInt(platforms?['configured']),
      platformsConnected: readInt(platforms?['connected']),
      disk: DiskStatus(
        pressure: Pressure.parse(disk?['pressure']),
        freeMb: readInt(disk?['free_mb']),
        usedPercent: readDouble(disk?['used_percent']),
      ),
      memory: MemoryStatus(
        pressure: Pressure.parse(memory?['pressure']),
        lastBootSuspectedOom:
            readBool(memory?['last_boot_suspected_oom']) ?? false,
      ),
      profiles: readStrings(root['profiles']),
    );
  }

  final String? version;
  final String? releaseDate;
  final bool? canUpdateHermes;
  final bool gatewayRunning;

  /// Null when the server sent no state (an old server).
  final GatewayState? gatewayState;

  /// The state text as sent, for [GatewayState.other].
  final String? gatewayStateRaw;
  final double? gatewayHeartbeatStaleSeconds;
  final List<String> gatewaySharedWith;
  final int activeAgents;
  final int? configVersion;
  final int? latestConfigVersion;

  /// Null when `components.storage` is absent.
  final bool? storageOk;
  final bool storageCorrupt;
  final int? platformsConfigured;
  final int? platformsConnected;
  final DiskStatus disk;
  final MemoryStatus memory;
  final List<String> profiles;
}
