import 'dart:async';

import 'package:flutter/foundation.dart';

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

  String? _profile;
  DateTime? _readAt;
  int _reads = 0;
  bool _disposed = false;

  /// Null before the first read ends, for another profile than the last
  /// asked, and when the read failed.
  int? waiting;

  Future<void> refresh(String? profile) async {
    if (profile == null) return clear();
    final read = ++_reads;
    if (profile != _profile) {
      waiting = null;
      notifyListeners();
    }
    _profile = profile;
    _readAt = _now();
    final snapshot = await _repository.load(profile);
    if (_disposed || read != _reads) return;
    waiting = snapshot.waiting;
    notifyListeners();
  }

  /// Reads again unless [profile] was read within [staleAfter].
  Future<void> refreshIfStale(String? profile) async {
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
