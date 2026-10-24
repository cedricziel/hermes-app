import 'dart:async';

import 'package:flutter/foundation.dart';

import '../telemetry/breadcrumbs.dart';
import 'memory_repository.dart';
import 'memory_settings.dart';
import 'memory_settings_repository.dart';

/// The Learning section's state for one profile. A change shows at once and
/// is sent as its own key; when the server does not take it, the control goes
/// back to the last value the server confirmed.
class MemorySettingsController extends ChangeNotifier {
  MemorySettingsController({this.breadcrumbs = Breadcrumbs.none});
  final Breadcrumbs breadcrumbs;

  MemorySettingsRepository? _repository;
  String? _profile;
  MemorySettings? _confirmed;
  final _writing = <MemorySetting>{};
  final _running = <Future<void>>{};
  int _generation = 0;
  bool _disposed = false;

  /// What the controls show; null until the config is read, and after a read
  /// that failed.
  MemorySettings? settings;
  bool loading = false;
  bool unreadable = false;

  /// What the last refused change says, until the next change.
  String? message;

  /// Completes when every read and write started so far has ended.
  Future<void> get whenIdle async {
    while (_running.isNotEmpty) {
      await Future.wait(_running.toList());
    }
  }

  void _track(Future<void> work) {
    _running.add(work);
    work.whenComplete(() => _running.remove(work));
  }

  void bind(MemorySettingsRepository? repository, String? profile) {
    if (identical(_repository, repository) && _profile == profile) return;
    _generation++;
    _repository = repository;
    _profile = profile;
    _confirmed = settings = null;
    _writing.clear();
    message = null;
    unreadable = false;
    loading = false;
    notifyListeners();
    if (repository != null && profile != null && profile.isNotEmpty) {
      _track(load());
    }
  }

  Future<void> load() async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null || profile.isEmpty) return;
    final generation = ++_generation;
    loading = true;
    unreadable = false;
    notifyListeners();
    try {
      final read = await repository.read(profile);
      if (_disposed || generation != _generation) return;
      _confirmed = settings = read;
    } on MemoryFailure {
      if (_disposed || generation != _generation) return;
      _confirmed = settings = null;
      unreadable = true;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void change(MemorySetting setting, Object value) {
    final shown = settings;
    if (shown == null || shown.valueOf(setting) == value) return;
    breadcrumbs('memory.setting_toggled', {'key': setting.key});
    message = null;
    settings = shown.withValue(setting, value);
    notifyListeners();
    if (_writing.add(setting)) _track(_flush(setting));
  }

  /// Sends [setting] until what the server confirmed is what is shown, so a
  /// change made during a write goes out after it with the latest value.
  Future<void> _flush(MemorySetting setting) async {
    final generation = _generation;
    final repository = _repository, profile = _profile;
    bool stale() => _disposed || generation != _generation;
    while (repository != null && profile != null) {
      final wanted = settings?.valueOf(setting);
      final confirmed = _confirmed?.valueOf(setting);
      if (wanted == null || confirmed == null || wanted == confirmed) break;
      try {
        await repository.write(profile, setting, wanted);
        if (stale()) return;
        _confirmed = _confirmed!.withValue(setting, wanted);
      } on MemoryWriteFailure {
        if (stale()) return;
        message = "Couldn't change ${setting.label}. Try again.";
        if (settings!.valueOf(setting) == wanted) {
          settings = settings!.withValue(setting, confirmed);
          notifyListeners();
          break;
        }
        notifyListeners();
      }
    }
    if (!stale()) _writing.remove(setting);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
