part of 'chat_controller.dart';

/// Thread loading, message pagination, and history reconciliation.
extension _ChatControllerHistory on ChatController {
  Future<void> _loadThreads(
    String? profile, {
    bool Function()? valid,
    bool preserveSelection = false,
  }) async {
    if (!active) return;
    var previousSelection = _selectedId;
    final previousProfile = _profile;
    final originalLocal = preserveSelection
        ? _threads.where((thread) => !thread.remote).toList()
        : const <ChatThread>[];
    final interruptedLocalReplies = {
      for (final thread in originalLocal)
        if (!_sending.containsKey(thread))
          thread: thread.messages.where((message) => message.isPending).toSet(),
    };
    final sendingAtStart = _threads.where(_sending.containsKey).toSet();
    final generation = ++_loadGeneration;
    // A send that is running stays current while this read is in flight; the
    // commit keeps or drops its thread.
    for (final thread in sendingAtStart) {
      _protectedSends[thread]?.carriedGeneration = generation;
    }
    // This load reads the list itself.
    _listRefreshPending = false;
    _loadingThreads = true;
    _threadsFailed = false;
    notifyListeners();
    try {
      if (!active || generation != _loadGeneration) return;
      profile ??= await _activeProfile();
      if (!active || generation != _loadGeneration) return;
      _failedListProfile = profile;
      final first = await repository!.loadThreadPage(profile: profile);
      if (!active || generation != _loadGeneration) return;
      final firstIds = {for (final thread in first.threads) thread.id};
      var launched = await _attention.takeLaunchTarget();
      if (!active || generation != _loadGeneration) return;
      if (launched != null && onLaunchNotification != null) {
        onLaunchNotification!(launched);
        launched = null;
      }
      if (launched != null && launched.isJob) {
        onOpenJob?.call(launched);
        launched = null;
      }
      if (launched != null && launched.prompt != null) {
        onOpenNewChat?.call(launched);
        launched = null;
      }
      if (!active || generation != _loadGeneration) return;
      if (valid?.call() == false) {
        _loadingThreads = false;
        notifyListeners();
        return;
      }
      final recoveredQueues = <({ChatThread source, ChatThread recovered})>[];
      final recoveredSources = <ChatThread>{};
      while (preserveSelection) {
        final candidates = _queues.keys
            .where(
              (thread) =>
                  thread.remote &&
                  !(profile != previousProfile &&
                      (_queues[thread]?.any(
                            (prompt) => prompt.durable != null,
                          ) ??
                          false)) &&
                  !recoveredSources.contains(thread) &&
                  (profile != previousProfile ||
                      !_sending.containsKey(thread) &&
                          !firstIds.contains(thread.id)),
            )
            .toList();
        if (candidates.isEmpty) break;
        recoveredSources.addAll(candidates);
        final recovered = await Future.wait([
          for (final thread in candidates)
            () async {
              final recovered = profile == previousProfile
                  ? await _recoverQueuedThread(thread, profile)
                  : _queuedDraft(thread, newId: true);
              return (source: thread, recovered: recovered);
            }(),
        ]);
        if (!active || generation != _loadGeneration) return;
        recoveredQueues.addAll(recovered);
      }
      if (!active || generation != _loadGeneration) return;
      if (valid?.call() == false) {
        _loadingThreads = false;
        notifyListeners();
        return;
      }
      // A list read again for the profile in view must not drop the turn
      // that is running in it.
      final sameProfile = profile == previousProfile;
      final local = preserveSelection
          ? _threads.where((thread) => !thread.remote).toList()
          : sameProfile
          ? _threads
                .where(
                  (thread) =>
                      !thread.remote &&
                      (_sending.containsKey(thread) ||
                          sendingAtStart.contains(thread)),
                )
                .toList()
          : const <ChatThread>[];
      final live = sameProfile
          ? _threads
                .where(
                  (thread) =>
                      thread.remote &&
                      (_sending.containsKey(thread) ||
                          sendingAtStart.contains(thread)),
                )
                .toList()
          : const <ChatThread>[];
      final liveIds = {for (final thread in live) thread.id};
      final kept = {...live, ...local};
      final currentRecoveries = recoveredQueues
          .where(
            (entry) =>
                _queues.containsKey(entry.source) &&
                (profile != previousProfile ||
                    !_sending.containsKey(entry.source)),
          )
          .toList();
      final retainedQueues = preserveSelection
          ? {
              for (final entry in _queues.entries)
                if (profile == previousProfile ||
                    !entry.value.any((prompt) => prompt.durable != null))
                  entry.key.id: entry.value,
            }
          : {
              for (final entry in _queues.entries)
                if (live.contains(entry.key) || local.contains(entry.key))
                  entry.key.id: entry.value,
            };
      if (preserveSelection) previousSelection = _selectedId;
      for (final (:source, :recovered) in currentRecoveries) {
        if (source.id == recovered.id) continue;
        retainedQueues[recovered.id] = retainedQueues.remove(source.id)!;
        if (previousSelection == source.id) previousSelection = recovered.id;
      }
      final held = _pendingTap;
      final fetchHeld = held != null && _pendingFetch;
      final launch = held ?? launched;
      final heldPrompt = _pendingTapPrompt;
      final requestedOpening = _requestedOpening;
      _pendingTap = null;
      _pendingFetch = false;
      _pendingTapPrompt = null;
      final threads = housekeeping!.begin(
        ThreadPage(
          threads: [
            ...live,
            for (final thread in first.threads)
              if (!liveIds.contains(thread.id)) thread,
            for (final entry in currentRecoveries) entry.recovered,
          ],
          nextOffset: first.nextOffset,
          hasMore: first.hasMore,
        ),
      );
      // Another profile can hold a different session under the same id.
      final keptState = (
        sessions: {for (final t in kept) t: ?_sessionStates[t]},
        actions: {for (final t in kept) t: ?_sessionActionGenerations[t]},
      );
      _stopFollowing();
      _sessionStates.addAll(keptState.sessions);
      _sessionActionGenerations.addAll(keptState.actions);
      _active.clear();
      for (final controller in _chatControllers.values) {
        controller.dispose();
      }
      _chatControllers.clear();
      final switched = profile != _profile;
      if (switched) {
        _modelOptions = null;
        _newChatModel = null;
        _ChatControllerWorkspace(this)._workspaceProfileSwitched();
        search?.clear();
      }
      _carryReplies();
      for (final entry in interruptedLocalReplies.entries) {
        entry.key.messages.removeWhere(
          (message) => message.isPending && entry.value.contains(message),
        );
      }
      if (switched) _ChatControllerSubagents(this)._clearSubagents();
      _profile = profile;
      breadcrumbs('chat.threads.loaded', {
        'switched': switched,
        'count': threads.length,
      });
      unawaited(_loadModelOptions(profile, generation, notifyLoading: false));
      _threads = [...local, ...threads];
      _unloaded
        ..clear()
        ..addAll(
          threads
              .where((t) => t.remote && !liveIds.contains(t.id))
              .map((t) => t.id),
        )
        // A first page cut off by this read is read again.
        ..addAll(live.map((t) => t.id).where(_loadingMessages.containsKey));
      final keptOlder = {for (final t in kept) t.id: ?_olderRows[t.id]};
      _olderRows
        ..clear()
        ..addAll(keptOlder);
      // What a kept thread's turn and queue stand on carries over; the rest
      // is rebuilt for the list that was just read.
      bool inKept(ChatThread t) => kept.contains(t);
      final carried = (
        loaded: _loadedQueues.where(inKept).toSet(),
        restored: _restoredQueues.where(inKept).toSet(),
        suspended: _suspendedQueues.where(inKept).toSet(),
        ready: _queueTurnReady.where(inKept).toSet(),
        settled: _queueSettled.where(inKept).toSet(),
        restoring: {
          for (final e in _queueRestoring.entries)
            if (inKept(e.key)) e.key: e.value,
        },
      );
      _loadedQueues
        ..clear()
        ..addAll(carried.loaded);
      _restoredQueues
        ..clear()
        ..addAll(carried.restored);
      _queueEpoch++;
      _queueRestoring
        ..clear()
        ..addAll(carried.restoring);
      _queueTurnReady
        ..clear()
        ..addAll(carried.ready);
      _queueSettled
        ..clear()
        ..addAll(carried.settled);
      _queues
        ..clear()
        ..addAll({
          for (final thread in _threads) thread: ?retainedQueues[thread.id],
        });
      _restoredQueues.addAll(
        _queues.keys.where(
          (thread) =>
              !inKept(thread) &&
              _queues[thread]!.any((prompt) => prompt.durable != null),
        ),
      );
      _suspendedQueues
        ..clear()
        ..addAll(_queues.keys.where((t) => !inKept(t)))
        ..addAll(carried.suspended);
      _cancelSettleWaits(except: kept);
      for (final thread in kept) {
        if (_protectedSends[thread] case final send?) {
          send
            ..epoch = _queueEpoch
            ..carriedGeneration = _loadGeneration;
        }
      }
      _bound
        ..clear()
        ..addAll(threads.where((thread) => thread.remote));
      _loadingThreads = false;
      _touched.clear();
      final launchedThread = ChatController._isOnProfile(launch, profile)
          ? threads.where((t) => t.id == launch!.threadId).firstOrNull
          : null;
      _selectedId =
          launchedThread?.id ??
          ((preserveSelection ||
                      live.any((t) => t.id == previousSelection) ||
                      local.any((t) => t.id == previousSelection)) &&
                  _threads.any((t) => t.id == previousSelection)
              ? previousSelection
              : null);
      if (launchedThread != null) _markRead(launchedThread);
      if (preserveSelection &&
          previousSelection != null &&
          _selectedId == null &&
          profile == previousProfile) {
        _opening = _openMissing(
          NotificationTarget(threadId: previousSelection, profile: profile),
        );
      }
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      _reportSurface(SurfaceTrigger.threads);
      if (!active || generation != _loadGeneration) return;
      if (launch != null) {
        // A held tap already put Chat in front when it arrived.
        if (held == null) onShowChat?.call();
        if (!active || generation != _loadGeneration) return;
        if (_selectedId != launch.threadId) {
          if (fetchHeld) {
            _opening = _openMissing(
              launch,
              prompt: heldPrompt,
            ).whenComplete(() => _finishOpening(requestedOpening));
          } else {
            _failOpen();
            _finishOpening(requestedOpening);
          }
        } else if (heldPrompt != null) {
          onDraft?.call(heldPrompt);
          _finishOpening(requestedOpening);
        } else {
          _finishOpening(requestedOpening);
        }
      }
      if (!active || generation != _loadGeneration) return;
      if (_selectedId != null) {
        final selected = _threads.firstWhere((t) => t.id == _selectedId);
        unawaited(
          (selected.remote ? _loadMessages(selected.id) : Future<void>.value())
              .then((_) {
                if (active &&
                    generation == _loadGeneration &&
                    _profile == profile &&
                    _selectedId == selected.id &&
                    _threads.contains(selected)) {
                  _pickUp(selected);
                }
              }),
        );
      }
      unawaited(refreshActive());
    } on Object {
      if (!active || generation != _loadGeneration) return;
      _loadingThreads = false;
      _threadsFailed = true;
      breadcrumbs('chat.threads.failed');
      notifyListeners();
    }
  }

  /// The sticky active profile, or null when the server has none to report:
  /// no repository, or a server without the profiles route (404). Any other
  /// failure throws, so the caller does not list or send unscoped.
  Future<String?> _activeProfile() async {
    try {
      return (await profiles?.loadActive())?.active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _loadModelOptions(
    String? profile,
    int generation, {
    bool notifyLoading = true,
  }) async {
    if (!active) return;
    final models = this.models;
    if (models == null) return;
    final request = ++_modelOptionsGeneration;
    _modelOptionsState = ModelOptionsState.loading;
    if (notifyLoading) notifyListeners();
    if (!active ||
        generation != _loadGeneration ||
        request != _modelOptionsGeneration ||
        profile != _profile) {
      return;
    }
    ModelOptions? options;
    var state = ModelOptionsState.failed;
    try {
      options = await models.load(profile: profile);
      state = options.providers.isEmpty
          ? ModelOptionsState.incomplete
          : ModelOptionsState.ready;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        state = ModelOptionsState.unsupported;
      }
    } on Object {
      state = ModelOptionsState.failed;
    }
    if (!active ||
        generation != _loadGeneration ||
        request != _modelOptionsGeneration ||
        profile != _profile) {
      return;
    }
    if (options != null) _modelOptions = options;
    _modelOptionsState = state;
    notifyListeners();
  }

  Future<void> _loadMessages(String id) {
    if (!active || !_unloaded.remove(id)) return Future.value();
    final load = _readFirstPage(id);
    _loadingMessages[id] = load;
    return load.whenComplete(() {
      if (identical(_loadingMessages[id], load)) _loadingMessages.remove(id);
    });
  }

  Future<void> _readFirstPage(String id) async {
    final generation = _loadGeneration;
    final reading = _threads.where((t) => t.id == id).firstOrNull;
    try {
      final page = await repository!.loadMessagePage(id, profile: _profile);
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return _readAgainUnderNewId(reading, id);
      final merged = _mergedWithPage(thread.messages, id, page.messages);
      thread.messages
        ..clear()
        ..addAll(merged);
      _reactionHistory(thread);
      if (page.hasMore) _olderRows[id] = page.rows;
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      if (generation != _loadGeneration) return;
      _unloaded.add(id);
      if (!active) return;
      _readAgainUnderNewId(reading, id);
      report('Could not load this chat');
    }
  }

  /// [thread] was stored under a new session id while its first page was
  /// read under [readId]: the page is read again under the new id.
  void _readAgainUnderNewId(ChatThread? thread, String readId) {
    if (thread == null ||
        thread.id == readId ||
        !_threads.contains(thread) ||
        _loadingMessages.containsKey(thread.id)) {
      return;
    }
    _unloaded.add(thread.id);
    if (_selectedId == thread.id) unawaited(_loadMessages(thread.id));
  }

  /// [page], the newest stored messages of session [sessionId], merged with
  /// [held], the messages the chat already shows because they were sent or
  /// run here while the page was read. History goes above them, and a turn
  /// both hold is shown once.
  ///
  /// A held turn is known to be stored only by its prompt's receipt, the row
  /// id Hermes gave it, which names the same row as the page's message id. A
  /// matched turn keeps the held copy, which may still be streaming or carry
  /// what only this app knows (review notes, a stop), unless it failed here
  /// while Hermes stored an answer: then the stored turn replaces it. A turn
  /// without a receipt, or one the page does not hold, stays as it is, and so
  /// does every row only this app has, such as a command's lines.
  List<ChatMessage> _mergedWithPage(
    List<ChatMessage> held,
    String sessionId,
    List<ChatMessage> page,
  ) {
    if (held.isEmpty) return [...page];
    final ids = {for (final m in held) m.id};
    final pageTurns = _turns([
      for (final m in page)
        if (!ids.contains(m.id)) m,
    ], stored: true);
    final heldTurns = _turns(held, stored: false);
    final byId = {
      for (final (i, turn) in pageTurns.indexed)
        if (turn.first case ChatMessage(role: ChatRole.user, displayKind: null))
          turn.first.id: i,
    };
    final matches = [
      for (final turn in heldTurns)
        switch (turn.first) {
          ChatMessage(role: ChatRole.user, canonicalRow: final row?) =>
            byId['$sessionId-${row.rowId}'],
          _ => null,
        },
    ];
    final matched = matches.nonNulls.toSet();
    final merged = <ChatMessage>[];
    var next = 0;
    void placeUpTo(int end) {
      for (; next < end; next++) {
        if (!matched.contains(next)) merged.addAll(pageTurns[next]);
      }
    }

    // What the page holds before the first turn sent here is older than
    // everything held; what it holds after the last one came from elsewhere
    // meanwhile, and goes before the held rows that follow.
    placeUpTo(matched.isEmpty ? pageTurns.length : matched.reduce(min));
    final last = matches.lastIndexWhere((j) => j != null);
    for (final (i, turn) in heldTurns.indexed) {
      final j = matches[i];
      if (j == null) {
        merged.addAll(turn);
      } else {
        placeUpTo(j);
        if (next <= j) next = j + 1;
        final stored = pageTurns[j];
        final failedHere =
            !turn.any((m) => m.isPending) &&
            turn.any(
              (m) =>
                  m.role == ChatRole.assistant &&
                  m.status == MessageStatus.error,
            );
        final answered = _endsAnswered(stored);
        merged.addAll(failedHere && answered ? stored : turn);
      }
      if (i == last) placeUpTo(pageTurns.length);
    }
    return merged;
  }

  /// Whether a stored [turn] ends on the final answer: an assistant row with
  /// text and no tool calls. A row that only calls tools belongs to a turn
  /// that may still be running.
  bool _endsAnswered(List<ChatMessage> turn) => switch (turn.lastOrNull) {
    final ChatMessage last =>
      last.role == ChatRole.assistant &&
          last.toolCalls.isEmpty &&
          last.content.trim().isNotEmpty,
    null => false,
  };

  /// Replaces the stored copy of [prompt] in [thread], which the page read
  /// while it was sent already held, with [prompt] and its reply: the two are
  /// the same turn, and it stays where Hermes stored it, above what the page
  /// holds after it. A stored row's id ends in its row id, which is unique
  /// across the profile's sessions, so a chat stored under a new id since
  /// still finds it.
  void _dropStoredCopy(ChatThread thread, ChatMessage prompt) {
    final rowId = prompt.canonicalRow?.rowId;
    final messages = thread.messages;
    if (rowId == null || !messages.contains(prompt)) return;
    bool local(ChatMessage m) => m.id.contains('-local-');
    final start = messages.indexWhere(
      (m) => m.role == ChatRole.user && !local(m) && m.id.endsWith('-$rowId'),
    );
    if (start < 0) return;
    var end = start + 1;
    while (end < messages.length &&
        messages[end].role != ChatRole.user &&
        !local(messages[end])) {
      end++;
    }
    final at = messages.indexOf(prompt);
    final held = [
      prompt,
      if (at + 1 < messages.length &&
          messages[at + 1].role == ChatRole.assistant &&
          local(messages[at + 1]))
        messages[at + 1],
    ];
    if (at > start) {
      messages.removeRange(at, at + held.length);
      messages.replaceRange(start, end, held);
    } else {
      messages.removeRange(start, end);
    }
    _reactionHistory(thread);
    notifyListeners();
    unawaited(controllerFor(thread).setMessages(chatThreadToFlyer(thread)));
  }

  /// [messages] split into turns that can be matched: a prompt the user
  /// wrote with the reply after it, or, for [stored] rows, with every
  /// assistant row up to the next user row. Each other row is a turn of its
  /// own and is never matched: a reply streaming in from elsewhere, a note
  /// Hermes wrote as a user row and what followed it.
  List<List<ChatMessage>> _turns(
    List<ChatMessage> messages, {
    required bool stored,
  }) {
    final turns = <List<ChatMessage>>[];
    var open = false;
    for (final m in messages) {
      if (m.role == ChatRole.user) {
        turns.add([m]);
        open = m.displayKind == null || stored;
      } else if (open && (stored || turns.last.length == 1)) {
        turns.last.add(m);
      } else {
        turns.add([m]);
        open = false;
      }
    }
    return turns;
  }

  /// Every message of [thread]: what is loaded, plus the pages the dashboard
  /// holds beyond it. A thread whose messages were never loaded is read
  /// whole; an open one is not read again.
  Future<List<ChatMessage>> _history(
    ChatThread thread, {
    bool Function()? cancelled,
  }) async {
    final epoch = _activityEpoch;
    if (!active) throw StateError("Chat activity suspended");
    final repository = this.repository;
    if (repository == null || !_bound.contains(thread)) return thread.messages;
    await _loadingMessages[thread.id];
    if (!_currentActivity(epoch)) throw StateError("Chat activity suspended");
    final loaded = !_unloaded.contains(thread.id);
    final newest = loaded ? thread.messages : const <ChatMessage>[];
    final held = {for (final m in newest) m.id};
    final pages = [newest];
    final profile = _profile;
    int? offset = loaded ? _olderRows[thread.id] : 0;
    while (offset != null) {
      if (!_currentActivity(epoch) || (cancelled?.call() ?? false)) {
        throw StateError('history cancelled');
      }
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
        offset: offset,
      );
      if (!_currentActivity(epoch)) throw StateError("Chat activity suspended");
      pages.add([
        for (final m in page.messages)
          if (held.add(m.id)) m,
      ]);
      offset = page.hasMore && page.rows > 0 ? offset + page.rows : null;
    }
    return [for (final page in pages.reversed) ...page];
  }

  Future<void> _loadOlderImpl(String id) async {
    if (!active) return;
    final offset = _olderRows[id];
    if (offset == null) return;
    final generation = _loadGeneration;
    // The oldest message held. A read of the chat's newest page meanwhile
    // replaces it, and the offset no longer counts from that page.
    final oldest = _threads
        .where((t) => t.id == id)
        .firstOrNull
        ?.messages
        .firstOrNull;
    try {
      final page = await repository!.loadMessagePage(
        id,
        profile: _profile,
        offset: offset,
      );
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null ||
          _olderRows[id] != offset ||
          !identical(thread.messages.firstOrNull, oldest)) {
        return;
      }
      final held = {for (final m in thread.messages) m.id};
      final older = [
        for (final m in page.messages)
          if (!held.contains(m.id)) m,
      ];
      thread.messages.insertAll(0, older);
      _reactionHistory(thread);
      if (page.hasMore && page.rows > 0) {
        _olderRows[id] = offset + page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      if (older.isEmpty) return;
      await controllerFor(thread).insertAllMessages(
        chatMessagesToFlyer(older),
        index: 0,
        animated: false,
      );
    } on Object {
      if (active && generation == _loadGeneration) {
        report('Could not load earlier messages');
      }
    }
  }

  /// Reads [id] again from the dashboard after it changed elsewhere (another
  /// window): its title and pin, and its messages once they were loaded. A
  /// chat that is gone leaves the list. Nothing is read while a reply streams
  /// into it, which would replace the reply in progress.
  Future<void> _refreshThreadImpl(String id) async {
    if (!active) return;
    final repository = this.repository;
    final thread = _threads.where((t) => t.id == id).firstOrNull;
    if (repository == null ||
        thread == null ||
        !thread.remote ||
        thread.isReplying) {
      return;
    }
    final generation = _loadGeneration;
    bool stale() =>
        !active || generation != _loadGeneration || thread.isReplying;
    try {
      final fresh = await repository.loadThread(id, profile: _profile);
      if (stale()) return;
      if (fresh == null) {
        housekeeping?.forget(thread);
        return notifyListeners();
      }
      final unchanged = fresh.updatedAt == thread.updatedAt;
      housekeeping?.adopt(thread, fresh);
      notifyListeners();
      if (stale()) return;
      if (unchanged || _unloaded.contains(id)) return;
      final page = await repository.loadMessagePage(id, profile: _profile);
      if (stale()) return;
      final failed = _failedTurn(thread, page.messages);
      thread.messages
        ..clear()
        ..addAll(page.messages)
        ..addAll(failed);
      _reactionHistory(thread);
      if (page.hasMore) {
        _olderRows[id] = page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
      if (stale()) return;
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      // Keeps what it shows; the next refresh or open reads it again.
    }
  }

  /// The turn of [thread] that ended in a failed reply and is still its last,
  /// to show after the [history] a read brought: the prompt, unless the history
  /// already holds it, and the failed reply with its error and Retry. It is
  /// dropped once an assistant message follows the prompt in the history, and
  /// a later send leaves it behind the thread's last message anyway.
  ///
  /// A prompt repeats earlier ones, so it is found by its place among the user
  /// messages of the same text: with n of them before it here, the history
  /// holds it only when it has more than n, and its occurrence is the next.
  List<ChatMessage> _failedTurn(ChatThread thread, List<ChatMessage> history) {
    final messages = thread.messages;
    final reply = messages.lastOrNull;
    if (reply == null ||
        reply.role != ChatRole.assistant ||
        reply.status != MessageStatus.error) {
      return const [];
    }
    final promptAt = messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (promptAt < 0) return [reply];
    final prompt = messages[promptAt];
    bool same(ChatMessage m) =>
        m.role == ChatRole.user && m.content == prompt.content;
    final before = messages.take(promptAt).where(same).length;
    final occurrences = [
      for (var i = 0; i < history.length; i++)
        if (same(history[i])) i,
    ];
    if (occurrences.length <= before) return [prompt, reply];
    final answered = history
        .skip(occurrences[before] + 1)
        .any((m) => m.role == ChatRole.assistant);
    return answered ? const [] : [reply];
  }
}
