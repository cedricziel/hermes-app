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
    final generation = ++_loadGeneration;
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
      final local = preserveSelection
          ? _threads.where((thread) => !thread.remote).toList()
          : const <ChatThread>[];
      final live = preserveSelection && profile == previousProfile
          ? _threads
                .where(
                  (thread) => thread.remote && _sending.containsKey(thread),
                )
                .toList()
          : const <ChatThread>[];
      final liveIds = {for (final thread in live) thread.id};
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
          : <String, List<QueuedPrompt>>{};
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
      _stopFollowing();
      _active.clear();
      for (final controller in _chatControllers.values) {
        controller.dispose();
      }
      _chatControllers.clear();
      final switched = profile != _profile;
      if (switched) {
        _modelOptions = null;
        _newChatModel = null;
        search?.clear();
      }
      _carryReplies();
      for (final entry in interruptedLocalReplies.entries) {
        entry.key.messages.removeWhere(
          (message) => message.isPending && entry.value.contains(message),
        );
      }
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
        );
      _olderRows.clear();
      _loadedQueues.clear();
      _restoredQueues.clear();
      _queueEpoch++;
      _queueRestoring.clear();
      _queueTurnReady.clear();
      _queueSettled.clear();
      _queues
        ..clear()
        ..addAll({
          for (final thread in _threads) thread: ?retainedQueues[thread.id],
        });
      _restoredQueues.addAll(
        _queues.keys.where(
          (thread) => _queues[thread]!.any((prompt) => prompt.durable != null),
        ),
      );
      _suspendedQueues
        ..clear()
        ..addAll(_queues.keys);
      _cancelSettleWaits();
      _bound
        ..clear()
        ..addAll(threads.where((thread) => thread.remote));
      _loadingThreads = false;
      _touched.clear();
      _selectedId =
          ChatController._isOnProfile(launch, profile) &&
              threads.any((t) => t.id == launch!.threadId)
          ? launch!.threadId
          : preserveSelection && _threads.any((t) => t.id == previousSelection)
          ? previousSelection
          : null;
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
    try {
      final page = await repository!.loadMessagePage(id, profile: _profile);
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      thread.messages.addAll(page.messages);
      _reactionHistory(thread);
      if (page.hasMore) _olderRows[id] = page.rows;
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      if (generation != _loadGeneration) return;
      _unloaded.add(id);
      if (!active) return;
      report('Could not load this chat');
    }
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
    try {
      final page = await repository!.loadMessagePage(
        id,
        profile: _profile,
        offset: offset,
      );
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
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
