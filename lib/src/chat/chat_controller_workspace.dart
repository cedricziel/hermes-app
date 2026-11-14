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
  final moves = <ChatThread, WorkspaceMoveState>{};

  /// The folder each unsettled move asked for and the one the chat had.
  final targets = <ChatThread, ({String path, String? previous})>{};

  /// Which move of a thread the answers in flight belong to.
  final runs = <ChatThread, int>{};
  var runCount = 0;

  /// One catalog per recipient profile, kept while the welcome view shows.
  final loaders = <String, WorkspaceCatalogLoader>{};

  /// Whether the server answered "unknown method" to a move. Kept for the
  /// connection.
  var moveUnsupported = false;

  void clearLoaders() {
    for (final loader in loaders.values) {
      loader.dispose();
    }
    loaders.clear();
  }
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
      ..folderPath = sessionFolderPath({'cwd': event.cwd}) ?? event.cwd;
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

  WorkspaceCatalogLoader? _catalogFor(String? profile) {
    final repository = workspaces;
    if (repository == null || !active) return null;
    final key = profile ?? _profileKey;
    var loader = _workspace.loaders[key];
    if (loader == null) {
      loader = WorkspaceCatalogLoader(repository: repository, profile: key)
        ..addListener(notifyListeners);
      _workspace.loaders[key] = loader;
      unawaited(loader.load());
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
    _workspace.pending = null;
    for (final thread in _threads) {
      if (_isNewChat(thread)) thread.workspaceChoice = null;
    }
    _workspace.clearLoaders();
  }

  void _clearWorkspaceStateImpl() {
    _workspace.pending = null;
    for (final thread in _threads) {
      thread.workspaceChoice = null;
    }
    _workspace
      ..sent.clear()
      ..projects.clear()
      ..mismatches.clear()
      ..moves.clear()
      ..targets.clear()
      ..runs.clear()
      ..moveUnsupported = false
      ..clearLoaders();
  }

  // Moving a chat.

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
    if (thread.isReplying || _sending.containsKey(thread)) {
      return WorkspaceMoveBlock.replying;
    }
    if (_moveStateImpl(thread).inFlight) return WorkspaceMoveBlock.moving;
    if (path != null && !isServerPath(path)) {
      return WorkspaceMoveBlock.notAServerPath;
    }
    return null;
  }

  WorkspaceMoveState _moveStateImpl(ChatThread thread) =>
      _workspace.moves[thread] ?? WorkspaceMoveState.idle;

  void _setMove(ChatThread thread, WorkspaceMoveState state) {
    _workspace.moves[thread] = state;
    notifyListeners();
  }

  /// Whether the move of [thread] in [run] is still the one in view: the app
  /// is current, the chat is still in the list and no later move replaced it.
  bool _moveCurrent(ChatThread thread, int run, int epoch) =>
      _currentActivity(epoch) &&
      _threads.contains(thread) &&
      _workspace.runs[thread] == run;

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
    final id = thread.id;
    final run = ++_workspace.runCount;
    _workspace.runs[thread] = run;
    _workspace.targets[thread] = (
      path: path,
      previous: thread.workingDirectory,
    );
    _setMove(thread, const WorkspaceMoveState(WorkspaceMovePhase.moving));
    // Sent once. Whatever comes of it, it is never sent again.
    final request = repository.moveWorkspace(id, path, profile: profile);
    final answer = await _within(request);
    if (!_moveCurrent(thread, run, epoch)) return null;
    switch (answer) {
      case WorkspacesOk(:final value):
        _applyMoved(thread, value);
      case WorkspacesUnsupported():
        _workspace
          ..moveUnsupported = true
          ..moves.remove(thread)
          ..targets.remove(thread);
        notifyListeners();
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.notFound:
        _setMove(
          thread,
          const WorkspaceMoveState(WorkspaceMovePhase.folderMissing),
        );
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.sessionGone:
        _setMove(thread, const WorkspaceMoveState(WorkspaceMovePhase.chatGone));
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.unknownProfile:
        _setMove(
          thread,
          const WorkspaceMoveState(WorkspaceMovePhase.profileGone),
        );
      case WorkspacesFailed() || null:
        // A lost answer, a server error and anything unclear may still have
        // moved the chat: read it again, and send nothing.
        if (answer == null) {
          unawaited(
            request.then((late) {
              if (!_moveCurrent(thread, run, epoch)) return;
              if (late is WorkspacesOk<MovedWorkspace> &&
                  _lateAnswerMayApply(thread)) {
                _applyMoved(thread, late.value);
              }
            }),
          );
        }
        await _recheck(thread, run, epoch, profile);
    }
    return null;
  }

  /// A move answer that came after its wait ended still decides the screen,
  /// unless the chat's row already settled it.
  bool _lateAnswerMayApply(ChatThread thread) =>
      switch (_moveStateImpl(thread).phase) {
        WorkspaceMovePhase.checking ||
        WorkspaceMovePhase.couldNotConfirm ||
        WorkspaceMovePhase.unchanged => true,
        _ => false,
      };

  void _applyMoved(ChatThread thread, MovedWorkspace moved) {
    thread
      ..workingDirectory = moved.cwd
      ..branch = moved.branch
      ..folderPath = moved.folderPath;
    _workspace.projects.remove(thread);
    _workspace.targets.remove(thread);
    _setMove(
      thread,
      WorkspaceMoveState(WorkspaceMovePhase.changed, folder: moved.cwd),
    );
  }

  Future<void> _recheck(
    ChatThread thread,
    int run,
    int epoch,
    String? profile,
  ) async {
    final repository = workspaces!;
    _setMove(thread, const WorkspaceMoveState(WorkspaceMovePhase.checking));
    final read = repository.sessionFolder(thread.id, profile: profile);
    final result = await _within(read);
    if (!_moveCurrent(thread, run, epoch)) return;
    if (result == null) {
      _setMove(
        thread,
        const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
      );
      unawaited(
        read.then((late) {
          if (!_moveCurrent(thread, run, epoch)) return;
          if (_moveStateImpl(thread).phase !=
              WorkspaceMovePhase.couldNotConfirm) {
            return;
          }
          _settleRead(thread, late);
        }),
      );
      return;
    }
    _settleRead(thread, result);
  }

  /// Decides a move from the chat's row. The row says where the chat runs;
  /// what the app expected does not.
  void _settleRead(ChatThread thread, WorkspacesResult<SessionFolder> result) {
    final target = _workspace.targets[thread];
    switch (result) {
      case WorkspacesOk(:final value):
        final cwd = value.cwd;
        if (cwd == null || target == null) {
          _setMove(
            thread,
            const WorkspaceMoveState(WorkspaceMovePhase.couldNotConfirm),
          );
          return;
        }
        if (_movedTo(target.path, cwd, target.previous)) {
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
          _workspace.targets.remove(thread);
          _setMove(
            thread,
            WorkspaceMoveState(WorkspaceMovePhase.changed, folder: cwd),
          );
        } else {
          _setMove(
            thread,
            const WorkspaceMoveState(WorkspaceMovePhase.unchanged),
          );
        }
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.sessionGone:
        _setMove(thread, const WorkspaceMoveState(WorkspaceMovePhase.chatGone));
      case WorkspacesFailed(:final kind)
          when kind == WorkspacesFailure.unknownProfile:
        _setMove(
          thread,
          const WorkspaceMoveState(WorkspaceMovePhase.profileGone),
        );
      case WorkspacesFailed() || WorkspacesUnsupported():
        _setMove(
          thread,
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

  /// "Check again": reads the chat's row and nothing else.
  Future<void> _recheckWorkspaceMoveImpl(ChatThread thread) async {
    if (!active || !_threads.contains(thread)) return;
    final state = _moveStateImpl(thread);
    if (state.phase != WorkspaceMovePhase.couldNotConfirm) return;
    if (_workspace.targets[thread] == null) return;
    final run = ++_workspace.runCount;
    _workspace.runs[thread] = run;
    await _recheck(thread, run, _activityEpoch, _profile);
  }
}
