import 'dart:async';

import 'package:flutter/foundation.dart';

import '../telemetry/breadcrumbs.dart';
import 'memory_provider.dart';
import 'memory_repository.dart';
import 'memory_settings.dart';
import 'memory_settings_repository.dart';

/// The state of the Learning and Storage sections for one profile. A change
/// shows at once and is sent as its own key; when the server does not take it,
/// the control goes back to the last value the server confirmed.
class MemorySettingsController extends ChangeNotifier {
  MemorySettingsController({this.breadcrumbs = Breadcrumbs.none, this.onReset});
  final Breadcrumbs breadcrumbs;

  /// Reads the memory entries again after a reset.
  final Future<void> Function()? onReset;

  MemorySettingsRepository? _repository;
  String? _profile;
  MemorySettings? _confirmed;
  final _writing = <MemorySetting>{};
  final _running = <Future<void>>{};
  int _generation = 0;

  /// Counts the config reads, so the newest answer wins.
  int _reads = 0;
  bool _disposed = false;

  /// What the controls show; null until the config is read, and after a read
  /// that failed.
  MemorySettings? settings;
  bool loading = false;
  bool unreadable = false;

  /// What the last refused change says, until the next change.
  String? message;

  /// The memory provider; null until it is read, and after a read that
  /// failed.
  MemoryProviderStatus? provider;
  bool providerFailed = false;
  bool resetting = false;

  /// What the last reset came to, until the next one or another profile.
  MemoryNotice? notice;

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
    provider = null;
    providerFailed = false;
    resetting = false;
    notice = null;
    notifyListeners();
    if (repository != null && profile != null && profile.isNotEmpty) {
      _track(load());
      _track(loadProvider());
    }
  }

  Future<void> load() async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null || profile.isEmpty) return;
    final generation = _generation, read = ++_reads;
    bool stale() => _disposed || generation != _generation || read != _reads;
    loading = true;
    unreadable = false;
    notifyListeners();
    try {
      final result = await repository.read(profile);
      if (stale()) return;
      _confirmed = settings = result;
    } on MemoryFailure {
      if (stale()) return;
      _confirmed = settings = null;
      unreadable = true;
    } finally {
      if (!stale()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadProvider() async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null || profile.isEmpty) return;
    final generation = _generation;
    providerFailed = false;
    try {
      final read = await repository.status(profile);
      if (_disposed || generation != _generation) return;
      provider = read;
    } on MemoryFailure {
      if (_disposed || generation != _generation) return;
      provider = null;
      providerFailed = true;
    }
    notifyListeners();
  }

  /// Deletes the memory files [target] names and reads everything again. A
  /// lost answer is not retried: the reset may have happened, so the reads
  /// show what is there now.
  Future<void> reset(MemoryResetTarget target) async {
    final repository = _repository, profile = _profile;
    if (repository == null || profile == null || profile.isEmpty || resetting) {
      return;
    }
    final generation = _generation;
    breadcrumbs('memory.reset_confirmed', {'target': target.wire});
    resetting = true;
    notice = null;
    notifyListeners();
    var reread = true;
    try {
      await repository.reset(profile, target);
      notice = MemoryNotice(
        'Reset ${target.what}. New chats start without it.',
        MemoryNoticeTone.success,
      );
    } on MemoryWriteFailure catch (failure) {
      reread = failure.uncertain;
      notice = MemoryNotice(
        failure.uncertain
            ? 'The reset may have happened. Reading memory again.'
            : failure.message,
        failure.uncertain ? MemoryNoticeTone.warning : MemoryNoticeTone.error,
      );
    }
    if (_disposed || generation != _generation) return;
    resetting = false;
    notifyListeners();
    if (!reread) return;
    await Future.wait([load(), loadProvider(), ?onReset?.call()]);
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
