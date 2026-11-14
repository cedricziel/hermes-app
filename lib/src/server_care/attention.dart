import 'server_status.dart';

/// What the Server screen's headline says, in the order of the table in the
/// design: the first matching row wins.
enum Attention {
  offline,
  storageUnreadable,
  gatewayFailed,
  gatewayUnresponsive,
  gatewayOff,
  diskCritical,
  unexpectedRestart,
  channelsOffline,
  memoryLow,
  diskLow,
  allGood;

  /// Whether the account button and the Mac sidebar show their "needs
  /// attention" mark: every row above the disk-elevated one.
  bool get needsAttention => switch (this) {
    offline ||
    storageUnreadable ||
    gatewayFailed ||
    gatewayUnresponsive ||
    gatewayOff ||
    diskCritical ||
    unexpectedRestart ||
    channelsOffline => true,
    memoryLow || diskLow || allGood => false,
  };

  /// The ranking for a status read; [status] is null when the read failed
  /// because the server could not be reached.
  static Attention of(ServerStatus? status) {
    if (status == null) return offline;
    if (status.storageCorrupt || status.storageOk == false) {
      return storageUnreadable;
    }
    final state = status.gatewayState;
    if (state == GatewayState.startupFailed ||
        (state == GatewayState.degraded && !status.gatewayRunning)) {
      return gatewayFailed;
    }
    if (status.gatewayHeartbeatStaleSeconds != null) return gatewayUnresponsive;
    final configured = status.platformsConfigured ?? 0;
    final connected = status.platformsConnected;
    // A stopped gateway with no channel configured is neutral: scheduled tasks
    // need it too, but that is not worth a mark.
    if (!status.gatewayRunning && configured > 0) return gatewayOff;
    if (status.disk.pressure == Pressure.critical) return diskCritical;
    if (status.memory.lastBootSuspectedOom) return unexpectedRestart;
    if (state == GatewayState.degraded ||
        (connected != null && configured > 0 && connected < configured)) {
      return channelsOffline;
    }
    if (status.memory.pressure == Pressure.critical) return memoryLow;
    if (status.disk.pressure == Pressure.elevated) return diskLow;
    return allGood;
  }
}
