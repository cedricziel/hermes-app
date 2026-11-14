import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../chat/media/media_store.dart';
import '../chat/media/quick_look.dart' show QuickLookToggle;
import 'files_failure.dart';
import 'files_models.dart';
import 'files_platform_policy.dart';
import 'files_preview_kind.dart';
import 'files_source.dart';
import 'files_state.dart';
import 'files_telemetry.dart';
import 'secret_names.dart';
import 'server_path.dart';

/// How many rows a folder shows; the rest are counted, not listed.
const kFilesMaxRows = 2000;

/// How long a request may go unanswered before the page gives up on it. It is
/// the total time for a listing, `git-root`, `default-cwd` and `read-text`; a
/// download is not bounded by it but by the repository's 30 s idle timeout
/// (no chunk for that long) and by Cancel.
const kFilesAnswerTimeout = Duration(seconds: 10);

/// One visit to the Files page of a chat: its folder, listing, selected file
/// and that file's preview.
///
/// It belongs to one chat, one profile and one connection. [cancelAll] (also
/// run by [dispose]) ends it: requests and downloads are cancelled and every
/// answer that arrives afterwards, like one for a folder or file the user has
/// already left, is dropped. Nothing is resent: a request that gets no answer
/// within [answerTimeout] ends in a failure the user can retry.
///
/// Nothing is requested for a file the user has not opened or acted on, and a
/// file whose name looks secret is asked about first. No path, name or
/// content reaches telemetry.
class FilesController extends ChangeNotifier {
  FilesController({
    required this._source,
    required this._media,
    required this._profile,
    this._cwd,
    this._openedFrom = FilesOpenedFrom.activity,
    FilesTelemetry? telemetry,
    this._answerTimeout = kFilesAnswerTimeout,
    this._share,
    this._policy = const FilesPlatformPolicy.none(),
  }) : _telemetry = telemetry ?? FilesTelemetry();

  final FilesSource _source;
  final MediaStore _media;
  final String _profile;
  final ServerPath? _cwd;
  final FilesOpenedFrom _openedFrom;
  final FilesTelemetry _telemetry;
  final Duration _answerTimeout;
  final Future<void> Function(File file)? _share;
  final FilesPlatformPolicy _policy;

  var _closed = false;
  var _disposed = false;
  var _folderGen = 0;
  var _fileGen = 0;
  CancelToken? _listToken;
  CancelToken? _gitToken;
  CancelToken? _fileToken;

  ServerPath? _begin;
  ServerPath? _root;

  /// The first listing was empty, so the folder the server resolved the start
  /// folder to is not known yet: [_root] is the stored text until a listing
  /// with rows, or a git root, says better.
  var _rootProvisional = false;
  ServerPath? _gitAnswer;
  ServerPath? _folder;
  FsListing? _listing;
  FolderState _folderState = const FolderLoading();
  var _stale = false;
  var _showHidden = false;
  var _fromServerDefault = false;
  List<FsEntry>? _visible;

  FsEntry? _selected;
  PreviewState _preview = const PreviewIdle();
  PreviewState? _resting;
  var _acting = false;
  int? _knownSize;
  Future<void> Function()? _pending;

  /// Paths the user said Continue for, whose cached copy goes when their
  /// preview closes.
  final _secretOk = <String>{};

  /// Paths already tried as a folder after a 400, so it happens once.
  final _triedAsFolder = <String>{};

  /// Keys downloaded without a length (an SSH workspace): they cannot be
  /// told complete, so they download again on the next open.
  final _unverified = <String>{};

  final _fetches = <String, Future<void>>{};

  /// The highest folder the page may show, once the first listing is in.
  ServerPath? get root => _root;

  /// The folder being shown, or loading.
  ServerPath? get folder => _folder;

  FolderState get folderState => _folderState;

  /// Whether the page started at the server's `default-cwd` because the chat
  /// has no stored folder.
  bool get startedFromServerDefault => _fromServerDefault;

  /// A refresh failed after a listing: the list stays, marked out of date.
  bool get stale => _stale;

  bool get showHidden => _showHidden;

  FsEntry? get selected => _selected;

  PreviewState get preview => _preview;

  /// Whether Up can go anywhere: not at the highest folder.
  bool get canGoUp {
    final folder = _folder;
    final root = _root;
    if (folder == null || root == null || folder.parent == null) return false;
    return folder.isWithin(root) && !root.isWithin(folder);
  }

  /// The rows to show: folders first as the server sent them, hidden names
  /// only when asked for, at most [kFilesMaxRows].
  List<FsEntry> get entries {
    final listing = _listing;
    if (listing == null) return const [];
    return _visible ??= [
      for (final e in listing.entries)
        if (_showHidden || !isHidden(e.name)) e,
    ];
  }

  /// How many rows [entries] would hold without the cap.
  int get entryCount => entries.length;

  /// The rows that fit on the page.
  List<FsEntry> get shownEntries =>
      entryCount <= kFilesMaxRows ? entries : entries.sublist(0, kFilesMaxRows);

  /// Whether hidden names exist that are not shown.
  bool get hasHiddenEntries =>
      !_showHidden && (_listing?.entries.any((e) => isHidden(e.name)) ?? false);

  /// Whether [entry]'s name looks secret, so it is asked about first.
  bool isSecret(FsEntry entry) =>
      !entry.isDirectory && SecretNames.looksSecret(entry.path);

  // -- Folder ---------------------------------------------------------------

  /// Lists the chat's folder: the stored `cwd`, else the server's
  /// `default-cwd` for the chat's profile.
  Future<void> start() {
    if (_closed) return Future.value();
    _telemetry.opened(_openedFrom);
    return _begin0();
  }

  Future<void> _begin0() async {
    final gen = ++_folderGen;
    _setFolder(const FolderLoading());
    var begin = _begin ?? _cwd;
    if (begin == null) {
      final result = await _bounded(
        (t) => _source.defaultCwd(cancelToken: t),
        _newListToken(),
      );
      if (_gone(gen, _folderGen)) return;
      switch (result) {
        case FilesOk(:final value):
          begin = value;
          _fromServerDefault = true;
        case FilesFailed(:final kind):
          return _setFolder(FolderFailed(kind));
        case FilesUnsupported():
          return _setFolder(const FolderFailed(FilesFailure.unreadable));
      }
    }
    _begin = begin;
    _folder = begin;
    _notify();
    _listToken?.cancel();
    _gitToken?.cancel();
    final listing = _bounded(
      (t) => _source.list(begin!, cancelToken: t),
      _newListToken(),
    );
    final git = _bounded(
      (t) => _source.gitRoot(begin!, cancelToken: t),
      _gitToken = CancelToken(),
    );
    final listed = await listing;
    final rooted = await git;
    if (_gone(gen, _folderGen)) return;
    switch (listed) {
      case FilesOk(:final value):
        _gitAnswer = rooted is FilesOk<ServerPath?> ? rooted.value : null;
        if (!_setBoundary(begin, value)) {
          _setFolder(const FolderFailed(FilesFailure.unreadable));
          return;
        }
        _listing = value;
        _visible = null;
        _setFolder(const FolderReady());
      case FilesFailed(:final kind):
        _setFolder(FolderFailed(kind));
      case FilesUnsupported():
        _setFolder(const FolderFailed(FilesFailure.unreadable));
    }
  }

  /// Fixes the highest folder from the first listing [value] of [begin], or
  /// says the listing cannot be trusted to.
  ///
  /// The server resolves links (`/tmp` is `/private/tmp` on a Mac), so the
  /// folder its rows lie in, not the stored text, is the one the page is
  /// confined to. That is only believed when every row shares one parent and
  /// the parent is not the filesystem root (unless that is where the page
  /// started): a wrong first answer must not widen the page to `/`. With no
  /// rows nothing is known, so the stored text stands in, provisionally, and
  /// the next listing with rows decides. A git root is taken only when it
  /// is not a filesystem root and holds the folder.
  bool _setBoundary(ServerPath begin, FsListing value) {
    ServerPath resolved = begin;
    var provisional = value.entries.isEmpty;
    if (!provisional) {
      final parent = value.entries.first.path.parent;
      if (parent == null ||
          value.entries.any((e) => e.path.parent != parent) ||
          (parent.isRoot && !begin.isRoot)) {
        return false;
      }
      resolved = parent;
    }
    final git = _gitAnswer;
    final usable = git != null && !git.isRoot && resolved.isWithin(git);
    _rootProvisional = provisional && !usable;
    _root = usable ? git : resolved;
    // A provisional folder is not yet the one the server resolves, so the
    // source must not refuse the rows it will list under another name.
    _source.highestFolder = _rootProvisional ? null : _root;
    _folder = resolved;
    return true;
  }

  /// Lists the folder again. The list stays while it loads; when that fails
  /// it stays under [stale]. Nothing is resent by itself.
  Future<void> refresh() {
    if (_closed) return Future.value();
    final folder = _folder;
    if (_root == null || folder == null) return _begin0();
    return _load(folder, refresh: _listing != null);
  }

  /// Opens a folder the server listed. One outside the highest folder is
  /// refused without a request.
  Future<void> openFolder(FsEntry entry) => _go(entry.path);

  /// Opens an ancestor of the folder shown, as a path-bar segment asks. One
  /// outside the highest folder is refused without a request.
  Future<void> openPath(ServerPath path) => _go(path);

  /// Goes to the parent folder, unless [canGoUp] is false.
  Future<void> up() {
    final parent = _folder?.parent;
    if (!canGoUp || parent == null) return Future.value();
    return _go(parent);
  }

  Future<void> _go(ServerPath path) {
    if (_closed) return Future.value();
    _closePreview();
    final root = _root;
    if (root != null && !path.isWithin(root)) {
      _folderGen++;
      _listToken?.cancel();
      _folder = path;
      _listing = null;
      _visible = null;
      _stale = false;
      _setFolder(const FolderFailed(FilesFailure.outside));
      return Future.value();
    }
    return _load(path, refresh: false);
  }

  Future<void> _load(ServerPath path, {required bool refresh}) async {
    final gen = ++_folderGen;
    _listToken?.cancel();
    if (!refresh) {
      _folder = path;
      _listing = null;
      _visible = null;
      _stale = false;
      _setFolder(const FolderLoading());
    }
    final result = await _bounded(
      (t) => _source.list(path, cancelToken: t),
      _newListToken(),
    );
    if (_gone(gen, _folderGen)) return;
    switch (result) {
      case FilesOk(:final value):
        _stale = false;
        if (_rootProvisional && !_setBoundary(_begin ?? path, value)) {
          _listing = null;
          _visible = null;
          _setFolder(const FolderFailed(FilesFailure.unreadable));
          return;
        }
        if (value.allOutsideBoundary) {
          _listing = null;
          _visible = null;
          _setFolder(const FolderFailed(FilesFailure.outside));
          return;
        }
        _listing = value;
        _visible = null;
        final selected = _selected;
        if (refresh &&
            selected != null &&
            !value.entries.any((e) => e.path == selected.path)) {
          _closePreview();
        }
        _setFolder(const FolderReady());
      case FilesFailed(kind: FilesFailure.notAFile) when !refresh:
        // ENOTDIR: the row was a file after all. List its folder instead and
        // open the file there.
        await _listParentAndOpen(path);
      case FilesFailed(:final kind):
        if (refresh && _listing != null) {
          _stale = true;
          _notify();
        } else {
          _listing = null;
          _visible = null;
          _setFolder(FolderFailed(kind));
        }
      case FilesUnsupported():
        _setFolder(const FolderFailed(FilesFailure.unreadable));
    }
  }

  Future<void> _listParentAndOpen(ServerPath path) async {
    final parent = path.parent;
    final root = _root;
    if (parent == null || root == null || !parent.isWithin(root)) {
      _listing = null;
      _visible = null;
      _setFolder(const FolderFailed(FilesFailure.notAFile));
      return;
    }
    await _load(parent, refresh: false);
    if (_closed || _folder != parent || _folderState is! FolderReady) return;
    final entry = _listing?.entries
        .where((e) => e.path == path && !e.isDirectory)
        .firstOrNull;
    if (entry != null) await _open(entry);
  }

  void toggleHidden() {
    if (_closed) return;
    _showHidden = !_showHidden;
    _visible = null;
    _telemetry.hiddenToggled(on: _showHidden);
    _notify();
  }

  // -- Preview --------------------------------------------------------------

  /// A tap on a row: a folder opens, a file previews.
  Future<void> select(FsEntry entry) {
    if (_closed) return Future.value();
    if (entry.isDirectory) return openFolder(entry);
    return _open(entry);
  }

  /// Asks again after a failure.
  Future<void> retry() {
    final entry = _selected;
    return entry == null ? Future.value() : _open(entry);
  }

  Future<void> _open(FsEntry entry) async {
    if (_closed) return;
    _leave(except: entry);
    _cancelFile();
    final gen = ++_fileGen;
    _pending = null;
    _resting = null;
    _selected = entry;
    _knownSize = null;
    if (_askSecret(entry, () => _open(entry))) return;
    final kind = previewKindFor(entry.path.name);
    _telemetry.previewOpened(kind);
    if (kind.readsText) return _readText(entry, kind, gen);
    if (kind == FilePreviewKind.image) return _showImage(entry, gen);
    _setPreview(PreviewDetails(kind));
  }

  bool _askSecret(FsEntry entry, Future<void> Function() then) {
    if (!isSecret(entry) || _secretOk.contains(entry.path.value)) return false;
    _pending = then;
    _telemetry.secretWarned();
    _setPreview(const PreviewConfirmSecret());
    return true;
  }

  /// The user chose Continue on the secret question. A press for a question
  /// no longer on screen does nothing.
  Future<void> confirmSecret() {
    final entry = _selected;
    final next = _pending;
    if (_closed ||
        entry == null ||
        next == null ||
        _preview is! PreviewConfirmSecret) {
      return Future.value();
    }
    _pending = null;
    _secretOk.add(entry.path.value);
    return next();
  }

  /// The user chose Cancel on the secret question: nothing was requested.
  void declineSecret() {
    if (_closed || _preview is! PreviewConfirmSecret) return;
    _pending = null;
    _closePreview();
    _notify();
  }

  /// The user chose Download on the size question.
  Future<void> confirmSize() {
    final next = _pending;
    if (_closed || next == null || _preview is! PreviewConfirmSize) {
      return Future.value();
    }
    _pending = null;
    return next();
  }

  /// The user chose Cancel on the size question.
  void declineSize() {
    final preview = _preview;
    final entry = _selected;
    if (_closed || preview is! PreviewConfirmSize || entry == null) return;
    _pending = null;
    _setPreview(
      _resting ??
          PreviewDetails(previewKindFor(entry.path.name), size: preview.bytes),
    );
  }

  Future<void> _readText(FsEntry entry, FilePreviewKind kind, int gen) async {
    final span = _telemetry.startPreview();
    _setPreview(const PreviewLoading());
    final result = await _bounded(
      (t) => _source.readText(entry.path, cancelToken: t),
      _newFileToken(),
    );
    if (_gone(gen, _fileGen)) {
      _telemetry.endPreview(span, kind, FilesPreviewOutcome.cancelled);
      return;
    }
    switch (result) {
      case FilesOk(:final value):
        _knownSize = value.byteSize;
        _telemetry.endPreview(
          span,
          kind,
          FilesPreviewOutcome.ok,
          bytes: value.byteSize,
        );
        _setPreview(
          value.binary
              ? PreviewDetails(FilePreviewKind.other, size: value.byteSize)
              : PreviewText(kind, value),
        );
      case FilesFailed(kind: FilesFailure.notAFile):
        _telemetry.endPreview(span, kind, FilesPreviewOutcome.failed);
        await _asFolder(entry);
      case FilesFailed(kind: FilesFailure.tooLarge):
        _telemetry.endPreview(span, kind, FilesPreviewOutcome.tooLarge);
        _setPreview(
          const PreviewDetails(FilePreviewKind.other, tooLargeForText: true),
        );
      case FilesFailed(kind: FilesFailure.cancelled):
        _telemetry.endPreview(span, kind, FilesPreviewOutcome.cancelled);
        _setPreview(PreviewDetails(kind));
      case FilesFailed(:final kind):
        _telemetry.endPreview(
          span,
          FilePreviewKind.other,
          FilesPreviewOutcome.failed,
        );
        _setPreview(PreviewFailed(kind));
      case FilesUnsupported():
        _telemetry.endPreview(span, kind, FilesPreviewOutcome.failed);
        _setPreview(const PreviewFailed(FilesFailure.unreadable));
    }
  }

  Future<void> _showImage(
    FsEntry entry,
    int gen, {
    bool allowLarge = false,
  }) async {
    const image = FilePreviewKind.image;
    final span = _telemetry.startPreview();
    _setPreview(const PreviewLoading());
    final result = await _fetch(entry, gen, allowLarge: allowLarge);
    if (_gone(gen, _fileGen)) {
      _telemetry.endPreview(span, image, FilesPreviewOutcome.cancelled);
      return;
    }
    switch (result) {
      case _Fetched(:final file, :final length):
        _telemetry.endPreview(
          span,
          image,
          FilesPreviewOutcome.ok,
          bytes: length,
        );
        _setPreview(PreviewImage(file));
      case _Declined(:final bytes):
        _telemetry.endPreview(
          span,
          image,
          FilesPreviewOutcome.tooLarge,
          bytes: bytes,
        );
        _pending = () => _showImage(entry, ++_fileGen, allowLarge: true);
        _setPreview(PreviewConfirmSize(bytes));
      case _FetchFailed(kind: FilesFailure.notAFile):
        _telemetry.endPreview(span, image, FilesPreviewOutcome.failed);
        await _asFolder(entry);
      case _FetchFailed(kind: FilesFailure.cancelled):
        _telemetry.endPreview(span, image, FilesPreviewOutcome.cancelled);
        _setPreview(const PreviewDetails(image));
      case _FetchFailed(:final kind):
        _telemetry.endPreview(span, image, FilesPreviewOutcome.failed);
        _setPreview(PreviewFailed(kind));
    }
  }

  /// A row listed as a file turned out to be a folder (a link to one): try it
  /// as a folder, once.
  Future<void> _asFolder(FsEntry entry) async {
    if (!_triedAsFolder.add(entry.path.value)) {
      _setPreview(const PreviewFailed(FilesFailure.notAFile));
      return;
    }
    _selected = null;
    _setPreview(const PreviewIdle());
    await _go(entry.path);
  }

  // -- Save, share, open with ------------------------------------------------

  Future<void> save() => _act(FileAction.save);

  /// Whether Open with… may be offered for [entry]. Never for a file that
  /// Windows would run.
  bool canOpenWith(FsEntry entry) => _policy.canOpenWith(entry.path.name);

  Future<void> openWith() {
    final entry = _selected;
    if (entry == null || !canOpenWith(entry)) return Future.value();
    return _act(FileAction.openWith);
  }

  Future<void> shareFile() => _act(FileAction.share);

  /// Shows the selected file in the system's Quick Look panel (macOS). With
  /// [toggle] the panel closes instead when it already shows the file.
  Future<void> quickLook({bool toggle = false}) =>
      _act(FileAction.quickLook, toggle: toggle);

  String? _savedName;

  /// The name of the file a Save just kept, returned once so the screen says
  /// so a single time.
  String? takeSavedName() {
    final name = _savedName;
    _savedName = null;
    return name;
  }

  /// The selected file's size once a header or `read-text` said.
  int? get knownSize => _knownSize;

  /// A copy of [entry] in the cache for a drag out of the app, downloaded if
  /// need be, or null when it must not go: a folder, a file whose name looks
  /// secret that the user has not said Continue for, or a failed download.
  /// It does not touch the preview. The drop is the user's action, so a large
  /// file is not asked about.
  Future<File?> stageForDrag(FsEntry entry) async {
    if (_closed || entry.isDirectory) return null;
    if (isSecret(entry) && !_secretOk.contains(entry.path.value)) return null;
    final result = await _run(
      entry,
      _key(entry.path),
      _fileGen,
      allowLarge: true,
      fetchToken: CancelToken(),
    );
    return result is _Fetched ? result.file : null;
  }

  Future<void> _act(
    FileAction action, {
    bool allowLarge = false,
    bool toggle = false,
  }) async {
    final entry = _selected;
    // A second tap while a read or download runs would drop the preview it
    // is about to return to.
    if (_closed || entry == null || _acting || _preview is PreviewLoading) {
      return;
    }
    if (_askSecret(entry, () => _act(action, toggle: toggle))) return;
    _acting = true;
    try {
      await _actOn(action, entry, allowLarge, toggle);
    } finally {
      _acting = false;
    }
  }

  Future<void> _actOn(
    FileAction action,
    FsEntry entry,
    bool allowLarge,
    bool toggle,
  ) async {
    final resting =
        _resting ??
        switch (_preview) {
          PreviewConfirmSize() || PreviewConfirmSecret() => PreviewDetails(
            previewKindFor(entry.path.name),
            size: _knownSize,
          ),
          final other => other,
        };
    _resting = resting;
    _cancelFile();
    final gen = ++_fileGen;
    _setPreview(const PreviewLoading());
    final result = await _fetch(entry, gen, allowLarge: allowLarge);
    if (_gone(gen, _fileGen)) return;
    switch (result) {
      case _Fetched(:final file):
        _resting = null;
        _setPreview(resting);
        final failure = await _finish(action, entry, file, toggle);
        if (_gone(gen, _fileGen)) return;
        if (failure != null) _setPreview(PreviewFailed(failure));
      case _Declined(:final bytes):
        _pending = () => _act(action, allowLarge: true, toggle: toggle);
        _setPreview(PreviewConfirmSize(bytes));
      case _FetchFailed(kind: FilesFailure.cancelled):
        _resting = null;
        _setPreview(resting);
      case _FetchFailed(:final kind):
        _resting = null;
        _setPreview(PreviewFailed(kind));
    }
  }

  /// Hands [file] to the system for [action]. What comes back is the kind of
  /// failure, if any, and nothing else: an exception from the platform can
  /// hold the cache path or the file's name, so it is never read.
  Future<FilesFailure?> _finish(
    FileAction action,
    FsEntry entry,
    File file,
    bool toggle,
  ) async {
    try {
      if (action == FileAction.quickLook) {
        final shown = await _media.showQuickLook(file, toggle: toggle);
        return shown == QuickLookToggle.failed ? FilesFailure.unreadable : null;
      }
      final done = switch (action) {
        FileAction.save => await _media.saveFile(entry.path.name, file),
        FileAction.openWith => await _openMarked(file),
        FileAction.share => await _shared(file),
        FileAction.quickLook => false,
      };
      if (done) {
        _telemetry.saved(action.slug);
        if (action == FileAction.save) _savedName = entry.path.name;
      }
      return null;
    } on Object {
      return FilesFailure.unreadable;
    }
  }

  /// Opens [file] after marking it as downloaded; a file that cannot be
  /// marked is not opened.
  Future<bool> _openMarked(File file) async {
    await _policy.markDownloaded(file);
    return _media.open(file);
  }

  Future<bool> _shared(File file) async {
    final share = _share;
    if (share == null) return false;
    try {
      await share(file);
      return true;
    } on Object {
      return false;
    }
  }

  /// Stops a running read or download. The partial file is deleted and the
  /// preview goes back to the file's details without an error.
  void cancelDownload() {
    _fileToken?.cancel();
  }

  /// Deletes the cached copy and fetches the selected file again.
  Future<void> reload() async {
    final entry = _selected;
    if (_closed || entry == null) return;
    final key = _key(entry.path);
    _cancelFile();
    await _fetches[key];
    _unverified.remove(key);
    await _media.evict(key);
    if (_closed || _selected != entry) return;
    await _open(entry);
  }

  /// Closes the preview. A cached copy fetched after the secret question is
  /// deleted.
  void closePreview() {
    if (_closed) return;
    _closePreview();
    _notify();
  }

  void _closePreview() {
    _cancelFile();
    _fileGen++;
    _pending = null;
    _resting = null;
    final entry = _selected;
    if (entry != null) _forgetSecret(entry.path);
    _selected = null;
    _preview = const PreviewIdle();
  }

  /// A different file is being opened: what the previous one fetched after
  /// the secret question goes.
  void _leave({required FsEntry except}) {
    final previous = _selected;
    if (previous != null && previous.path != except.path) {
      _forgetSecret(previous.path);
    }
  }

  void _forgetSecret(ServerPath path) {
    if (_secretOk.remove(path.value)) {
      unawaited(_media.evict(_key(path)));
      _unverified.remove(_key(path));
    }
  }

  /// Ends the page: cancels every request and download, drops late answers
  /// and removes what was fetched after a secret question. A profile switch,
  /// sign-out, server change or leaving the page calls it.
  void cancelAll() {
    if (_closed) return;
    _closed = true;
    _folderGen++;
    _fileGen++;
    _listToken?.cancel();
    _gitToken?.cancel();
    _fileToken?.cancel();
    _pending = null;
    for (final path in _secretOk) {
      unawaited(_media.evict(_keyOf(path)));
    }
    _secretOk.clear();
    // A copy without a length cannot be told complete, so the next page must
    // not take it for one.
    for (final key in _unverified) {
      unawaited(_media.evict(key));
    }
    _unverified.clear();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelAll();
    super.dispose();
  }

  // -- Plumbing --------------------------------------------------------------

  String _key(ServerPath path) => _keyOf(path.value);

  /// A copy of a file whose name looks secret goes under a key the next
  /// launch wipes, in case the app is killed before this page deletes it.
  String _keyOf(String path) {
    final secret = ServerPath.tryParse(path);
    final prefix = secret != null && SecretNames.looksSecret(secret)
        ? kSecretCopyKeyPrefix
        : 'fs:';
    return '$prefix$_profile:$path';
  }

  /// Streams [entry] into the cache and says how it went. A fetch of the same
  /// file still running is awaited first, so two never share one.
  Future<_Fetch> _fetch(
    FsEntry entry,
    int gen, {
    required bool allowLarge,
  }) async {
    final key = _key(entry.path);
    final earlier = _fetches[key];
    if (earlier != null) {
      await earlier;
      if (_gone(gen, _fileGen)) {
        return const _FetchFailed(FilesFailure.cancelled);
      }
    }
    if (_unverified.remove(key)) {
      await _media.evict(key);
      // The user may have moved on, or the page ended, while it was deleted.
      if (_gone(gen, _fileGen)) {
        return const _FetchFailed(FilesFailure.cancelled);
      }
    }
    final run = _run(entry, key, gen, allowLarge: allowLarge);
    final tracked = run.then<void>((_) {});
    _fetches[key] = tracked;
    unawaited(
      tracked.whenComplete(() {
        if (identical(_fetches[key], tracked)) _fetches.remove(key);
      }),
    );
    return run;
  }

  Future<_Fetch> _run(
    FsEntry entry,
    String key,
    int gen, {
    required bool allowLarge,
    CancelToken? fetchToken,
  }) async {
    final token = fetchToken ?? _newFileToken();
    var ran = false;
    int? length;
    try {
      final file = await _media.stageDownload(key, entry.path.name, (
        sink,
      ) async {
        ran = true;
        final result = await _source.download(
          entry.path,
          sink: sink,
          cancelToken: token,
          allowLarge: allowLarge,
          onProgress: (received, total) {
            if (fetchToken == null && !_gone(gen, _fileGen)) {
              _setPreview(PreviewLoading(received: received, total: total));
            }
          },
        );
        switch (result) {
          case FilesOk(:final value):
            length = value.contentLength;
            if (value.declined) {
              throw _Stop(_Declined(value.contentLength ?? 0));
            }
            final expected = _knownSize;
            if (length == null && expected != null && value.bytes < expected) {
              throw const _Stop(_FetchFailed(FilesFailure.unreadable));
            }
          case FilesFailed(:final kind):
            throw _Stop(_FetchFailed(kind));
          case FilesUnsupported():
            throw const _Stop(_FetchFailed(FilesFailure.unreadable));
        }
      });
      if (ran && length == null) _unverified.add(key);
      try {
        await _policy.markDownloaded(file);
      } on Object {
        // Opening the file marks it again and fails if that cannot be done.
      }
      if (_closed) {
        // Ended while it finished: nothing of it may stay behind.
        if (_unverified.remove(key) || _secretOk.contains(entry.path.value)) {
          unawaited(_media.evict(key));
        }
      }
      return _Fetched(file, length);
    } on _Stop catch (stop) {
      return stop.result;
    } on Object {
      return const _FetchFailed(FilesFailure.unreadable);
    }
  }

  CancelToken _newListToken() => _listToken = CancelToken();

  /// A token for the request being started. The one it replaces is not
  /// cancelled here: whoever starts a request has already cancelled what it
  /// replaces, and this may be a stale call that must not end a newer one.
  CancelToken _newFileToken() => _fileToken = CancelToken();

  void _cancelFile() => _fileToken?.cancel();

  /// Whether the answer for generation [gen] is one the user has left.
  bool _gone(int gen, int current) => _closed || gen != current;

  /// [call]'s answer, or "unreachable" when none comes within the timeout; the
  /// request is cancelled then and never sent again.
  Future<FilesResult<T>> _bounded<T>(
    Future<FilesResult<T>> Function(CancelToken token) call,
    CancelToken token,
  ) {
    final done = Completer<FilesResult<T>>();
    final timer = Timer(_answerTimeout, () {
      if (done.isCompleted) return;
      token.cancel();
      done.complete(const FilesFailed(FilesFailure.unreachable));
    });
    call(token)
        .then<void>((result) {
          if (!done.isCompleted) done.complete(result);
        })
        .catchError((Object _) {
          if (!done.isCompleted) {
            done.complete(const FilesFailed(FilesFailure.unreadable));
          }
        })
        .whenComplete(timer.cancel);
    return done.future;
  }

  void _setFolder(FolderState state) {
    _folderState = state;
    _notify();
  }

  void _setPreview(PreviewState state) {
    _preview = state;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }
}

sealed class _Fetch {
  const _Fetch();
}

class _Fetched extends _Fetch {
  const _Fetched(this.file, this.length);

  final File file;
  final int? length;
}

class _Declined extends _Fetch {
  const _Declined(this.bytes);

  final int bytes;
}

class _FetchFailed extends _Fetch {
  const _FetchFailed(this.kind);

  final FilesFailure kind;
}

/// Ends a staged download early, carrying how.
class _Stop implements Exception {
  const _Stop(this.result);

  final _Fetch result;
}
