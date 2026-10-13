import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';

import 'change_signal.dart';

class ChangeInvalidationScope {
  const ChangeInvalidationScope({
    required this.connection,
    required this.server,
    required this.account,
    required this.profile,
  });
  final Object connection, server, account;
  final String? profile;
  @override
  bool operator ==(Object other) =>
      other is ChangeInvalidationScope &&
      identical(connection, other.connection) &&
      server == other.server &&
      account == other.account &&
      profile == other.profile;
  @override
  int get hashCode =>
      Object.hash(identityHashCode(connection), server, account, profile);
}

class ChangeInvalidationController extends ChangeNotifier {
  ChangeInvalidationController({
    this.activity,
    this.events = noopAppEventLogger,
    this.scopeIsCurrent,
  }) {
    activity?.addListener(_activityChanged);
  }
  final ValueListenable<bool>? activity;
  final AppEventLogger events;
  final bool Function(ChangeInvalidationScope)? scopeIsCurrent;
  final _entries = {
    for (final resource in InvalidationResource.values) resource: _Entry(),
  };
  ChangeInvalidationScope? _scope;
  bool _disposed = false;

  bool dirty(InvalidationResource resource) => _entries[resource]!.dirty;
  bool loading(InvalidationResource resource) => _entries[resource]!.loading;
  bool failed(InvalidationResource resource) => _entries[resource]!.failed;

  /// Retires prior reads and hints when the authenticated connection scope changes.
  void bind(ChangeInvalidationScope? scope) {
    if (_disposed || _scope == scope) return;
    _scope = scope;
    for (final entry in _entries.values) {
      entry.retire();
      entry.dirty = false;
      entry.failed = false;
    }
    notifyListeners();
  }

  /// Registers a pure repository read and a synchronous read-model update.
  /// [readSnapshot] must not mutate screen/controller state; [applySnapshot]
  /// runs only while this scope and activity period still own the result.
  /// Keep drafts, filters, selection and pending local mutations in their owners.
  /// Pairing destinations must be active only while a known pairing needs status.
  /// The returned callback unregisters this registration and retires its reads.
  VoidCallback register<T>(
    InvalidationResource resource, {
    required Future<T> Function(ChangeInvalidationScope) readSnapshot,
    required void Function(T) applySnapshot,
    void Function(Object)? onFailure,
    bool Function(T)? snapshotIsCurrent,
    bool active = false,
  }) {
    if (_disposed) throw StateError('Invalidation controller disposed');
    final entry = _entries[resource]!;
    entry.retire();
    final reader = _Reader<T>(
      readSnapshot,
      applySnapshot,
      onFailure,
      snapshotIsCurrent,
    );
    entry.reader = reader;
    entry.active = active;
    _schedule(entry);
    return () {
      if (_disposed || !identical(entry.reader, reader)) return;
      entry.retire();
      entry.reader = null;
      entry.active = false;
      notifyListeners();
    };
  }

  void setActive(InvalidationResource resource, bool active) {
    if (_disposed) return;
    final entry = _entries[resource]!;
    if (entry.active == active) return;
    entry.retire();
    entry.active = active;
    _schedule(entry);
    notifyListeners();
  }

  /// Defers reads and application while a local mutation needs its current model.
  void setBlocked(InvalidationResource resource, bool blocked) {
    if (_disposed) return;
    final entry = _entries[resource]!;
    if (entry.blocked == blocked) return;
    entry.retire();
    entry.blocked = blocked;
    _schedule(entry);
    notifyListeners();
  }

  void invalidate(
    ChangeSignal signal, {
    required ChangeInvalidationScope scope,
  }) {
    if (_disposed || scope != _scope) {
      _log('stale');
      return;
    }
    final entry = _entries[signal.resource]!;
    entry.dirty = true;
    entry.failed = false;
    _log('dirty');
    _schedule(entry);
    notifyListeners();
  }

  /// Retries retained dirty data through the same visibility and activity gates.
  void retry(InvalidationResource resource) {
    if (_disposed) return;
    final entry = _entries[resource]!;
    entry.failed = false;
    _schedule(entry);
  }

  void _activityChanged() {
    if (_disposed) return;
    // Every notification retires work, including a false value hidden by reentry.
    for (final entry in _entries.values) {
      entry.retire();
      _schedule(entry);
    }
    notifyListeners();
  }

  bool _eligible(_Entry entry, ChangeInvalidationScope scope, int epoch) =>
      !_disposed &&
      _scope == scope &&
      (scopeIsCurrent?.call(scope) ?? true) &&
      (activity?.value ?? true) &&
      entry.epoch == epoch &&
      entry.active &&
      !entry.blocked &&
      entry.reader != null;

  void _schedule(_Entry entry) {
    final scope = _scope, epoch = entry.epoch;
    if (scope == null ||
        !entry.dirty ||
        entry.loading ||
        entry.scheduled ||
        !_eligible(entry, scope, epoch)) {
      return;
    }
    entry.scheduled = true;
    unawaited(Future<void>.microtask(() => _refresh(entry, scope, epoch)));
  }

  Future<void> _refresh(
    _Entry entry,
    ChangeInvalidationScope scope,
    int epoch,
  ) async {
    if (!_eligible(entry, scope, epoch)) return;
    entry.scheduled = false;
    entry.dirty = false;
    entry.loading = true;
    entry.failed = false;
    final reader = entry.reader!;
    notifyListeners();
    if (!_eligible(entry, scope, epoch)) return;
    var applied = false, followUp = false;
    try {
      final snapshot = await reader.read(scope);
      if (!_eligible(entry, scope, epoch)) {
        _log('stale');
        return;
      }
      if (!reader.current(snapshot)) {
        followUp = entry.dirty;
        entry.dirty = true;
        _log('stale');
        return;
      }
      if (!_eligible(entry, scope, epoch)) return;
      reader.apply(snapshot);
      applied = true;
      _log('applied');
    } on Object catch (error) {
      if (!_eligible(entry, scope, epoch)) {
        _log('stale');
        return;
      }
      followUp = entry.dirty;
      entry.dirty = true;
      entry.failed = true;
      _log('failed');
      if (!_eligible(entry, scope, epoch)) return;
      try {
        reader.failure?.call(error);
      } on Object {
        return;
      }
    } finally {
      if (entry.epoch == epoch && !_disposed) {
        entry.loading = false;
        if (applied || followUp) _schedule(entry);
        notifyListeners();
      }
    }
  }

  void _log(String outcome) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'change_invalidation',
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    activity?.removeListener(_activityChanged);
    for (final entry in _entries.values) {
      entry.retire();
      entry.reader = null;
    }
    super.dispose();
  }
}

class _Entry {
  bool dirty = false,
      loading = false,
      failed = false,
      active = false,
      blocked = false,
      scheduled = false;
  int epoch = 0;
  _ReadModel? reader;
  void retire() {
    epoch++;
    dirty = dirty || loading;
    loading = false;
    scheduled = false;
  }
}

abstract interface class _ReadModel {
  Future<Object?> read(ChangeInvalidationScope scope);
  void apply(Object? snapshot);
  bool current(Object? snapshot);
  void Function(Object)? get failure;
}

class _Reader<T> implements _ReadModel {
  _Reader(
    this.readSnapshot,
    this.applySnapshot,
    this.failure,
    this.snapshotIsCurrent,
  );
  final Future<T> Function(ChangeInvalidationScope) readSnapshot;
  final void Function(T) applySnapshot;
  final bool Function(T)? snapshotIsCurrent;
  @override
  final void Function(Object)? failure;
  @override
  Future<Object?> read(ChangeInvalidationScope scope) async =>
      await readSnapshot(scope);
  @override
  void apply(Object? snapshot) => applySnapshot(snapshot as T);
  @override
  bool current(Object? snapshot) =>
      snapshotIsCurrent?.call(snapshot as T) ?? true;
}
