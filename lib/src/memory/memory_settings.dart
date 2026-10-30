import 'package:flutter/foundation.dart' show mapEquals;

/// The per-profile config keys the Learning section changes.
enum MemorySetting {
  userProfile('memory', 'user_profile_enabled', 'Remember things about me'),
  agentNotes('memory', 'memory_enabled', 'Keep agent notes'),
  writeApproval('memory', 'write_approval', 'Ask before saving'),
  reviewInterval('memory', 'nudge_interval', 'Review chats'),
  updatesInChat('display', 'memory_notifications', 'Memory updates in chat');

  const MemorySetting(this.section, this.key, this.label);

  /// The config table the key lives in.
  final String section;

  /// The config key, also the fixed slug telemetry carries.
  final String key;
  final String label;
}

/// What the Learning section shows for a profile: a `bool` for each switch,
/// the review interval as an `int` (user turns, 0 is off) and the in-chat
/// reports as `off`, `on` or `verbose`. Hermes reads `write_approval` at every
/// write and the other keys when a chat starts.
class MemorySettings {
  const MemorySettings._(this._values);

  /// What Hermes uses for a key the config does not hold.
  static const defaults = MemorySettings._({
    MemorySetting.userProfile: true,
    MemorySetting.agentNotes: true,
    MemorySetting.writeApproval: false,
    MemorySetting.reviewInterval: 10,
    MemorySetting.updatesInChat: 'on',
  });

  /// Reads the answer of `GET /api/config`, taking the default for a key that
  /// is missing or of the wrong type.
  factory MemorySettings.fromConfig(Map<Object?, Object?> config) {
    Object read(MemorySetting setting) {
      final table = config[setting.section];
      final value = table is Map ? table[setting.key] : null;
      final fallback = defaults.valueOf(setting);
      final fits =
          value != null &&
          value.runtimeType == fallback.runtimeType &&
          (value is! int || value >= 0);
      return fits ? value : fallback;
    }

    return MemorySettings._({
      for (final setting in MemorySetting.values) setting: read(setting),
    });
  }

  final Map<MemorySetting, Object> _values;

  Object valueOf(MemorySetting setting) => _values[setting]!;

  bool get userProfile => _values[MemorySetting.userProfile]! as bool;
  bool get agentNotes => _values[MemorySetting.agentNotes]! as bool;
  bool get writeApproval => _values[MemorySetting.writeApproval]! as bool;
  int get reviewInterval => _values[MemorySetting.reviewInterval]! as int;

  /// A value other than `off`, `on` and `verbose` is one another client wrote.
  String get updatesInChat => _values[MemorySetting.updatesInChat]! as String;

  MemorySettings withValue(MemorySetting setting, Object value) =>
      MemorySettings._({..._values, setting: value});

  @override
  bool operator ==(Object other) =>
      other is MemorySettings && mapEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values.values);
}
