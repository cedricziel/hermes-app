import 'dart:async';

import 'package:flutter/foundation.dart';

import '../telemetry/breadcrumbs.dart';
import 'memory_repository.dart';

enum MemoryMutation { idle, pending, conflict, failed, uncertain }

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
  bool editing = false;
  String? draft;
  String? mutationMessage;
  MemoryMutation mutation = MemoryMutation.idle;
  bool get dirty => editing && draft != detail?.content;
  bool get needsLeaveConfirmation =>
      dirty ||
      mutation == MemoryMutation.pending ||
      mutation == MemoryMutation.uncertain;
  bool get canSave =>
      editing &&
      dirty &&
      draft?.trim().isNotEmpty == true &&
      (mutation == MemoryMutation.idle || mutation == MemoryMutation.failed);

  void _clearEditor() {
    editing = false;
    draft = null;
    mutationMessage = null;
    mutation = MemoryMutation.idle;
  }

  void beginEdit() {
    if (detail == null ||
        (mutation != MemoryMutation.idle &&
            mutation != MemoryMutation.failed)) {
      return;
    }
    mutation = MemoryMutation.idle;
    mutationMessage = null;
    editing = true;
    draft = detail!.content;
    breadcrumbs('memory.edit.open');
    notifyListeners();
  }

  void setDraft(String value) {
    if (!editing || mutation == MemoryMutation.pending) return;
    draft = value;
    notifyListeners();
  }

  void discardEdit() {
    if (mutation == MemoryMutation.uncertain ||
        mutation == MemoryMutation.conflict) {
      showList();
      unawaited(load());
      return;
    }
    _clearEditor();
    notifyListeners();
  }

  Future<void> mutate({required bool delete}) async {
    final repository = _repository, scope = profile, original = detail;
    if (repository == null ||
        scope == null ||
        original == null ||
        loading ||
        mutation == MemoryMutation.pending ||
        mutation == MemoryMutation.uncertain ||
        mutation == MemoryMutation.conflict ||
        (!delete && !canSave)) {
      return;
    }
    final content = draft;
    final generation = ++_generation;
    mutation = MemoryMutation.pending;
    mutationMessage = null;
    notifyListeners();
    if (_disposed || generation != _generation) return;
    try {
      final current = await repository.detail(original.entry.id, scope);
      if (_disposed || generation != _generation) return;
      if (current.content != original.content) {
        mutation = MemoryMutation.conflict;
        mutationMessage = 'This memory changed. Keep your draft or discard it and refresh before trying again.';
        return;
      }
      if (delete) breadcrumbs('memory.delete.confirm');
      await repository.mutate(
        original.entry.id,
        scope,
        content: delete ? null : content,
      );
      if (_disposed || generation != _generation) return;
      _clearEditor();
      await load();
    } on MemoryWriteFailure catch (error) {
      if (!_disposed && generation == _generation) {
        mutation = error.uncertain
            ? MemoryMutation.uncertain
            : MemoryMutation.failed;
        mutationMessage = error.message;
        if (error.uncertain) await reconcile();
      }
    } on MemoryFailure catch (error) {
      if (!_disposed && generation == _generation) {
        mutation =
            error == MemoryFailure.missing || error == MemoryFailure.malformed
            ? MemoryMutation.conflict
            : MemoryMutation.failed;
        mutationMessage = error.message;
      }
    } finally {
      if (!_disposed && generation == _generation) notifyListeners();
    }
  }

  Future<void> reconcile() async {
    final repository = _repository, scope = profile, original = detail;
    if (repository == null ||
        scope == null ||
        original == null ||
        mutation != MemoryMutation.uncertain) {
      return;
    }
    final generation = ++_generation;
    loading = true;
    notifyListeners();
    if (_disposed || generation != _generation) return;
    try {
      final refreshed = await repository.load(scope);
      if (_disposed || generation != _generation) return;
      entries = refreshed;
      await repository.detail(original.entry.id, scope);
      if (!_disposed && generation == _generation) {
        mutationMessage = 'Current memories loaded. The previous change remains unconfirmed. Discard this draft and select a memory again before another change.';
      }
    } on MemoryFailure catch (error) {
      if (!_disposed && generation == _generation) {
        mutationMessage = error == MemoryFailure.missing
            ? 'The old entry is no longer present. The previous change remains unconfirmed. Select a memory again before another change.'
            : 'The previous change remains unconfirmed. Refresh the list and select a memory again before another change.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  int _generation = 0;
  bool _disposed = false;

  void bind(MemoryRepository? repository, String? nextProfile) {
    if (identical(_repository, repository) && profile == nextProfile) return;
    _generation++;
    _clearEditor();
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
    _clearEditor();
    selected = null;
    detail = null;
    breadcrumbs('memory.open', {'kind': 'list'});
    await _run(() => repository.load(scope), (value) => entries = value);
  }

  Future<void> open(MemoryEntry entry) async {
    final repository = _repository, scope = profile;
    if (repository == null || scope == null || scope.isEmpty) return;
    _clearEditor();
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
    _clearEditor();
    selected = null;
    detail = null;
    failure = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearEditor();
    _generation++;
    entries = const [];
    selected = null;
    detail = null;
    super.dispose();
  }
}
