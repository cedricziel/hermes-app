part of 'chat_controller.dart';

/// Slash commands and retry/edit actions for the last prompt.
extension _ChatControllerCommands on ChatController {
  Future<List<SlashCommand>> _slashCommandsImpl() async {
    if (!active) return const [];
    final epoch = _activityEpoch;
    try {
      final commands = await transport?.slashCommands(
        threadId: selectedThread?.remote == true ? selectedThread!.id : null,
        profile: _profile,
      );
      return _currentActivity(epoch) ? commands ?? const [] : const [];
    } on Object {
      if (!_currentActivity(epoch)) return const [];
      rethrow;
    }
  }

  /// Runs a gateway command without putting it through prompt.submit or the
  /// reply queue. Display-only command output stays in this visit's chat.
  Future<bool> _runSlashCommandImpl(String command) async {
    if (_ChatControllerCheckpoints(this)._actionHolds(selectedThread)) {
      report('Wait for the files to be restored, then try again.');
      return false;
    }
    if (_sessionStates[selectedThread]?.reclaimedReason != null) {
      report('Reopen this session before running another command.');
      return false;
    }
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return false;
    final bot = selectedThread?.botContext;
    if (bot != null &&
        RegExp(r'^/(?:title|rename)(?:\s|$)').hasMatch(command.trim())) {
      report(
        'Bot Chat keeps its canonical title. Edit the bot name in the roster.',
      );
      return false;
    }
    final compacting =
        bot != null && {'/new', '/reset'}.contains(command.trim());
    if (compacting) command = '/compress';
    if (command == '/new') {
      newThread();
      return true;
    }
    final transport = this.transport;
    if (transport == null) return false;
    final selected = selectedThread;
    if (selected != null && !selected.remote && selected.isReplying) {
      report('Wait for this chat to open before running a command.');
      return false;
    }
    final wasRemote = selected?.remote == true;
    final profile = _profile;
    try {
      final result = await transport.runSlashCommand(
        threadId: wasRemote ? selected!.id : null,
        profile: profile,
        command: command,
      );
      if (!_currentActivity(epoch)) return false;
      if (_profile != profile) return true;
      final thread =
          selected ??
          ChatThread(
            id: result.threadId,
            title: command,
            updatedAt: DateTime.now(),
            remote: true,
            modelChoice: _newChatModel,
          );
      if (selected == null) {
        // The command made the session without the pick for the next chat.
        _workspace.pending = null;
        _threads.insert(0, thread);
        _selectedId ??= thread.id;
      } else if (!selected.remote) {
        _bindThread(selected, result.threadId);
      }
      _bound.add(thread);
      if (compacting && botChats != null) {
        final BotModeChat canonical;
        try {
          canonical = await botChats!.open(bot.bot);
        } on Object {
          if (_currentActivity(epoch)) {
            report('Bot Chat was compacted. Reopen the bot to continue.');
          }
          return true;
        }
        if (!_currentActivity(epoch) || _profile != profile) return true;
        if (canonical.storedId != thread.id) {
          _retargetBoundThread(thread, canonical.storedId);
        }
        thread.botContext = bot.withStoredId(canonical.storedId);
        await _refreshAfterSlash(thread, profile);
      }
      if (result.prefill != null && wasRemote) {
        await _refreshAfterSlash(thread, profile);
      }
      if (!_currentActivity(epoch)) return false;
      void append(ChatRole role, String content) {
        if (content.isEmpty) return;
        final message = ChatMessage(
          id: _newMessageId(thread),
          role: role,
          content: content,
          createdAt: DateTime.now(),
        );
        thread.messages.add(message);
        for (final flyer in chatMessageToFlyer(message)) {
          controllerFor(thread).insertMessage(flyer);
        }
      }

      append(ChatRole.user, command);
      append(ChatRole.assistant, result.output);
      thread.updatedAt = DateTime.now();
      notifyListeners();
      if (!_currentActivity(epoch)) return false;
      if (result.prefill case final draft?) onPrefill?.call(draft);
      if (!_currentActivity(epoch)) return false;
      if (result.prompt case final prompt? when prompt.isNotEmpty) {
        await _submitTo(
          thread,
          prompt,
          const [],
          displayText: result.display ?? command,
        );
      }
      return true;
    } on Object catch (error) {
      if (_currentActivity(epoch)) report('Could not run $command: $error');
      return false;
    }
  }

  Future<void> _refreshAfterSlash(ChatThread thread, String? profile) async {
    final epoch = _activityEpoch;
    final repository = this.repository;
    if (repository == null) return;
    if (!_currentActivity(epoch)) return;
    await _loadingMessages[thread.id];
    if (!_currentActivity(epoch)) return;
    try {
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
      );
      if (!_currentActivity(epoch) ||
          _profile != profile ||
          !_threads.contains(thread)) {
        return;
      }
      final kept = _heldAfterRefresh(thread, page);
      thread.messages
        ..clear()
        ..addAll(_mergedWithPage(kept, thread.id, page.messages));
      _reactionHistory(thread);
      _unloaded.remove(thread.id);
      if (page.hasMore) {
        _olderRows[thread.id] = page.rows;
      } else {
        _olderRows.remove(thread.id);
      }
      await controllerFor(thread)
          .setMessages(_ChatControllerCheckpoints(this)._flyerOf(thread));
      if (!_currentActivity(epoch)) return;
      notifyListeners();
    } on Object {
      if (_currentActivity(epoch)) {
        report('Command ran, but this chat could not be refreshed.');
      }
    }
  }

  /// What [thread] holds that a command's re-read must not drop: rows only
  /// this app has (command lines) and turns sent here, which may still be
  /// streaming. Rows read from Hermes are left to [page], the truth after
  /// the command, which may have undone some. A settled turn is dropped when
  /// the page does not hold its stored row (undone, or older than the page,
  /// which loading older messages brings back in place), or, without a receipt, when the page
  /// holds a prompt with the same words.
  List<ChatMessage> _heldAfterRefresh(ChatThread thread, MessagePage page) {
    final stored = {for (final m in page.messages) m.id};
    final storedPrompts = {
      for (final m in page.messages)
        if (m.role == ChatRole.user) m.content,
    };
    final kept = <ChatMessage>[];
    for (final turn in _turns([
      for (final m in thread.messages)
        if (m.id.contains('-local-')) m,
    ], stored: false)) {
      final first = turn.first;
      final settled = !turn.any((m) => m.isPending);
      final row = first.canonicalRow?.rowId;
      final gone = !settled
          ? false
          : row != null
          ? !stored.contains('${thread.id}-$row')
          : first.role == ChatRole.user &&
                !turn.any((m) => m.status == MessageStatus.error) &&
                storedPrompts.contains(first.content);
      if (!gone) kept.addAll(turn);
    }
    return kept;
  }

  /// The last prompt of [thread], with or without text. A note Hermes wrote
  /// as a user row, such as the one that resumes an interrupted turn, is not
  /// one: Hermes does not undo it as a turn, and sending it again would run
  /// that turn again.
  ChatMessage? _lastPrompt(ChatThread thread) =>
      thread.messages.reversed.where((m) => m.isPrompt).firstOrNull;

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? _lastPromptTextImpl(ChatThread thread) {
    final message = _lastPrompt(thread);
    if (message == null) return null;
    final text = message.submittedText ?? message.content;
    return text.isEmpty ? null : text;
  }

  /// Whether the last prompt of [thread] can be taken back on the server:
  /// edited, or sent again in place of its turn.
  bool _canEditLastPromptImpl(ChatThread thread) {
    if (!active || _sessionStates[thread]?.reclaimedReason != null) {
      return false;
    }
    final prompt = lastPromptText(thread);
    return transport != null &&
        _bound.contains(thread) &&
        !_undoing.containsKey(thread) &&
        !_ChatControllerCheckpoints(this)._actionHolds(thread) &&
        !thread.isReplying &&
        !_queues.containsKey(thread) &&
        prompt != null &&
        !prompt.startsWith('/');
  }

  /// Sends the text of the last prompt again. The server drops the turn it
  /// replaces first, so the model does not see that reply again. A command, a
  /// prompt that had files (they are not sent again) and a server that cannot
  /// undo get a new turn instead.
  Future<void> _retryImpl(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    // A full restore is rewinding the chat: another undo would take a second
    // turn.
    if (_ChatControllerCheckpoints(this)._actionHolds(thread)) return;
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation)) {
      return;
    }
    final prompt = lastPromptText(thread);
    if (prompt == null || _undoing.containsKey(thread)) return;
    if (prompt.startsWith('/')) {
      unawaited(runSlashCommand(prompt));
      return;
    }
    if (canEditLastPrompt(thread) && _lastPrompt(thread)!.attachments.isEmpty) {
      try {
        await _undoLastTurn(thread, TurnAction.retry);
      } on Object catch (error) {
        if (_currentActivity(epoch) &&
            _sessionActionCurrent(thread, generation)) {
          _failTurnAction(thread, error, 'try again');
        }
        return;
      }
      if (!_currentActivity(epoch) ||
          !_sessionActionCurrent(thread, generation)) {
        return;
      }
    }
    await _submitTo(thread, prompt, const []);
  }

  /// Takes the last prompt of [thread] back on the server and puts its text
  /// in the composer. Its files are not put back.
  Future<void> _editLastPromptImpl(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    final prompt = lastPromptText(thread);
    if (prompt == null || !canEditLastPrompt(thread)) return;
    final bool undone;
    try {
      undone = await _undoLastTurn(thread, TurnAction.edit);
    } on Object catch (error) {
      if (_currentActivity(epoch) &&
          _sessionActionCurrent(thread, generation)) {
        _failTurnAction(thread, error, 'edit the prompt');
      }
      return;
    }
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    if (!undone) {
      report("This Hermes server can't edit prompts. Update Hermes to edit.");
      return;
    }
    onPrefill?.call(prompt);
  }

  /// Whether [thread] can be copied into a new chat now: the server knows it
  /// and nothing runs in it.
  bool _canBranchImpl(ChatThread thread) =>
      active &&
      transport != null &&
      _bound.contains(thread) &&
      _sessionStates[thread]?.reclaimedReason == null &&
      !_undoing.containsKey(thread) &&
      !_ChatControllerCheckpoints(this)._actionHolds(thread) &&
      !thread.isReplying &&
      !_queues.containsKey(thread);

  /// How many prompts Hermes holds after the message the flyer id [messageId]
  /// belongs to, or null when [thread] has no such message. A command shown
  /// only here and a prompt that failed are not Hermes' prompts.
  int? _promptsAfter(ChatThread thread, String messageId) {
    final index = thread.messages.lastIndexWhere(
      (m) => m.id == messageId || messageId.startsWith('${m.id}-'),
    );
    if (index < 0) return null;
    return thread.messages
        .skip(index + 1)
        .where(
          (m) =>
              m.role == ChatRole.user &&
              m.status != MessageStatus.error &&
              // A command run in this visit shows its text but was never a
              // prompt; a stored row is one whatever it starts with.
              (!m.id.contains('-local-') ||
                  m.submittedText != null ||
                  !m.content.startsWith('/')),
        )
        .length;
  }

  /// Copies [thread] into a new chat, up to and including the turn of the
  /// message [fromMessageId] (a flyer id), or all of it when null, and opens
  /// the copy.
  Future<void> _branchImpl(ChatThread thread, {String? fromMessageId}) async {
    if (!canBranch(thread)) {
      // The Mac thread menu offers it for any chat of the list.
      if (active && transport != null && thread.isReplying) {
        report('Wait for the reply to finish, then branch the chat.');
      }
      return;
    }
    final dropTurns = fromMessageId == null
        ? 0
        : _promptsAfter(thread, fromMessageId);
    if (dropTurns == null) return;
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    final profile = _profile;
    final from = fromMessageId == null || dropTurns == 0 ? 'end' : 'message';
    _undoing[thread] = TurnAction.branch;
    _turnProblems.remove(thread);
    notifyListeners();
    BranchedThread? branch;
    Object? failure;
    try {
      branch = await transport!.branchThread(
        thread.id,
        profile: profile,
        dropTurns: dropTurns,
      );
    } on BranchIncomplete catch (error) {
      failure = error.cause;
      // The copy holds turns it should not; it is not what was asked for.
      unawaited(
        repository
            ?.deleteThread(error.thread.id, profile: profile)
            .catchError((Object _) {}),
      );
    } on Object catch (error) {
      failure = error;
    } finally {
      if (_currentActivity(epoch) &&
          _sessionActionCurrent(thread, generation)) {
        _undoing.remove(thread);
        notifyListeners();
      }
    }
    if (!_currentActivity(epoch) || _profile != profile) return;
    if (failure != null) {
      breadcrumbs('chat.branch', {'outcome': 'failed', 'from': from});
      // Hermes refused, or answered what the app cannot use.
      final answered =
          failure is GatewayRpcException ||
          failure is FormatException ||
          failure is StateError;
      final problem = answered
          ? "Hermes couldn't branch the chat."
          : "Couldn't reach Hermes to branch the chat. Check your connection.";
      // Said under the chat's last reply when it is open, else as a note.
      if (selectedThread != thread) {
        report(problem);
      } else if (_sessionActionCurrent(thread, generation)) {
        _turnProblems[thread] = problem;
        notifyListeners();
      }
      return;
    }
    if (branch == null) {
      breadcrumbs('chat.branch', {'outcome': 'unsupported', 'from': from});
      report("This Hermes server can't branch chats. Update Hermes to branch.");
      return;
    }
    breadcrumbs('chat.branch', {'outcome': 'branched', 'from': from});
    // Not in the loaded list yet: opening fetches it and puts it on top.
    open(
      NotificationTarget(threadId: branch.id, profile: profile),
      fetchMissing: true,
    );
  }

  /// Says under the last reply why taking back its turn failed. The error
  /// itself is meant for developers, so only its kind goes to the crumb.
  void _failTurnAction(ChatThread thread, Object error, String action) {
    final rejected = error is GatewayRpcException;
    breadcrumbs('chat.undo.failed', {
      'cause': rejected ? 'rejected' : 'unreachable',
    });
    _turnProblems[thread] = rejected
        ? "Hermes couldn't $action."
        : "Couldn't reach Hermes to $action. Check your connection.";
    notifyListeners();
  }

  /// The retry or edit running on the last turn of [thread], or why the last
  /// one failed.
  TurnActionStatus _turnActionStatusImpl(ChatThread thread) => TurnActionStatus(
    running: _undoing[thread],
    problem: _turnProblems[thread],
  );

  /// Drops the last turn of [thread] on the server and then here. False when
  /// the server cannot undo.
  Future<bool> _undoLastTurn(ChatThread thread, TurnAction action) async {
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    _undoing[thread] = action;
    _turnProblems.remove(thread);
    notifyListeners();
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    final int? removed;
    try {
      removed = await transport!.undoLastTurn(
        thread.id,
        profile: _profile,
        retry: action == TurnAction.retry,
      );
    } finally {
      if (_currentActivity(epoch) &&
          _sessionActionCurrent(thread, generation)) {
        _undoing.remove(thread);
        notifyListeners();
      }
    }
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    if (removed == null) return false;
    final start = thread.messages.lastIndexWhere((m) => m.isPrompt);
    if (start < 0) return true;
    thread.messages.removeRange(start, thread.messages.length);
    await controllerFor(thread)
        .setMessages(_ChatControllerCheckpoints(this)._flyerOf(thread));
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    notifyListeners();
    return true;
  }
}
