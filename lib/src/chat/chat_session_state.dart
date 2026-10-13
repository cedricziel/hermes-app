class SessionControlSnapshot {
  const SessionControlSnapshot({
    required this.revision,
    this.goal,
    this.loop,
    this.heartbeat,
  });

  final String revision;
  final Map<String, Object?>? goal;
  final Map<String, Object?>? loop;
  final Map<String, Object?>? heartbeat;

  static SessionControlSnapshot? decode(Object? value) {
    if (value is! Map || value['revision'] is! String) return null;
    Map<String, Object?>? section(String key) {
      final data = value[key];
      if (data is! Map) return null;
      return Map.unmodifiable({
        for (final entry in data.entries)
          if (entry.key is String &&
              (entry.value is String ||
                  entry.value is num ||
                  entry.value is bool))
            entry.key as String: entry.value,
      });
    }

    return SessionControlSnapshot(
      revision: value['revision'] as String,
      goal: section('goal'),
      loop: section('loop'),
      heartbeat: section('heartbeat'),
    );
  }

  bool get isEmpty => goal == null && loop == null && heartbeat == null;
}

class ResumeProgress {
  const ResumeProgress(this.phase, this.status, {this.message});
  final String phase;
  final String status;
  final String? message;
}

class ChatSessionState {
  String? runtimeId;
  SessionControlSnapshot? control;
  final waits = <String, String>{};
  ResumeProgress? resume;
  String? reclaimedReason;
  bool unavailable = false;

  void adopt(String runtime) {
    if (runtimeId == runtime) return;
    clear();
    runtimeId = runtime;
  }

  bool get visible =>
      control?.isEmpty == false ||
      waits.isNotEmpty ||
      resume != null ||
      reclaimedReason != null ||
      unavailable;

  void clear() {
    runtimeId = null;
    control = null;
    waits.clear();
    resume = null;
    reclaimedReason = null;
    unavailable = false;
  }
}
