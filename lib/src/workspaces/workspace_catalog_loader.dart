import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hermes_workspaces_repository.dart';
import 'workspace_models.dart';
import 'workspace_paths.dart';

/// Where the read of a profile's projects and folders stands.
enum WorkspaceCatalogStatus {
  /// Nothing asked yet.
  idle,

  /// A read is out. See [WorkspaceCatalogLoader.stalled] for one that has
  /// gone unanswered for too long.
  loading,
  ready,

  /// The server answered with an error, or something that does not fit.
  failed,

  /// The server has no such route (an older Hermes).
  unsupported,

  /// No answer: the device or the server cannot be reached.
  offline,

  /// The profile does not exist on the server.
  unknownProfile,
}

/// The projects and git roots of one profile, read through
/// [HermesWorkspacesRepository] for the row above a new chat's composer (its
/// default folder and project tag) and for the picker.
///
/// One loader serves one recipient profile. It never asks again by itself:
/// [load] and [reload] are the only requests. A read that has gone unanswered
/// for [slowAfter] is [stalled], but it stays loading and its answer, when it
/// comes, still applies. A re-read keeps the earlier catalog while it runs.
/// Nothing is stored on the device.
class WorkspaceCatalogLoader extends ChangeNotifier {
  WorkspaceCatalogLoader({
    required this._repository,
    required this.profile,
    this.slowAfter = kWorkspaceRpcTimeout,
  });

  final HermesWorkspacesRepository _repository;

  /// The profile every read names.
  final String profile;

  /// How long a read may go unanswered before [stalled] says so.
  final Duration slowAfter;

  WorkspaceCatalogStatus _status = WorkspaceCatalogStatus.idle;
  WorkspaceCatalog? _catalog;
  bool _stalled = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _timer;

  WorkspaceCatalogStatus get status => _status;

  /// The latest catalog that was read. Kept, as stale, while a re-read runs
  /// or after one failed.
  WorkspaceCatalog? get catalog => _catalog;

  /// Whether a read has had no answer for [slowAfter].
  bool get stalled => _stalled;

  bool get loading => _status == WorkspaceCatalogStatus.loading;

  /// The folder a chat of the profile runs in when none is picked, when the
  /// server has said.
  String? get defaultFolder => _catalog?.defaultCwd;

  /// The project that holds [path], by the server's own rule, or null when
  /// none does or the projects could not be read.
  WorkspaceProject? projectFor(String path) {
    final catalog = _catalog;
    return catalog == null
        ? null
        : WorkspaceProjects.projectFor(path, catalog.projects);
  }

  /// Reads the catalog once: does nothing when a read is out or has answered.
  /// A failed or unsupported one is read again only by [reload].
  Future<void> load() {
    if (_status != WorkspaceCatalogStatus.idle) return Future.value();
    return reload();
  }

  /// Reads the catalog again, with [scan] asking the server to look for
  /// folders first. A read already out is replaced: its answer is dropped.
  Future<void> reload({bool scan = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _timer?.cancel();
    _stalled = false;
    _status = WorkspaceCatalogStatus.loading;
    _timer = Timer(slowAfter, () {
      if (_disposed || generation != _generation) return;
      _stalled = true;
      notifyListeners();
    });
    notifyListeners();
    final result = await _repository.catalog(profile: profile, scan: scan);
    // A late answer is the answer of the latest read; one that a newer read
    // replaced is not.
    if (_disposed || generation != _generation) return;
    _timer?.cancel();
    _stalled = false;
    switch (result) {
      case WorkspacesOk(:final value):
        _catalog = value;
        _status = WorkspaceCatalogStatus.ready;
      case WorkspacesUnsupported():
        _catalog = null;
        _status = WorkspaceCatalogStatus.unsupported;
      case WorkspacesFailed(:final kind):
        _status = switch (kind) {
          WorkspacesFailure.unreachable => WorkspaceCatalogStatus.offline,
          WorkspacesFailure.unknownProfile =>
            WorkspaceCatalogStatus.unknownProfile,
          _ => WorkspaceCatalogStatus.failed,
        };
        if (kind == WorkspacesFailure.unknownProfile) _catalog = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
