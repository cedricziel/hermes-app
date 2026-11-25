import 'dart:async';

import 'package:flutter/foundation.dart';

import '../profiles/profile_resolver.dart';
import 'memory_proposals_repository.dart';

/// "Memory · 2 waiting" when changes wait, plain "Memory" otherwise.
String memoryEntryLabel(int? waiting) =>
    waiting != null && waiting > 0 ? 'Memory · $waiting waiting' : 'Memory';

/// How many changes wait in one profile, for the Memory entries of the
/// sidebar and the Profiles page. A read that fails leaves no count, and the
/// answer of an earlier profile never replaces a later one.
class MemoryWaitingCount extends ChangeNotifier {
  MemoryWaitingCount(
    this._repository, {
    this.staleAfter = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MemoryProposalsRepository _repository;
  final Duration staleAfter;
  final DateTime Function() _now;

  ResolvedProfile? _profile;
  DateTime? _readAt;
  int _reads = 0;
  Future<void>? _reading;
  bool _disposed = false;

  /// Null before the first read ends, for another profile than the last
  /// asked, and when the read failed.
  int? waiting;

  /// Reads the count. A trigger that comes while a read of the same profile is
  /// still out (the chat list finishing, the launch profile arriving and a
  /// resume often land together) joins it, so one moment asks Hermes once.
  /// With [supersede] it never joins: a read already out began before what the
  /// caller wants to see (the user's decisions in Memory), and its answer is
  /// dropped.
  Future<void> refresh(ResolvedProfile? profile, {bool supersede = false}) {
    if (profile == null) {
      clear();
      return Future.value();
    }
    if (profile == _profile && !supersede) {
      final reading = _reading;
      if (reading != null) return reading;
    }
    final read = ++_reads;
    if (profile != _profile) {
      waiting = null;
      notifyListeners();
    }
    _profile = profile;
    _readAt = _now();
    return _reading = _read(profile, read).whenComplete(() {
      if (read == _reads) _reading = null;
    });
  }

  Future<void> _read(ResolvedProfile profile, int read) async {
    final snapshot = await _repository.load(profile);
    if (_disposed || read != _reads) return;
    waiting = snapshot.waiting;
    notifyListeners();
  }

  /// Reads again unless [profile] was read within [staleAfter].
  Future<void> refreshIfStale(ResolvedProfile? profile) async {
    final readAt = _readAt;
    if (profile == _profile &&
        readAt != null &&
        _now().difference(readAt) < staleAfter) {
      return;
    }
    await refresh(profile);
  }

  void clear() {
    _reads++;
    _reading = null;
    _profile = null;
    _readAt = null;
    if (waiting == null) return;
    waiting = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
