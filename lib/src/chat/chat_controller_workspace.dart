part of 'chat_controller.dart';

/// What the controller holds about folders, in memory only. Nothing here is
/// written to the device, logged or put in a span: a path, folder name,
/// project name, branch and profile stay in these fields.
class _WorkspaceData {
  /// The folder picked while no thread exists to hold it.
  WorkspaceChoice? pending;

  /// The pick a send carried, until the server says where it started.
  final sent = <ChatThread, WorkspaceChoice>{};
  final projects = <ChatThread, WorkspaceProjectRef>{};
  final mismatches = <ChatThread, WorkspaceMismatch>{};

  /// Moves by (profile, stored id): the outcome and the hold on Send outlive
  /// the thread objects a reload replaces.
  final moves = <(String, String), _MoveRecord>{};

  /// One catalog per recipient profile, kept while the welcome view shows.
  final loaders = <String, WorkspaceCatalogLoader>{};

  /// Whether the server answered "unknown method" to a move. Kept for the
  /// connection.
  var moveUnsupported = false;

  /// Counts the times everything was dropped, for a picker or confirmation
  /// that must close when it changes.
  var epoch = 0;

  /// What a profile switch drops: everything about the chats of the profile
  /// before, except a move that is still being settled.
  void profileSwitched() {
    epoch++;
    pending = null;
    sent.clear();
    projects.clear();
    mismatches.clear();
    moves.removeWhere((_, record) => !record.state.inFlight);
    clearLoaders();
  }

  void clearLoaders() {
    for (final loader in loaders.values) {
      loader.dispose();
    }
    loaders.clear();
  }
}

/// One chat's move: where it stands, what it asked for, and which move and
/// which re-read the answers in flight belong to.
class _MoveRecord {
  WorkspaceMoveState state = WorkspaceMoveState.idle;

  /// The folder asked for and the one the chat had, kept until settled.
  String? target;
  String? previous;
  var moveRun = 0;
  var readGen = 0;
}

/// The working directory of a chat: the folder picked for a new one, where
/// Hermes started it, and moving an existing one.
extension _ChatControllerWorkspace on ChatController {
  WorkspaceChoice? get _workspaceChoiceImpl {
    final selected = selectedThread;
    return selected == null ? _workspace.pending : selected.workspaceChoice;
  }

  bool _isNewChat(ChatThread thread) =>
      !thread.remote && !_bound.contains(thread);

  bool _chooseWorkspaceImpl(WorkspaceChoice? choice) {
    if (!active) return false;
    final selected = selectedThread;
    if (selected == null) {
      _workspace.pending = choice;
    } else if (_isNewChat(selected)) {
      selected.workspaceChoice = choice;
    } else {
      return false;
    }
    notifyListeners();
    return true;
  }

  /// The folder for [thread]'s first send, or null for a resumed chat: only
  /// a chat that does not exist yet carries one.
  WorkspaceChoice? _choiceForSend(ChatThread thread, String? threadId) {
    if (threadId != null) return null;
    final choice = thread.workspaceChoice;
    if (choice != null) _workspace.sent[thread] = choice;
    return choice;
  }

  /// A new chat takes the pick made while none existed.
  void _carryPendingChoice(ChatThread thread) {
    final pending = _workspace.pending;
    if (pending == null) return;
    thread.workspaceChoice = pending;
    _workspace.pending = null;
  }

  /// The chat exists on the server now: its draft pick is spent.
  void _workspaceCreated(ChatThread thread) {
    thread.workspaceChoice = null;
  }

  void _workspaceBoundImpl(ChatThread thread, WorkspaceBound event) {
    thread
      ..workingDirectory = event.cwd
      ..branch = event.branch
      ..folderPath =
          sessionFolderPath({
            'git_repo_root': event.gitRepoRoot,
            'cwd': event.cwd,
          }) ??
          event.cwd;
    if (event.project case final project?) {
      _workspace.projects[thread] = project;
    }
    final picked = _workspace.sent.remove(thread);
    if (picked != null &&
        folderMismatch(
          picked.path,
          event.cwd,
          home: _workspace.loaders[_profileKey]?.catalog?.home,
        )) {
      _workspace.mismatches[thread] = WorkspaceMismatch(
        picked: picked.path,
        reported: event.cwd,
        profileMayUseOwnFolder: event.retriedWithoutExplicit,
      );
      events('workspace.cwd_mismatch', {
        'retried_without_explicit': event.retriedWithoutExplicit,
      });
    }
    notifyListeners();
  }

  String get _profileKey => _profile ?? kDefaultProfile;

  /// The server's home folder, when the profile's catalog was read.
  String? get _homeImpl => _workspace.loaders[_profileKey]?.catalog?.home;

  /// Whether "Change folder" is worth offering for [thread]: a stored chat
  /// with a known folder, on a server that has the workspace routes. While the
  /// catalog is still being read it is offered; it goes away once the read
  /// says the server is older. A reply or a move in flight keeps it offered
  /// (the control says why it is disabled).
  bool _changeOfferedImpl(ChatThread thread) {
    // Reads the catalog if nobody did: an older server answers "unsupported"
    // and the control goes away.
    _catalogFor(null);
    final block = _moveBlockImpl(thread);
    if (block != null &&
        block != WorkspaceMoveBlock.replying &&
        block != WorkspaceMoveBlock.moving) {
      return false;
    }
    final path = thread.workingDirectory ?? thread.folderPath;
    if (path == null || path.trim().isEmpty) return false;
    return _workspace.loaders[_profileKey]?.status !=
        WorkspaceCatalogStatus.unsupported;
  }

  bool get _offlineImpl =>
      _workspace.loaders[_profileKey]?.status == WorkspaceCatalogStatus.offline;

  /// The project that holds [thread]'s folder: the server's own answer for a
  /// chat just created, else the catalog's by the server's rule. Never reads
  /// the catalog; null when it was not read.
  String? _projectNameOfImpl(ChatThread thread, String path) =>
      _workspace.projects[thread]?.name ??
      _workspace.loaders[_profileKey]?.projectFor(path)?.name;

  WorkspaceCatalogLoader? _catalogFor(String? profile) {
    final repository = workspaces;
    // Nothing is read for a locked app: the folders are dropped with it.
    if (repository == null || !active || (appLock?.locked ?? false)) {
      return null;
    }
    final key = profile ?? _profileKey;
    var loader = _workspace.loaders[key];
    if (loader == null) {
      loader = WorkspaceCatalogLoader(repository: repository, profile: key)
        ..addListener(notifyListeners);
      _workspace.loaders[key] = loader;
      // Not now: this runs while a screen builds, and a read starting
      // notifies its listeners.
      scheduleMicrotask(loader.load);
    }
    return loader;
  }

  NewChatWorkspace _newChatWorkspaceImpl(String? profile) {
    final loader = _catalogFor(profile);
    final choice = _workspaceChoiceImpl;
    final folder = choice?.path ?? loader?.defaultFolder;
    final project =
        choice?.projectName ??
        (folder == null ? null : loader?.projectFor(folder)?.name);
    return NewChatWorkspace(
      status: loader?.status ?? WorkspaceCatalogStatus.unsupported,
      choice: choice,
      folder: folder,
      projectName: project,
      branch: choice?.branch,
      stalled: loader?.stalled ?? false,
    );
  }

  /// A new chat's recipient changed profile: the pick and the catalog of the
  /// profile before are no longer about the recipient.
  void _workspaceProfileSwitched() {
    for (final thread in _threads) {
      if (_isNewChat(thread)) thread.workspaceChoice = null;
    }
    _workspace.profileSwitched();
  }

  /// App Lock engaged: like sign-out, except that a move still being
  /// settled keeps its record.
  void _workspaceLocked() {
    _workspace.epoch++;
    _workspace.pending = null;
    for (final thread in _threads) {
      thread.workspaceChoice = null;
    }
    _workspace
      ..sent.clear()
      ..projects.clear()
      ..mismatches.clear()
      ..moves.removeWhere((_, record) => !record.state.inFlight)
      ..clearLoaders();
  }

  void _clearWorkspaceStateImpl() {
    _workspace.epoch++;
    _workspace.pending = null;
    for (final thread in _threads) {
      thread.workspaceChoice = null;
    }
    _workspace
      ..sent.clear()
      ..projects.clear()
      ..mismatches.clear()
      ..moves.clear()
      ..moveUnsupported = false
      ..clearLoaders();
  }

  // Moving a chat. Move state is kept by (profile, stored id), not by the
  // thread object: a reload replaces every thread, and the outcome of a move
  // and the hold on Send must survive that.

  (String, String) _moveKey(ChatThread thread) => (_profileKey, thread.id);

  /// The thread of the current profile that [key] names, whatever object
  /// holds it now.
  ChatThread? _threadFor((String, String) key) {
    if (key.$1 != _profileKey) return null;
    for (final thread in _threads) {
      if (thread.id == key.$2 && thread.remote) return thread;
    }
    return null;
  }

  WorkspaceMoveState _moveStateImpl(ChatThread thread) =>
      _workspace.moves[_moveKey(thread)]?.state ?? WorkspaceMoveState.idle;

  WorkspaceMoveBlock? _moveBlockImpl(ChatThread thread, {String? path}) {
    if (workspaces == null || _workspace.moveUnsupported) {
      return WorkspaceMoveBlock.unsupported;
    }
    if (thread.isCanonicalBotChat) return WorkspaceMoveBlock.botChat;
    if (!active ||
        !_threads.contains(thread) ||
        !thread.remote ||
        !_bound.contains(thread)) {
      return WorkspaceMoveBlock.notAvailable;
    }
    // Hermes lets a live agent follow a move, even mid-turn, so nothing may
    // be running or about to run: a reply, a turn of another client, queued
    // prompts, a queue waiting on a settle report, an undo or branch.
    if (thread.isReplying ||
        _sending.containsKey(thread) ||
        _active.contains(thread.id) ||
        (_queues[thread]?.isNotEmpty ?? false) ||
        _settleTimers.containsKey(thread) ||
        queueBusy(thread) ||
        _undoing.containsKey(thread)) {
      return WorkspaceMoveBlock.replying;
    }
    if (_moveStateImpl(thread).inFlight) return WorkspaceMoveBlock.moving;
    if (path != null && !isServerPath(path)) {
      return WorkspaceMoveBlock.notAServerPath;
    }
    return null;
  }

  /// Whether a move of [thread] is being settled: nothing is sent to it then.
  bool _moveHolds(ChatThread? thread) =>
      thread != null && _moveStateImpl(thread).inFlight;

  void _setMove(
    (String, String) key,
    _MoveRecord record,
    WorkspaceMoveState state,
  ) {
    final wasInFlight = record.state.inFlight;
    final before = record.state.phase;
    record.state = state;
    if (disposed) return;
    // How a move ended, as a fixed name: never the folder.
    final outcome = switch (state.phase) {
      WorkspaceMovePhase.changed => 'changed',
      WorkspaceMovePhase.unchanged => 'unchanged',
      WorkspaceMovePhase.couldNotConfirm => 'could_not_confirm',
      WorkspaceMovePhase.folderMissing => 'folder_missing',
      WorkspaceMovePhase.chatGone => 'chat_gone',
      WorkspaceMovePhase.profileGone => 'profile_gone',
      _ => null,
    };
    if (outcome != null && before != state.phase) {
      events('workspace.move_outcome', {'outcome': outcome});
    }
    notifyListeners();
    if (!wasInFlight || state.inFlight) return;
    // Whatever waited for the move goes on.
    final thread = _threadFor(key);
    if (thread != null && active && _queues[thread] != null) {
      _drainQueue(thread);
    }
  }

  /// The wait for a move or a re-read ended without anything to apply, as
  /// when the app went to the background meanwhile: nothing is known.
  void _unconfirmed((String, String) key, _MoveRecord record) {
    if (!record.state.inFlight) return;
    _setMove(
      key,
      record,
      const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
    );
  }

  /// The result of [call], or null when it has had no answer within the
  /// time a waiting state may last. [call] is not cancelled: its answer, when
  /// it comes, is still [call]'s.
  Future<WorkspacesResult<T>?> _within<T>(Future<WorkspacesResult<T>> call) {
    final repository = workspaces!;
    return call
        .then<WorkspacesResult<T>?>((result) => result)
        .timeout(repository.timeout, onTimeout: () => null);
  }

  Future<WorkspaceMoveBlock?> _moveWorkspaceImpl(
    ChatThread thread,
    String path,
  ) async {
    // Checked here again, when the person confirms: a reply that started
    // since the picker opened sends nothing.
    final block = _moveBlockImpl(thread, path: path);
    if (block != null) return block;
    final repository = workspaces!;
    final epoch = _activityEpoch;
    final profile = _profile;
    final key = _moveKey(thread);
    breadcrumbs('workspace.move.confirmed');
    final record = _workspace.moves.putIfAbsent(key, _MoveRecord.new);
    final run = ++record.moveRun;
    record
      ..target = path
      ..previous = thread.workingDirectory;
    _setMove(key, record, const WorkspaceMoveState(WorkspaceMovePhase.moving));
    // Sent once. Whatever comes of it, it is never sent again.
    final request = repository.moveWorkspace(key.$2, path, profile: profile);
    final answer = await _within(request);
    if (disposed || record.moveRun != run) return null;
    if (!_currentActivity(epoch)) {
      _unconfirmed(key, record);
      return null;
    }
    switch (answer) {
      case WorkspacesOk(:final value):
        _applyMoved(key, record, value);
      case WorkspacesUnsupported():
        _workspace.moveUnsupported = true;
        _workspace.moves.remove(key);
        events('workspace.move_outcome', {'outcome': 'unsupported'});
        notifyListeners();
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.notFound:
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.folderMissing),
        );
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.sessionGone:
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.chatGone),
        );
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.unknownProfile:
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.profileGone),
        );
      case WorkspacesFailed() || null:
        // A lost answer, a server error and anything unclear may still have
        // moved the chat: read it again, and send nothing.
        if (answer == null) {
          unawaited(
            request.then((late) {
              if (disposed || record.moveRun != run || !active) return;
              if (late is WorkspacesOk<MovedWorkspace> &&
                  _lateAnswerMayApply(record)) {
                _applyMoved(key, record, late.value);
              }
            }),
          );
        }
        await _recheck(key, record, epoch, profile, timedOut: answer == null);
    }
    return null;
  }

  /// A move answer that came after its wait ended still decides the screen,
  /// unless it was settled already.
  bool _lateAnswerMayApply(_MoveRecord record) => switch (record.state.phase) {
    WorkspaceMovePhase.checking ||
    WorkspaceMovePhase.couldNotConfirm ||
    WorkspaceMovePhase.unchanged => true,
    _ => false,
  };

  void _applyMoved(
    (String, String) key,
    _MoveRecord record,
    MovedWorkspace moved,
  ) {
    final thread = _threadFor(key);
    if (thread != null) {
      thread
        ..workingDirectory = moved.cwd
        ..branch = moved.branch
        ..folderPath = moved.folderPath;
      _workspace.projects.remove(thread);
      _workspace.mismatches.remove(thread);
    }
    _setMove(
      key,
      record,
      WorkspaceMoveState(WorkspaceMovePhase.changed, folder: moved.cwd),
    );
  }

  Future<void> _recheck(
    (String, String) key,
    _MoveRecord record,
    int epoch,
    String? profile, {
    bool timedOut = false,
  }) async {
    final repository = workspaces!;
    final generation = ++record.readGen;
    _setMove(
      key,
      record,
      WorkspaceMoveState(WorkspaceMovePhase.checking, timedOut: timedOut),
    );
    final read = repository.sessionFolder(key.$2, profile: profile);
    final result = await _within(read);
    if (disposed || record.readGen != generation) return;
    if (!_currentActivity(epoch)) {
      _unconfirmed(key, record);
      return;
    }
    if (result == null) {
      _setMove(
        key,
        record,
        const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
      );
      unawaited(
        read.then((late) {
          if (disposed ||
              !active ||
              record.readGen != generation ||
              record.state.phase != WorkspaceMovePhase.couldNotConfirm) {
            return;
          }
          _settleRead(key, record, late);
        }),
      );
      return;
    }
    _settleRead(key, record, result);
  }

  /// Decides a move from the chat's row. The row says where the chat runs;
  /// what the app expected does not. A move answer that already settled it
  /// is not overruled.
  void _settleRead(
    (String, String) key,
    _MoveRecord record,
    WorkspacesResult<SessionFolder> result,
  ) {
    if (record.state.phase == WorkspaceMovePhase.changed) return;
    final target = record.target;
    switch (result) {
      case WorkspacesOk(:final value):
        final cwd = value.cwd;
        if (cwd == null || target == null) {
          _setMove(
            key,
            record,
            const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
          );
          return;
        }
        if (_movedTo(target, cwd, record.previous)) {
          final thread = _threadFor(key);
          if (thread != null) {
            thread
              ..workingDirectory = cwd
              ..branch = value.branch
              ..folderPath =
                  sessionFolderPath({
                    'git_repo_root': value.gitRepoRoot,
                    'cwd': cwd,
                  }) ??
                  cwd;
            _workspace.projects.remove(thread);
            _workspace.mismatches.remove(thread);
          }
          _setMove(
            key,
            record,
            WorkspaceMoveState(WorkspaceMovePhase.changed, folder: cwd),
          );
        } else {
          _setMove(
            key,
            record,
            const WorkspaceMoveState(WorkspaceMovePhase.unchanged),
          );
        }
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.sessionGone:
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.chatGone),
        );
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.unknownProfile:
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.profileGone),
        );
      case WorkspacesFailed() || WorkspacesUnsupported():
        _setMove(
          key,
          record,
          const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
        );
    }
  }

  /// Whether the row's [cwd] is the folder the move asked for. A `~`-led
  /// target cannot be compared with a resolved path, so then only a change
  /// from the folder the chat had counts.
  bool _movedTo(String target, String cwd, String? previous) {
    final home = _workspace.loaders[_profileKey]?.catalog?.home;
    final tilde =
        target.trim().startsWith('~') && (home == null || home.isEmpty);
    if (tilde) {
      return previous == null || !sameServerFolder(previous, cwd, home: home);
    }
    return sameServerFolder(target, cwd, home: home);
  }

  /// "Check again": reads the chat's row and nothing else. A move answer or
  /// read still on its way is not dropped by it.
  Future<void> _recheckWorkspaceMoveImpl(ChatThread thread) async {
    if (!active || !_threads.contains(thread)) return;
    final key = _moveKey(thread);
    final record = _workspace.moves[key];
    if (record == null ||
        record.state.phase != WorkspaceMovePhase.couldNotConfirm ||
        record.target == null) {
      return;
    }
    await _recheck(key, record, _activityEpoch, _profile);
  }
}
