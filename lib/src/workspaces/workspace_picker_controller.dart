import 'dart:async';

import 'package:flutter/foundation.dart';

import '../files/server_path.dart';
import 'folder_labels.dart';
import 'hermes_workspaces_repository.dart';
import 'widgets/folder_browser_view.dart' show FolderBrowserLevel;
import 'widgets/path_entry_view.dart'
    show PathEntryCheck, PathEntrySuggestion, PathEntryView;
import 'widgets/workspace_picker_view.dart'
    show
        WorkspacePickerRow,
        WorkspacePickerScanOutcome,
        kWorkspacePickerSearchThreshold;
import 'workspace_catalog_loader.dart';
import 'workspace_models.dart';
import 'workspace_paths.dart';
import 'workspace_telemetry.dart';

/// Where the picker's list stands.
enum WorkspacePickerStatus {
  /// The projects are being read and have not been for long.
  loading,

  /// The projects were read.
  ready,

  /// The projects could not be read (or took longer than 10 s) but folders
  /// can still be browsed and typed.
  partial,

  /// The projects could not be read and the server does not let the app
  /// browse either: only a typed path is left.
  failed,

  /// The server has no workspaces route (an older Hermes): no projects, and
  /// no error.
  unsupported,

  /// The server cannot be reached: Browse and Type are disabled.
  offline,

  /// The profile no longer exists on the server.
  unknownProfile,
}

/// Whether Browse is offered.
enum WorkspaceBrowseAccess {
  /// Not yet known: the probe has not answered. Browse is offered.
  unknown,
  available,

  /// The server only lets the app browse its own folders
  /// (`HERMES_DASHBOARD_FILES_ROOT`), or answered a 403 that is not
  /// recognised: Browse is hidden for the visit.
  locked,

  /// The server has no `/api/fs/list` (an older Hermes): Browse is hidden.
  unsupported,
}

/// The folder a picker visit ended with.
class FolderPick {
  const FolderPick({this.path, this.choice});

  /// The server default of a new chat: nothing is sent.
  const FolderPick.serverDefault() : this();

  /// The folder, or null for the server default of a new chat.
  final String? path;

  /// What a new chat's draft keeps; null for the server default.
  final WorkspaceChoice? choice;

  bool get isServerDefault => path == null;
}

/// The state of one visit to the folder picker and its Browse and Type pages.
///
/// A plain [ChangeNotifier] with no screen in it: rows, levels and checks are
/// values a widget draws, and every user-visible text is the widget's. One
/// controller serves one visit. The catalog read belongs to the [loader] the
/// chat keeps for the row above the composer; the picker reads again on open
/// and on Try again and Scan, and waits on nothing longer than [wait].
///
/// Nothing is ever sent again by itself: a wait that ends says so and offers
/// the action again, and an answer that comes later still updates the screen
/// unless the person has moved on. After [close] or [dispose] every answer is
/// dropped. Nothing here is stored on the device, logged or put in a span.
class WorkspacePickerController extends ChangeNotifier {
  WorkspacePickerController({
    required this._repository,
    required this._loader,
    required this.profile,
    this.current,
    this.picked,
    this.wait = kWorkspaceRpcTimeout,
    this.debounce = const Duration(milliseconds: 250),
    this.telemetry = WorkspaceTelemetry.none,
  }) {
    _loader.addListener(_catalogChanged);
    _lastRepos = _repoRoots(_loader.catalog);
    telemetry.pickerOpened(move: isMove);
    _openCatalog();
    _startProbe();
  }

  final HermesWorkspacesRepository _repository;
  final WorkspaceCatalogLoader _loader;

  /// The profile every read names.
  final String profile;

  /// The folder of the chat being moved, null for a new chat.
  final String? current;

  /// The folder already picked for the new chat, to show it chosen.
  final String? picked;

  /// How long any wait may last.
  final Duration wait;

  /// How long typing pauses before the server is asked.
  final Duration debounce;
  final WorkspaceTelemetry telemetry;

  bool _disposed = false;
  bool _closed = false;

  bool get isMove => current != null;

  /// The picker was closed by the host (the profile changed, the app
  /// locked): nothing more is read or applied.
  bool get closed => _closed;

  bool get _dead => _disposed || _closed;

  // -- the list -----------------------------------------------------------

  String _query = '';
  String get query => _query;

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _notify();
  }

  WorkspaceCatalog? get catalog => _loader.catalog;

  WorkspacePickerStatus get status {
    final loader = _loader;
    switch (loader.status) {
      case WorkspaceCatalogStatus.unknownProfile:
        return WorkspacePickerStatus.unknownProfile;
      case WorkspaceCatalogStatus.offline:
        return WorkspacePickerStatus.offline;
      case WorkspaceCatalogStatus.unsupported:
        return WorkspacePickerStatus.unsupported;
      case WorkspaceCatalogStatus.failed:
        return _browseAccess == WorkspaceBrowseAccess.available ||
                _browseAccess == WorkspaceBrowseAccess.unknown
            ? WorkspacePickerStatus.partial
            : WorkspacePickerStatus.failed;
      case WorkspaceCatalogStatus.ready:
        return WorkspacePickerStatus.ready;
      case WorkspaceCatalogStatus.idle:
      case WorkspaceCatalogStatus.loading:
        // A read that is running keeps the list it had.
        if (loader.catalog != null) return WorkspacePickerStatus.ready;
        return _stalled || loader.stalled
            ? WorkspacePickerStatus.partial
            : WorkspacePickerStatus.loading;
    }
  }

  /// No connection: Browse and Type are disabled.
  bool get offline =>
      status == WorkspacePickerStatus.offline || _probeUnreachable;

  bool _stalled = false;
  Timer? _catalogTimer;

  void _openCatalog() {
    switch (_loader.status) {
      case WorkspaceCatalogStatus.loading:
        // The row's own read is out: wait for it, but not past [wait].
        _watchCatalogWait();
      case WorkspaceCatalogStatus.unsupported:
      case WorkspaceCatalogStatus.unknownProfile:
        break;
      case WorkspaceCatalogStatus.idle:
      case WorkspaceCatalogStatus.ready:
      case WorkspaceCatalogStatus.failed:
      case WorkspaceCatalogStatus.offline:
        // Read again on open; what was read stays shown meanwhile.
        _readCatalog();
    }
  }

  void _readCatalog({bool scan = false}) {
    _stalled = false;
    _watchCatalogWait();
    unawaited(_loader.reload(scan: scan));
  }

  void _watchCatalogWait() {
    _catalogTimer?.cancel();
    _catalogTimer = Timer(wait, () {
      if (_dead || !_loader.loading) return;
      _stalled = true;
      _notify();
    });
  }

  /// "Try again" after the projects could not be read.
  void retryCatalog() {
    if (_dead) return;
    _readCatalog();
    _notify();
  }

  void _catalogChanged() {
    if (_dead) return;
    if (!_loader.loading) {
      _catalogTimer?.cancel();
      _stalled = false;
      _startProbe();
    }
    if (_scanning) _scanAnswered();
    _notify();
  }

  /// Server default, then the folders by source, as rows. The server default
  /// is null while the profile's default folder is unknown.
  WorkspacePickerRow? get serverDefault {
    final path = _loader.defaultFolder;
    if (path == null) return null;
    return WorkspacePickerRow(
      id: kPickerDefaultId,
      title: folderLabelFor(path),
      path: path,
      projectName: _loader.projectFor(path)?.name,
      isCurrent: _isCurrent(path, null),
    );
  }

  bool _isCurrent(String path, String? home) {
    final folder = current;
    return folder != null &&
        sameServerFolder(path, folder, home: home ?? catalog?.home);
  }

  /// Every project and recent row of the catalog, before searching.
  _Rows _build() {
    final catalog = this.catalog;
    final projects = <WorkspacePickerRow>[];
    final recent = <WorkspacePickerRow>[];
    if (catalog != null) {
      for (final project in catalog.projects) {
        if (project.archived) continue;
        final folders = [...project.folders]
          ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
        for (var i = 0; i < folders.length; i++) {
          final folder = folders[i];
          projects.add(
            WorkspacePickerRow(
              id: '$kPickerProjectPrefix${project.id}:$i',
              title: project.name,
              label: folders.length > 1
                  ? (folder.label ?? folderLabelFor(folder.path))
                  : null,
              path: folder.path,
              isCurrent: _isCurrent(folder.path, catalog.home),
            ),
          );
        }
      }
      final seen = <String>{};
      final repos = [...catalog.repos]
        ..sort((a, b) => (b.lastActive ?? -1).compareTo(a.lastActive ?? -1));
      for (final repo in repos) {
        // A repo inside a project's folder is already listed under it.
        if (WorkspaceProjects.projectFor(repo.root, catalog.projects) != null) {
          continue;
        }
        if (!seen.add(repo.root)) continue;
        recent.add(
          WorkspacePickerRow(
            id: '$kPickerRecentPrefix${repo.root}',
            title: repo.label ?? folderLabelFor(repo.root),
            path: repo.root,
            chatCount: repo.sessions,
            isNew: _newRoots.contains(repo.root),
            isCurrent: _isCurrent(repo.root, catalog.home),
          ),
        );
      }
    }
    // In a move the chat's own folder is always on the list: at the top of
    // Projects when a project holds it, else at the top of Recent.
    final folder = current;
    final inDefault = serverDefault?.isCurrent ?? false;
    if (folder != null &&
        !inDefault &&
        !projects.any((row) => row.isCurrent) &&
        !recent.any((row) => row.isCurrent)) {
      final project = catalog == null
          ? null
          : WorkspaceProjects.projectFor(folder, catalog.projects);
      final row = WorkspacePickerRow(
        id: kPickerCurrentId,
        title: project?.name ?? folderLabelFor(folder),
        path: folder,
        isCurrent: true,
      );
      (project == null ? recent : projects).insert(0, row);
    }
    return _Rows(projects, recent);
  }

  /// The project rows, after searching.
  List<WorkspacePickerRow> get projects => _filter(_build().projects);

  /// The recent rows, after searching.
  List<WorkspacePickerRow> get recent => _filter(_build().recent);

  /// Whether the list is long enough to search.
  bool get searchable {
    final rows = _build();
    return rows.projects.length + rows.recent.length >
        kWorkspacePickerSearchThreshold;
  }

  List<WorkspacePickerRow> _filter(List<WorkspacePickerRow> rows) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return rows;
    return [
      for (final row in rows)
        if ([
          row.title,
          row.label ?? '',
          row.path,
        ].any((text) => text.toLowerCase().contains(needle)))
          row,
    ];
  }

  /// The row that is shown chosen: the pick made earlier, the chat's folder
  /// in a move, else the server default.
  String get selectedId {
    final target = picked ?? current;
    if (target == null) return kPickerDefaultId;
    final home = catalog?.home;
    final def = _loader.defaultFolder;
    if (def != null && sameServerFolder(def, target, home: home)) {
      return kPickerDefaultId;
    }
    final rows = _build();
    for (final row in [...rows.projects, ...rows.recent]) {
      if (sameServerFolder(row.path, target, home: home)) return row.id;
    }
    // A browsed or typed pick that no list holds: nothing is checked.
    return '';
  }

  /// Takes the row [id]. A new chat's pick becomes a [FolderPick] to keep in
  /// the draft; in a move it is the folder to confirm. Null for an unknown
  /// row, and for the server default while the default is not known in a
  /// move.
  FolderPick? pick(String id) {
    if (_dead) return null;
    if (id == kPickerDefaultId) {
      final path = _loader.defaultFolder;
      if (isMove) {
        if (path == null) return null;
        telemetry.chosen(null);
        return FolderPick(path: path);
      }
      telemetry.chosen(null);
      return const FolderPick.serverDefault();
    }
    final rows = _build();
    final recentRow = rows.recent.where((r) => r.id == id).firstOrNull;
    final projectRow = rows.projects.where((r) => r.id == id).firstOrNull;
    final row = projectRow ?? recentRow;
    if (row == null) return null;
    final source = projectRow != null
        ? WorkspaceChoiceSource.project
        : WorkspaceChoiceSource.recent;
    telemetry.chosen(source);
    return FolderPick(
      path: row.path,
      choice: WorkspaceChoice(
        path: row.path,
        projectName: projectRow?.title,
        source: source,
      ),
    );
  }

  // -- scanning -----------------------------------------------------------

  bool _scanning = false;
  WorkspacePickerScanOutcome? _scanOutcome;
  int _scanFound = 0;
  Set<String> _lastRepos = const {};
  Set<String> _newRoots = const {};
  int _scanRun = 0;
  Timer? _scanTimer;

  /// Whether the server can scan for folders.
  bool get scanAvailable => catalog?.scanEnabled ?? false;
  bool get scanning => _scanning;
  WorkspacePickerScanOutcome? get scanOutcome => _scanOutcome;
  int get scanFound => _scanFound;

  static Set<String> _repoRoots(WorkspaceCatalog? catalog) => {
    for (final repo in catalog?.repos ?? const <WorkspaceRepo>[]) repo.root,
  };

  /// Clears the line that told how the last scan ended; the host does it
  /// when the person goes on.
  void clearScanOutcome() {
    if (_scanOutcome == null) return;
    _scanOutcome = null;
    _notify();
  }

  /// Looks for projects on the server. Reads the folders to scan first and,
  /// when there are none, sends no scan. The wait ends after [wait] with the
  /// list unchanged; an answer after that still applies.
  Future<void> scan() async {
    if (_dead || _scanning || !scanAvailable) return;
    final run = ++_scanRun;
    _scanning = true;
    _scanOutcome = null;
    _scanTimer?.cancel();
    _scanTimer = Timer(wait, () {
      if (_dead || run != _scanRun || !_scanning) return;
      _scanning = false;
      _scanOutcome = WorkspacePickerScanOutcome.tooSlow;
      _notify();
    });
    _notify();
    final roots = await _repository.scanRoots(profile: profile);
    if (_dead || run != _scanRun) return;
    if (roots case WorkspacesOk(:final value) when value.isEmpty) {
      _scanTimer?.cancel();
      _scanning = false;
      _scanOutcome = WorkspacePickerScanOutcome.nothingToScan;
      _notify();
      return;
    }
    if (_scanOutcome == WorkspacePickerScanOutcome.tooSlow) return;
    _lastRepos = _repoRoots(_loader.catalog);
    _stalled = false;
    unawaited(_loader.reload(scan: true));
  }

  /// The scan's catalog arrived (maybe after the wait ended).
  void _scanAnswered() {
    if (_loader.loading) return;
    _scanTimer?.cancel();
    _scanning = false;
    if (_loader.status != WorkspaceCatalogStatus.ready) {
      _scanOutcome = WorkspacePickerScanOutcome.tooSlow;
      return;
    }
    final now = _repoRoots(_loader.catalog);
    _newRoots = now.difference(_lastRepos);
    _scanFound = _newRoots.length;
    _scanOutcome = _scanFound == 0
        ? WorkspacePickerScanOutcome.nothingNew
        : WorkspacePickerScanOutcome.found;
    _lastRepos = now;
  }

  // -- browse access and the probe ----------------------------------------

  WorkspaceBrowseAccess _browseAccess = WorkspaceBrowseAccess.unknown;
  bool _probeUnreachable = false;
  bool _routeKnown = false;
  bool _firstRead = true;

  WorkspaceBrowseAccess get browseAccess => _browseAccess;

  /// Browse is hidden: the server only lets the app browse its own folders,
  /// or has no `/api/fs/list`.
  bool get browseLocked =>
      _browseAccess == WorkspaceBrowseAccess.locked ||
      _browseAccess == WorkspaceBrowseAccess.unsupported;

  /// The one `fs/list` read made when the picker opens. It tells an older
  /// server (the route is missing) from a folder that is missing (the route
  /// answered), and a locked root from a folder Hermes may not read.
  bool _probeStarted = false;
  Timer? _probeTimer;

  /// Starts the probe once the profile's default folder is known, so it asks
  /// about that folder; with no answer from the catalog in [wait] (or none
  /// to come) it asks about `~`.
  void _startProbe() {
    if (_probeStarted || _dead) return;
    if (_loader.defaultFolder == null && current == null && _loader.loading) {
      _probeTimer ??= Timer(wait, _startProbe);
      if (_probeTimer!.isActive) return;
    }
    _probeStarted = true;
    _probeTimer?.cancel();
    unawaited(_probe());
  }

  Future<void> _probe() async {
    final path = _loader.defaultFolder ?? current ?? '~';
    final result = await _repository.listFolders(path, profile: profile);
    if (_dead) return;
    _firstRead = false;
    switch (result) {
      case WorkspacesOk():
        _routeKnown = true;
        _browseAccess = WorkspaceBrowseAccess.available;
      case WorkspacesUnsupported():
        _browseAccess = WorkspaceBrowseAccess.unsupported;
      case WorkspacesFailed(:final kind):
        switch (kind) {
          case WorkspacesFailure.outsideBoundary:
            _routeKnown = true;
            _browseAccess = WorkspaceBrowseAccess.locked;
          case WorkspacesFailure.unreachable:
            _probeUnreachable = true;
          case WorkspacesFailure.unknownProfile:
            break;
          default:
            // The route answered: the folder is missing or unreadable, not
            // the whole server.
            _routeKnown = true;
            _browseAccess = WorkspaceBrowseAccess.available;
        }
    }
    _notify();
  }

  // -- browsing -----------------------------------------------------------

  ServerPath? _browsePath;
  FolderBrowserLevel _level = FolderBrowserLevel.opening;
  List<FolderEntry> _folders = const [];
  int _browseRun = 0;
  Timer? _browseTimer;

  /// The folder Browse shows; null before it was opened.
  ServerPath? get browsePath => _browsePath;
  FolderBrowserLevel get browseLevel => _level;
  List<FolderEntry> get browseFolders => _folders;

  /// Opens Browse: at the folder the chat is in (its parent in a move), else
  /// the server default, else the root.
  void startBrowse() {
    if (_dead) return;
    final start = isMove
        ? (ServerPath.tryParse(current!)?.parent ??
              ServerPath.tryParse(current!))
        : ServerPath.tryParse(_loader.defaultFolder ?? '');
    _open(start ?? ServerPath.tryParse('/')!);
  }

  void openFolder(ServerPath path) => _open(path);

  /// Up one folder, unrestricted within what the server lets the app browse.
  void browseUp() {
    final parent = _browsePath?.parent;
    if (parent != null) _open(parent);
  }

  /// Reads the folder shown again: the person's say-so after a failure.
  void retryBrowse() {
    final path = _browsePath;
    if (path != null) _open(path);
  }

  void _open(ServerPath path) {
    if (_dead) return;
    final run = ++_browseRun;
    _browsePath = path;
    _level = FolderBrowserLevel.opening;
    _folders = const [];
    _browseTimer?.cancel();
    _browseTimer = Timer(wait, () {
      if (_dead || run != _browseRun || _level != FolderBrowserLevel.opening) {
        return;
      }
      _level = FolderBrowserLevel.unreachable;
      _notify();
    });
    _notify();
    unawaited(_read(path, run));
  }

  Future<void> _read(ServerPath path, int run) async {
    final result = await _repository.listFolders(
      path.value,
      profile: profile,
      routeKnown: _routeKnown,
    );
    // A late answer still applies while the person has not moved on.
    if (_dead || run != _browseRun) return;
    _browseTimer?.cancel();
    final first = _firstRead;
    switch (result) {
      case WorkspacesOk(:final value):
        _firstRead = false;
        _routeKnown = true;
        _folders = value.folders;
        _level = FolderBrowserLevel.ready;
      case WorkspacesUnsupported():
        _firstRead = false;
        _browseAccess = WorkspaceBrowseAccess.unsupported;
        _level = FolderBrowserLevel.missing;
      case WorkspacesFailed(:final kind):
        _level = switch (kind) {
          WorkspacesFailure.outsideBoundary =>
            // The boundary on the very first read of the visit hides Browse;
            // on a later level it is only that level.
            first ? _lockBrowse() : FolderBrowserLevel.outside,
          WorkspacesFailure.notAllowed => FolderBrowserLevel.notAllowed,
          WorkspacesFailure.notFound ||
          WorkspacesFailure.notADirectory => FolderBrowserLevel.missing,
          _ => FolderBrowserLevel.unreachable,
        };
        if (kind != WorkspacesFailure.unreachable &&
            kind != WorkspacesFailure.unknown) {
          _firstRead = false;
          _routeKnown = true;
        }
    }
    _notify();
  }

  FolderBrowserLevel _lockBrowse() {
    _browseAccess = WorkspaceBrowseAccess.locked;
    _firstRead = false;
    _routeKnown = true;
    return FolderBrowserLevel.outside;
  }

  /// Chooses the folder Browse shows. Null for a missing level or one
  /// outside what the server lets the app browse.
  FolderPick? useBrowsed() {
    final path = _browsePath;
    if (_dead ||
        path == null ||
        _level == FolderBrowserLevel.missing ||
        _level == FolderBrowserLevel.outside) {
      return null;
    }
    return _pickOf(path.value, WorkspaceChoiceSource.browsed);
  }

  FolderPick _pickOf(String path, WorkspaceChoiceSource source) {
    telemetry.chosen(source);
    return FolderPick(
      path: path,
      choice: WorkspaceChoice(path: path, source: source),
    );
  }

  // -- typing -------------------------------------------------------------

  String _text = '';
  List<PathEntrySuggestion> _suggestions = const [];
  bool _capped = false;
  PathEntryCheck _check = PathEntryCheck.idle;
  int _typeRun = 0;
  Timer? _typeTimer;
  Timer? _checkTimer;

  String get typedText => _text;
  List<PathEntrySuggestion> get suggestions => _suggestions;

  /// Hermes returned its 30 items, files and folders together.
  bool get suggestionsCapped => _capped;
  PathEntryCheck get check => _check;

  /// Whether "Use this folder" is available for the typed text.
  bool get canUseTyped => PathEntryView.canUse(_check);

  /// The text changed: ask after the pause, keeping only the latest answer.
  void setTyped(String text) {
    if (_dead) return;
    _text = text;
    final run = ++_typeRun;
    _typeTimer?.cancel();
    _checkTimer?.cancel();
    _suggestions = const [];
    _capped = false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _check = PathEntryCheck.idle;
      _notify();
      return;
    }
    if (!isServerPath(trimmed)) {
      // Never accepted, and nothing is asked.
      _check = PathEntryCheck.relative;
      _notify();
      return;
    }
    _check = PathEntryCheck.idle;
    _notify();
    _typeTimer = Timer(debounce, () => _askTyped(run));
  }

  /// A suggestion was taken: the field now holds it.
  void takeSuggestion(PathEntrySuggestion suggestion) {
    if (_dead) return;
    _text = suggestion.path;
    final run = ++_typeRun;
    _typeTimer?.cancel();
    _checkTimer?.cancel();
    _suggestions = const [];
    _capped = false;
    _check = PathEntryCheck.idle;
    _notify();
    _askTyped(run);
  }

  /// "Check again" after a check that had no answer.
  void checkAgain() {
    if (_dead) return;
    final run = ++_typeRun;
    _typeTimer?.cancel();
    _checkTimer?.cancel();
    _askTyped(run, suggest: false);
  }

  void _askTyped(int run, {bool suggest = true}) {
    if (_dead || run != _typeRun) return;
    final text = _text.trim();
    if (text.isEmpty || !isServerPath(text)) return;
    _check = PathEntryCheck.checking;
    _checkTimer = Timer(wait, () {
      if (_dead || run != _typeRun || _check != PathEntryCheck.checking) return;
      // No answer in time: nothing is sent again by itself.
      _check = PathEntryCheck.tooSlow;
      _notify();
    });
    _notify();
    if (suggest) unawaited(_suggest(text, run));
    unawaited(_checkFolder(text, run));
  }

  Future<void> _suggest(String text, int run) async {
    final result = await _repository.complete(text, profile: profile);
    if (_dead || run != _typeRun) return;
    if (result case WorkspacesOk(:final value)) {
      _suggestions = [
        for (final folder in value.folders)
          PathEntrySuggestion(
            name: folder.display.replaceFirst(RegExp(r'/+$'), ''),
            path: folder.text,
          ),
      ];
      _capped = value.capped;
      _notify();
    }
  }

  Future<void> _checkFolder(String text, int run) async {
    final result = await _repository.listFolders(
      _normalised(text),
      profile: profile,
      routeKnown: _routeKnown,
    );
    if (_dead || run != _typeRun) return;
    _checkTimer?.cancel();
    _check = switch (result) {
      WorkspacesOk() => PathEntryCheck.found,
      // The server cannot say: the choice is accepted and the chat says so
      // if Hermes starts somewhere else.
      WorkspacesUnsupported() => PathEntryCheck.cannotCheck,
      WorkspacesFailed(:final kind) => switch (kind) {
        WorkspacesFailure.notFound ||
        WorkspacesFailure.notADirectory => PathEntryCheck.missing,
        WorkspacesFailure.notAllowed => PathEntryCheck.notAllowed,
        WorkspacesFailure.outsideBoundary => PathEntryCheck.cannotCheck,
        _ => PathEntryCheck.tooSlow,
      },
    };
    if (result is WorkspacesOk) _routeKnown = true;
    _notify();
  }

  /// The typed text without a trailing separator, as a folder path.
  static String _normalised(String text) {
    final trimmed = text.trim();
    if (trimmed.length > 1) return trimmed.replaceFirst(RegExp(r'/+$'), '');
    return trimmed;
  }

  /// Chooses the typed folder, when it can be.
  FolderPick? useTyped() {
    if (_dead || !canUseTyped) return null;
    return _pickOf(_normalised(_text), WorkspaceChoiceSource.typed);
  }

  // -- ending -------------------------------------------------------------

  /// The host ended the visit (the profile changed, the app locked or the
  /// session ended): every answer still on its way is dropped.
  void close() {
    if (_closed) return;
    _closed = true;
    _cancelTimers();
    _loader.removeListener(_catalogChanged);
    if (!_disposed) notifyListeners();
  }

  /// The chat's profile is [now]: a picker for another profile closes.
  void profileChanged(String now) {
    if (now != profile) close();
  }

  void _cancelTimers() {
    _catalogTimer?.cancel();
    _scanTimer?.cancel();
    _browseTimer?.cancel();
    _typeTimer?.cancel();
    _checkTimer?.cancel();
    _probeTimer?.cancel();
  }

  void _notify() {
    if (!_dead) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
    _loader.removeListener(_catalogChanged);
    super.dispose();
  }
}

/// Row ids of the picker.
const kPickerDefaultId = 'default';
const kPickerCurrentId = 'current';
const kPickerProjectPrefix = 'project:';
const kPickerRecentPrefix = 'recent:';

class _Rows {
  _Rows([this.projects = const [], this.recent = const []]);

  final List<WorkspacePickerRow> projects;
  final List<WorkspacePickerRow> recent;
}
