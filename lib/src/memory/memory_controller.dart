import 'dart:async';

import 'package:flutter/foundation.dart';

import '../telemetry/breadcrumbs.dart';
import 'memory_repository.dart';

class MemoryController extends ChangeNotifier {
  MemoryController({this.breadcrumbs = Breadcrumbs.none});
  final Breadcrumbs breadcrumbs;
  MemoryRepository? _repository;
  String? profile;
  List<MemoryEntry> entries = const [];
  MemoryEntry? selected;
  MemoryDetail? detail;
  MemoryFailure? failure;
  bool loading = false;

  int _generation = 0;
  bool _disposed = false;

  void bind(MemoryRepository? repository, String? nextProfile) {
    if (identical(_repository, repository) && profile == nextProfile) return;
    _generation++;
    _repository = repository;
    profile = nextProfile;
    entries = const [];
    selected = null;
    detail = null;
    failure = null;
    loading = false;
    notifyListeners();
    if (repository != null && nextProfile != null && nextProfile.isNotEmpty) {
      unawaited(load());
    }
  }

  Future<void> load() async {
    final repository = _repository, scope = profile;
    if (repository == null || scope == null || scope.isEmpty) return;
    selected = null;
    detail = null;
    breadcrumbs('memory.open', {'kind': 'list'});
    await _run(() => repository.load(scope), (value) => entries = value);
  }

  Future<void> open(MemoryEntry entry) async {
    final repository = _repository, scope = profile;
    if (repository == null || scope == null || scope.isEmpty) return;
    selected = entry;
    detail = null;
    breadcrumbs('memory.open', {'kind': 'detail'});
    await _run(
      () => repository.detail(entry.id, scope),
      (value) => detail = value,
    );
  }

  Future<void> _run<T>(
    Future<T> Function() read,
    void Function(T) apply,
  ) async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    if (_disposed || generation != _generation) return;
    try {
      final result = await read();
      if (!_disposed && generation == _generation) apply(result);
    } on MemoryFailure catch (error) {
      if (!_disposed && generation == _generation) failure = error;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void showList() {
    _generation++;
    selected = null;
    detail = null;
    failure = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    entries = const [];
    selected = null;
    detail = null;
    super.dispose();
  }
}
