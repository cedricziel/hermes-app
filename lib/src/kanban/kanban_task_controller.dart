import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../chat/media/media_source.dart';
import '../chat/media/media_store.dart';
import '../chat/media/quick_look.dart';
import '../chat/media/quick_look_telemetry.dart';
import '../core/safe_notifier.dart';
import '../models/model_provider_option.dart';
import 'kanban_files.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';

/// The state of one task's detail panel: the loaded task, its home channels
/// and estimate, and the writes made to it.
///
/// A write throws what the server refused and leaves the state alone; one
/// that went through drops the estimate, reports the change through
/// [onChanged] and reloads the task.
class KanbanTaskController extends ChangeNotifier with SafeNotifier {
  KanbanTaskController({
    required this.repository,
    required this.taskId,
    this.files = const PlatformKanbanFiles(),
    this.board,
    this.onChanged,
    this.media,
    this.telemetry = const QuickLookTelemetry(),
  });

  final KanbanRepository repository;
  final String taskId;
  final String? board;

  /// The file dialogs used to attach and save attachments.
  final KanbanFiles files;

  /// Called after every change that went through, so the board can refresh.
  final VoidCallback? onChanged;

  /// The cache attachments are staged in to be previewed or opened. Without
  /// it an attachment can only be saved.
  final MediaStore? media;

  /// Where a preview reports that it opened or failed.
  final QuickLookTelemetry telemetry;

  KanbanTaskDetail? _detail;
  bool _failed = false;
  bool _transferring = false;
  KanbanEstimate? _estimate;
  bool _estimating = false;
  List<KanbanHomeChannel> _channels = const [];
  final _switching = <String>{};
  int _loadGeneration = 0;
  Future<ModelOptions>? _modelOptions;

  KanbanTaskDetail? get detail => _detail;

  /// The first load failed, so there is nothing to show.
  bool get failed => _failed;

  /// An attachment is being picked, uploaded or saved.
  bool get transferring => _transferring;
  KanbanEstimate? get estimate => _estimate;
  bool get estimating => _estimating;
  List<KanbanHomeChannel> get channels => _channels;

  /// The platforms whose subscription is being changed.
  Set<String> get switching => Set.unmodifiable(_switching);

  Future<void> start() => Future.wait([load(), loadChannels()]);

  /// Loads the task. Only the newest load counts: an older one that answers
  /// late is dropped. A failed reload keeps the task on screen.
  Future<void> load() async {
    final generation = ++_loadGeneration;
    try {
      final detail = await repository.loadTask(taskId, board: board);
      if (disposed || generation != _loadGeneration) return;
      _detail = detail;
      _failed = false;
      notifyListeners();
      unawaited(loadChannels());
    } on Object catch (_) {
      if (!disposed && generation == _loadGeneration && _detail == null) {
        _failed = true;
        notifyListeners();
      }
    }
  }

  Future<void> retry() {
    _failed = false;
    notifyListeners();
    return load();
  }

  /// The home channels are an extra: a server without any, or one that
  /// refuses, simply shows no Notify section.
  Future<void> loadChannels() async {
    try {
      final channels = await repository.loadHomeChannels(taskId, board: board);
      if (disposed) return;
      _channels = channels;
      notifyListeners();
    } on Object catch (_) {}
  }

  Future<void> setChannel(KanbanHomeChannel channel, bool on) async {
    if (!_switching.add(channel.platform)) return;
    notifyListeners();
    try {
      await repository.setHomeSubscription(
        taskId,
        channel.platform,
        subscribed: on,
        board: board,
      );
      _channels = [
        for (final c in _channels)
          c.platform == channel.platform ? c.withSubscribed(on) : c,
      ];
    } finally {
      _switching.remove(channel.platform);
      notifyListeners();
    }
  }

  Future<void> estimateTask() async {
    _estimating = true;
    notifyListeners();
    try {
      _estimate = await repository.estimateTask(taskId, board: board);
    } finally {
      _estimating = false;
      notifyListeners();
    }
  }

  Future<void> _write(
    Future<void> Function() action, {
    bool reload = true,
  }) async {
    await action();
    // The task changed, so an estimate of it no longer holds.
    _estimate = null;
    notifyListeners();
    onChanged?.call();
    if (reload) await load();
  }

  Future<void> update({
    String? status,
    String? blockReason,
    String? result,
    String? title,
    String? body,
    String? assignee,
    int? priority,
  }) => _write(
    () => repository.updateTask(
      taskId,
      status: status,
      blockReason: blockReason,
      result: result,
      title: title,
      body: body,
      assignee: assignee,
      priority: priority,
      board: board,
    ),
  );

  /// Moves the task, with the optional reason for blocking it or result of
  /// completing it.
  Future<void> moveTo(String status, {String? reason, String? result}) =>
      update(
        status: status,
        blockReason: reason == null || reason.isEmpty ? null : reason,
        result: result == null || result.isEmpty ? null : result,
      );

  Future<KanbanTriageOutcome> decompose() =>
      _triage(() => repository.decomposeTask(taskId, board: board));

  Future<KanbanTriageOutcome> specify() =>
      _triage(() => repository.specifyTask(taskId, board: board));

  Future<KanbanTriageOutcome> _triage(
    Future<KanbanTriageOutcome> Function() run,
  ) async {
    final outcome = await run();
    if (outcome.ok) {
      onChanged?.call();
      await load();
    }
    return outcome;
  }

  Future<void> terminateRun(KanbanRun run) =>
      _write(() => repository.terminateRun(run.id, board: board));

  Future<void> reclaim() =>
      _write(() => repository.reclaimTask(taskId, board: board));

  Future<void> addParent(String id) =>
      _write(() => repository.addLink(id, taskId, board: board));

  Future<void> removeParent(String id) =>
      _write(() => repository.removeLink(id, taskId, board: board));

  Future<void> addComment(String text) =>
      _write(() => repository.addComment(taskId, text, board: board));

  Future<void> archive() =>
      _write(() => repository.archiveTask(taskId, board: board), reload: false);

  Future<void> delete() =>
      _write(() => repository.deleteTask(taskId, board: board), reload: false);

  /// The models the task can be moved to, loaded once per panel.
  Future<ModelOptions> modelOptions() =>
      _modelOptions ??= repository.loadModelOptions();

  /// Moves the task to [choice], or back to its profile's model and effort
  /// when null. Sends nothing when that is what the task already runs on. A
  /// choice without an effort leaves the task's effort as it is.
  Future<void> setModel(ModelChoice? choice) async {
    final task = _detail?.task;
    if (task == null) return;
    if (choice == null) {
      if (task.modelOverride == null && task.reasoningEffort == null) return;
      return _write(
        () => repository.updateTask(
          taskId,
          clearModel: true,
          clearEffort: true,
          board: board,
        ),
      );
    }
    if (choice.modelId == task.modelOverride &&
        choice.providerId == task.providerOverride &&
        (choice.effort == null || choice.effort == task.reasoningEffort)) {
      return;
    }
    return _write(
      () => repository.updateTask(taskId, model: choice, board: board),
    );
  }

  /// Moves the task to a model typed by hand; an empty name clears it.
  Future<void> setModelName(String name) {
    if (name == (_detail?.task.modelOverride ?? '')) return Future.value();
    return _write(
      () => name.isEmpty
          ? repository.updateTask(taskId, clearModel: true, board: board)
          : repository.updateTask(taskId, modelName: name, board: board),
    );
  }

  /// The names a task can be assigned to; none when the server will not say.
  Future<List<String>> loadAssignees() async {
    try {
      return await repository.loadAssignees(board: board);
    } on Object catch (_) {
      return const [];
    }
  }

  Future<void> removeAttachment(KanbanAttachment a) =>
      _write(() => repository.removeAttachment(a.id, board: board));

  /// Picks a file and uploads it. Does nothing while a transfer runs or when
  /// no file was picked.
  Future<void> attach() async {
    if (_transferring) return;
    _setTransferring(true);
    try {
      final file = await files.pick();
      if (file == null || disposed) return;
      await _write(
        () => repository.uploadAttachment(
          taskId,
          file.name,
          file.bytes,
          board: board,
        ),
      );
    } finally {
      _setTransferring(false);
    }
  }

  /// The bytes of an attachment, for a drag out of the app. Unlike
  /// [download] it does not mark the task as transferring: a drop is the
  /// receiver's wait, and the panel stays usable meanwhile.
  Future<Uint8List> readAttachment(KanbanAttachment a) =>
      repository.downloadAttachment(a.id, board: board);

  /// Whether an attachment can be previewed or opened: there is a cache to
  /// put it in.
  bool get canOpenAttachments => media != null;

  /// Downloads [a] into the media cache once, and from then on reuses it.
  Future<File> _stageAttachment(MediaStore store, KanbanAttachment a) =>
      store.stage(
        'kanban:${board ?? ''}:${a.id}',
        a.filename,
        () => repository.downloadAttachment(a.id, board: board),
      );

  /// Shows [a] in the Quick Look panel, downloading it first. With [toggle]
  /// the panel closes instead when it already shows the file. Returns whether
  /// the panel shows the file afterwards. Does nothing while a transfer runs.
  /// Throws [KanbanException] when the file could not be fetched or shown.
  Future<bool> preview(
    KanbanAttachment a, {
    required QuickLookTrigger trigger,
    bool toggle = false,
  }) async {
    final store = media;
    if (store == null || _transferring) return false;
    _setTransferring(true);
    try {
      final File file;
      try {
        file = await _stageAttachment(store, a);
      } on Object catch (e) {
        telemetry.failed(
          QuickLookSource.kanban,
          trigger,
          stage: QuickLookStage.download,
          reason: e is MediaFetchException ? e.reason.name : 'failed',
        );
        if (e is KanbanException) rethrow;
        throw const KanbanException('Could not download the attachment.');
      }
      if (disposed) return false;
      switch (await store.showQuickLook(file, toggle: toggle)) {
        case QuickLookToggle.shown:
          telemetry.opened(QuickLookSource.kanban, trigger);
          return true;
        case QuickLookToggle.closed:
          return false;
        case QuickLookToggle.failed:
          telemetry.failed(
            QuickLookSource.kanban,
            trigger,
            stage: QuickLookStage.native,
            reason: 'unavailable',
          );
          throw const KanbanException("Quick Look couldn't preview this file.");
      }
    } finally {
      _setTransferring(false);
    }
  }

  /// Downloads [a] and hands it to the app the system has for its type.
  /// Does nothing while a transfer runs. Throws [KanbanException] when the
  /// file could not be fetched or no app opens it.
  Future<void> open(KanbanAttachment a) async {
    final store = media;
    if (store == null || _transferring) return;
    _setTransferring(true);
    try {
      final File file;
      try {
        file = await _stageAttachment(store, a);
      } on KanbanException {
        rethrow;
      } on Object {
        throw const KanbanException('Could not download the attachment.');
      }
      if (disposed) return;
      if (!await store.open(file)) {
        throw const KanbanException('No app can open this file.');
      }
    } finally {
      _setTransferring(false);
    }
  }

  /// Saves an attachment to the device; whether it was saved.
  Future<bool> download(KanbanAttachment a) async {
    _setTransferring(true);
    try {
      final bytes = await readAttachment(a);
      return await files.save(a.filename, bytes);
    } finally {
      _setTransferring(false);
    }
  }

  void _setTransferring(bool value) {
    _transferring = value;
    notifyListeners();
  }
}
