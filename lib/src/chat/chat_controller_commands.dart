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
      thread.messages
        ..clear()
        ..addAll(page.messages);
      _unloaded.remove(thread.id);
      if (page.hasMore) {
        _olderRows[thread.id] = page.rows;
      } else {
        _olderRows.remove(thread.id);
      }
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
      if (!_currentActivity(epoch)) return;
      notifyListeners();
    } on Object {
      if (_currentActivity(epoch)) {
        report('Command ran, but this chat could not be refreshed.');
      }
    }
  }

  /// The last prompt of [thread], with or without text.
  ChatMessage? _lastPrompt(ChatThread thread) => thread.messages.reversed
      .where((m) => m.role == ChatRole.user)
      .firstOrNull;

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
    final start = thread.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (start < 0) return true;
    thread.messages.removeRange(start, thread.messages.length);
    await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    notifyListeners();
    return true;
  }
}
