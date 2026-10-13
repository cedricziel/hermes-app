import 'dart:async';

class ToolOutputRisk {
  const ToolOutputRisk({
    required this.risk,
    required this.findings,
    required this.redacted,
  });
  final String risk;
  final List<String> findings;
  final bool redacted;
}

class AgentNotice {
  const AgentNotice({
    required this.text,
    this.level = 'info',
    this.kind = 'sticky',
    this.key,
    this.ttlMs,
  });
  final String text;
  final String level;
  final String kind;
  final String? key;
  final int? ttlMs;
}

class ChatWarningState {
  ChatWarningState({required this.changed});
  final void Function() changed;
  final notices = <AgentNotice>[];
  final risks = <String, ToolOutputRisk>{};
  final _timers = <AgentNotice, Timer>{};
  String? _runtimeId;
  String? get runtimeId => _runtimeId;

  void adopt(String runtimeId) {
    if (_runtimeId == runtimeId) return;
    final hadNotices = notices.isNotEmpty;
    clear();
    _runtimeId = runtimeId;
    if (hadNotices) changed();
  }

  void show(AgentNotice notice) {
    final key = notice.key;
    if (key != null && key.isNotEmpty) {
      for (final old in notices.where((n) => n.key == key).toList()) {
        _remove(old);
      }
    }
    notices.add(notice);
    if (notice.kind == 'ttl' && (notice.ttlMs ?? 0) > 0) {
      _timers[notice] = Timer(
        Duration(milliseconds: notice.ttlMs!),
        () => dismiss(notice),
      );
    }
    changed();
  }

  void withdraw(String key) {
    if (key.isEmpty) return;
    for (final notice in notices.where((n) => n.key == key).toList()) {
      _remove(notice);
    }
    changed();
  }

  void dismiss(AgentNotice notice) {
    if (!notices.contains(notice)) return;
    _remove(notice);
    changed();
  }

  void _remove(AgentNotice notice) {
    notices.remove(notice);
    _timers.remove(notice)?.cancel();
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    notices.clear();
    risks.clear();
  }
}
