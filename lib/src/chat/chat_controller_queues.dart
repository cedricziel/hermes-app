part of 'chat_controller.dart';

/// Durable prompt restoration, ownership, dispatch, and settle handling.
extension _ChatControllerQueues on ChatController {
  bool get _queuesVisibleImpl => canShowQueues?.call() ?? true;

  bool _queueNeedsReviewImpl(ChatThread thread) =>
      _restoredQueues.contains(thread);

  bool _queueBusyImpl(ChatThread thread) =>
      _queueRemoving.contains(thread) ||
      _enqueueing.contains(thread) ||
      _queuePreparing.contains(thread) ||
      _queueDispatching.contains(thread) ||
      _queueRestoring.containsKey(thread);

  String? _queueErrorInImpl(ChatThread thread) => _queueErrors[thread];

  bool _queueAvailableImpl(ChatThread thread) =>
      active &&
      _profile != null &&
      _profile!.trim().isNotEmpty &&
      queuesVisible &&
      !_queueUnavailable.contains(thread) &&
      !(_queues[thread]?.any(
            (prompt) =>
                prompt.scope != null &&
                prompt.scope!.conversationId != thread.id,
          ) ??
          false) &&
      _sessionStates[thread]?.reclaimedReason == null &&
      _bound.contains(thread);

  void _queueReviewedImpl(QueuedPrompt prompt) => breadcrumbs(
    'chat.queue.reviewed',
    {'count': 1, 'state': prompt.uncertain ? 'uncertain' : 'unsent'},
  );

  void _inspectQueuedImpl(ChatThread thread) {
    if (!active || !_threads.contains(thread)) return;
    select(thread.id);
    if (repository != null) unawaited(refreshThread(thread.id));
  }

  bool _sameQueueOwner(QueueScope? current, QueueScope expected) =>
      current != null &&
      current.serverKey == expected.serverKey &&
      current.accountKey == expected.accountKey &&
      current.profile == expected.profile;

  void _finishQueueBinding(ChatThread thread, bool bound) {
    _bindingScopes.remove(thread);
    final wait = _queueBindings.remove(thread);
    if (wait != null && !wait.isCompleted) wait.complete(bound);
  }

  void _cancelQueueBindings() {
    for (final thread in _queueBindings.keys.toList()) {
      _finishQueueBinding(thread, false);
    }
  }

  void _queueIdentityChanged() {
    _queueEpoch++;
    _queueRestoring.clear();
    for (final entry in _bindingScopes.entries.toList()) {
      if (!_sameQueueOwner(
        queueScope?.call(entry.key, _profile),
        entry.value,
      )) {
        _finishQueueBinding(entry.key, false);
      }
    }
    for (final entry in _queues.entries.toList()) {
      final current = queueScope?.call(entry.key, _profile);
      if (!queuesVisible ||
          entry.value.any(
            (prompt) =>
                prompt.scope != null &&
                !_sameQueueOwner(current, prompt.scope!),
          )) {
        _hiddenQueueOrder[entry.key] = [
          for (final prompt in entry.value)
            if (prompt.scope != null && prompt.durable != null)
              (prompt.scope!, prompt.durable!.id),
        ];
        _queues.remove(entry.key);
        _loadedQueues.remove(entry.key);
        _settleTimers.remove(entry.key)?.cancel();
      }
    }
    if (selectedThread case final thread? when active && queuesVisible) {
      unawaited(_restoreQueue(thread));
    }
    notifyListeners();
  }

  Future<bool> _waitForQueueBinding(ChatThread thread, QueueScope scope) {
    if (_bound.contains(thread)) return Future.value(true);
    _bindingScopes[thread] = scope;
    return (_queueBindings[thread] ??= Completer<bool>()).future;
  }

  Future<PromptQueueStore> _protectedQueueStore() async {
    try {
      return await (_openedQueueStore ??= queueStore!());
    } on Object {
      _openedQueueStore = null;
      rethrow;
    }
  }

  Future<ChatThread> _recoverQueuedThread(
    ChatThread thread,
    String? profile,
  ) async {
    final generation = _loadGeneration, epoch = _activityEpoch;
    bool current() =>
        _currentActivity(epoch) &&
        generation == _loadGeneration &&
        _profile == profile;
    try {
      final fresh = await repository!.loadThread(thread.id, profile: profile);
      if (fresh != null) {
        if (current()) setThreadListAvailability(thread, available: true);
        return fresh;
      }
    } on Object {
      // An unreadable target cannot vouch for sending into its old session.
    }
    if (_queues[thread]?.any((prompt) => prompt.durable != null) ?? false) {
      if (current()) setThreadListAvailability(thread, available: false);
      return thread;
    }
    return _queuedDraft(thread);
  }

  ChatThread _queuedDraft(ChatThread thread, {bool newId = false}) =>
      ChatThread(
        id: newId ? '${thread.id}-draft-${_sentMessages++}' : thread.id,
        title: thread.title,
        named: thread.named,
        updatedAt: thread.updatedAt,
        modelChoice: thread.modelChoice,
        messages: [
          for (final message in thread.messages)
            if (!message.isPending) message,
        ],
      );

  Future<void> Function()? _prepareQueueDeletion(ChatThread thread) {
    if (queueStore == null) return null;
    final scopes = <String, QueueScope>{};
    void remember(QueueScope scope) =>
        scopes[jsonEncode(scope.toJson())] = scope;
    final current = queueScope?.call(thread, _profile);
    if (current != null) remember(current);
    for (final prompt in _queues[thread] ?? const <QueuedPrompt>[]) {
      if (prompt.scope case final scope?) remember(scope);
    }
    for (final (scope, _)
        in _hiddenQueueOrder[thread] ?? const <(QueueScope, String)>[]) {
      remember(scope);
    }
    if (scopes.isEmpty) return null;
    return () async {
      final store = await _protectedQueueStore();
      for (final scope in scopes.values) {
        await store.deleteConversation(scope);
      }
    };
  }

  Future<bool> _restoreQueue(ChatThread thread) {
    if (!active) return Future.value(false);
    if (queueStore == null || !thread.remote) {
      return Future.value(true);
    }
    if (_loadedQueues.contains(thread)) return Future.value(true);
    final held = _queueRestoring[thread];
    if (held != null) return held;
    late final Future<bool> restoring;
    restoring = _readProtectedQueue(thread).whenComplete(() {
      if (identical(_queueRestoring[thread], restoring)) {
        _queueRestoring.remove(thread);
      }
      if (active) notifyListeners();
    });
    _queueRestoring[thread] = restoring;
    return restoring;
  }

  Future<bool> _readProtectedQueue(ChatThread thread) async {
    final profile = _profile;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final generation = _loadGeneration;
    final scope = queueScope?.call(thread, profile);
    if (profile == null ||
        profile.trim().isEmpty ||
        scope == null ||
        !queuesVisible) {
      return false;
    }
    try {
      final store = await _protectedQueueStore();
      final order = _hiddenQueueOrder[thread] ?? const <(QueueScope, String)>[];
      final scopes = <String, QueueScope>{jsonEncode(scope.toJson()): scope};
      for (final (held, _) in order) {
        if (_sameQueueOwner(held, scope)) {
          scopes[jsonEncode(held.toJson())] = held;
        }
      }
      final prompts = <QueuedPrompt>[];
      var corrupt = 0;
      for (final target in scopes.values) {
        final loaded = await store.load(target);
        corrupt += loaded.corruptRecords;
        for (final record in loaded.records) {
          if (_knownQueueAcceptance.contains((
            jsonEncode(target.toJson()),
            record.id,
          ))) {
            continue;
          }
          prompts.add(
            QueuedPrompt(
              record.text,
              const [],
              displayText: record.displayText,
              durable: record,
              scope: target,
            ),
          );
        }
      }
      if (!active ||
          !queuesVisible ||
          epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          generation != _loadGeneration ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(queueScope?.call(thread, profile), scope)) {
        return false;
      }
      if (order.isNotEmpty) {
        int position(QueuedPrompt prompt) => order.indexWhere(
          (item) =>
              item.$2 == prompt.durable?.id &&
              jsonEncode(item.$1.toJson()) ==
                  jsonEncode(prompt.scope!.toJson()),
        );
        prompts.sort((a, b) {
          final left = position(a), right = position(b);
          if (left >= 0 && right >= 0) return left.compareTo(right);
          if (left >= 0) return -1;
          if (right >= 0) return 1;
          return a.durable!.sequence.compareTo(b.durable!.sequence);
        });
      }
      _loadedQueues.add(thread);
      _hiddenQueueOrder.remove(thread);
      _settleTimers.remove(thread)?.cancel();
      if (prompts.isNotEmpty) {
        _queues[thread] = prompts;
        _restoredQueues.add(thread);
      } else if (!_enqueueing.contains(thread) &&
          (_queues[thread]?.isEmpty ?? true)) {
        _restoredQueues.remove(thread);
      }
      if (corrupt > 0) _queueErrors[thread] = 'Some recovered prompts could not be read. Valid entries were kept.';
      try {
        events('chat.queue.recovery', {
          'outcome': corrupt > 0
              ? 'corrupt'
              : prompts.isEmpty
              ? 'empty'
              : 'recovered',
          'count': prompts.length,
        });
      } on Object {
        // Telemetry must not alter the review barrier.
      }
      notifyListeners();
      return true;
    } on Object {
      if (_currentActivity(activityEpoch) &&
          epoch == _queueEpoch &&
          generation == _loadGeneration) {
        _queueErrors[thread] =
            'Protected queue storage is unavailable. Your draft was kept.';
        try {
          events('chat.queue.recovery', {'outcome': 'unavailable', 'count': 0});
        } on Object {
          // Telemetry must not alter the review barrier.
        }
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> _submitAfterQueueRestore(
    ChatThread thread,
    String text,
    List<SharedFile> files,
    String? displayText,
  ) async {
    if (!_queuePreparing.add(thread)) return false;
    final profile = _profile;
    final activityEpoch = _activityEpoch;
    final generation = _loadGeneration;
    final scope = queueScope?.call(thread, profile);
    try {
      if (scope == null ||
          !await _restoreQueue(thread) ||
          !_currentActivity(activityEpoch) ||
          generation != _loadGeneration ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(queueScope?.call(thread, profile), scope)) {
        return false;
      }
      _queuePreparing.remove(thread);
      return await Future.sync(
        () => _submitTo(thread, text, files, displayText: displayText),
      );
    } finally {
      _queuePreparing.remove(thread);
    }
  }

  /// The prompts waiting in [thread] for its reply to end.
  List<QueuedPrompt> _queuedInImpl(ChatThread thread) =>
      List.unmodifiable(_queues[thread] ?? const <QueuedPrompt>[]);

  /// Whether [thread] holds queued prompts that no reply will send, because
  /// the last one was stopped or failed.
  bool _queuePausedImpl(ChatThread thread) =>
      !thread.isReplying && (_queues[thread]?.isNotEmpty ?? false);

  FutureOr<void> _removeQueuedImpl(ChatThread thread, QueuedPrompt prompt) {
    if (!active) return Future<void>.value();
    if (prompt.submitting || _queueDispatching.contains(thread)) {
      return Future<void>.value();
    }
    if (prompt.durable != null) return _removeProtectedQueue(thread, prompt);
    final queue = _queues[thread];
    if (queue == null || !queue.remove(prompt)) return Future<void>.value();
    if (queue.isEmpty) _queues.remove(thread);
    notifyListeners();
    return Future<void>.value();
  }

  Future<void> _removeProtectedQueue(
    ChatThread thread,
    QueuedPrompt prompt,
  ) async {
    if (!_queueRemoving.add(thread)) return;
    try {
      final scope = prompt.scope;
      if (scope == null) throw const QueueStorageException('unavailable');
      await (await _protectedQueueStore()).discard(scope, prompt.durable!.id);
      _queues[thread]?.removeWhere(
        (entry) =>
            entry.durable?.id == prompt.durable!.id &&
            jsonEncode(entry.scope?.toJson()) == jsonEncode(scope.toJson()),
      );
      if (_queues[thread]?.isEmpty ?? false) {
        _queues.remove(thread);
        _restoredQueues.remove(thread);
      }
      breadcrumbs('chat.queue.removed', {
        'count': 1,
        'state': prompt.uncertain ? 'uncertain' : 'unsent',
      });
      _queueRemoving.remove(thread);
      if (!_restoredQueues.contains(thread) &&
          !thread.isReplying &&
          _queueTurnReady.contains(thread) &&
          _holdOf(thread) == _Hold.none) {
        _queueSettled.contains(thread)
            ? _drainQueue(thread)
            : _awaitSettle(thread);
      }
    } on Object {
      _queueErrors[thread] =
          'Could not remove this queued prompt. Its protected record was kept.';
    } finally {
      _queueRemoving.remove(thread);
      if (active) notifyListeners();
    }
  }

  /// Explicitly resumes queued work after review; unsent prompts stay queued.
  void _sendQueuedImpl(ChatThread thread) {
    if (!active || _queueUnavailable.contains(thread)) return;
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (_reclaimedQueueReview.remove(thread)) {
      breadcrumbs('chat.visibility_action', {
        'feature': 'session_state',
        'action': 'review_queue',
      });
    }
    if (_restoredQueues.contains(thread)) {
      final prompt = _queues[thread]?.firstOrNull;
      if (prompt == null ||
          prompt.uncertain ||
          queueBusy(thread) ||
          thread.isReplying) {
        return;
      }
      breadcrumbs('chat.queue.send_requested', {'count': 1, 'state': 'unsent'});
      queueReviewed(prompt);
      unawaited(_dispatchProtected(thread, prompt));
    } else {
      _drainQueue(thread);
    }
  }

  void _drainQueue(ChatThread thread) {
    if (!active || _queueUnavailable.contains(thread)) return;
    if (_sessionStates[thread]?.reclaimedReason != null ||
        _reclaimedQueueReview.contains(thread)) {
      return;
    }
    _settleTimers.remove(thread)?.cancel();
    final queue = _queues[thread];
    if (thread.isReplying ||
        queue == null ||
        queue.isEmpty ||
        _queueDispatching.contains(thread)) {
      return;
    }
    if (_restoredQueues.contains(thread) || _queueRemoving.contains(thread)) {
      return;
    }
    final first = queue.first;
    if (first.durable != null) {
      if (!first.uncertain) unawaited(_dispatchProtected(thread, first));
      return;
    }
    _suspendedQueues.remove(thread);
    final next = queue.removeAt(0);
    if (queue.isEmpty) _queues.remove(thread);
    if (!_send(
      thread,
      next.text,
      next.files,
      displayText: next.displayText,
      queued: true,
    )) {
      (_queues[thread] ??= []).insert(0, next);
    }
    notifyListeners();
  }

  bool _queueContextCurrent(
    ChatThread thread,
    _ProtectedQueuedSend send,
    String? profile,
    int generation,
  ) =>
      _currentActivity(send.activityEpoch) &&
      _sessionActionCurrent(thread, send.sessionGeneration) &&
      queuesVisible &&
      send.epoch == _queueEpoch &&
      profile == _profile &&
      generation == _loadGeneration &&
      _threads.contains(thread) &&
      _sameQueueOwner(queueScope?.call(thread, profile), send.scope) &&
      send.scope.conversationId == thread.id &&
      _sessionStates[thread]?.reclaimedReason == null;

  QueuedPrompt? _entryFor(ChatThread thread, _ProtectedQueuedSend send) =>
      _queues[thread]
          ?.where(
            (prompt) =>
                prompt.durable?.id == send.id &&
                jsonEncode(prompt.scope?.toJson()) ==
                    jsonEncode(send.scope.toJson()),
          )
          .firstOrNull;

  void _replaceQueueState(
    ChatThread thread,
    _ProtectedQueuedSend send,
    QueueRecordState state, {
    bool submitting = false,
  }) {
    final prompt = _entryFor(thread, send);
    final queue = _queues[thread];
    if (prompt == null || queue == null) return;
    queue[queue.indexOf(prompt)] = QueuedPrompt(
      prompt.text,
      prompt.files,
      displayText: prompt.displayText,
      durable: prompt.durable!.withState(state),
      scope: prompt.scope,
      submitting: submitting,
    );
    if (active) notifyListeners();
  }

  Future<void> _restoreNotSubmitted(
    ChatThread thread,
    _ProtectedQueuedSend send,
  ) async {
    send.provenNotSubmitted = true;
    try {
      await send.store.restoreUnsentAfterPreSubmitFailure(
        send.scope,
        send.id,
        claim: send.claim,
      );
      send.restored = true;
      _replaceQueueState(thread, send, QueueRecordState.queued);
    } on Object {
      _replaceQueueState(thread, send, QueueRecordState.submissionStarted);
      _restoredQueues.add(thread);
      _queueErrors[thread] = 'Protected queue state could not be updated. Inspect the conversation before sending again.';
    }
  }

  void _acceptedQueue(ChatThread thread, _ProtectedQueuedSend send) {
    send.accepted = true;
    _knownQueueAcceptance.add((jsonEncode(send.scope.toJson()), send.id));
    final prompt = _entryFor(thread, send);
    if (prompt != null) _queues[thread]?.remove(prompt);
    if (_queues[thread]?.isEmpty ?? false) {
      _queues.remove(thread);
      _restoredQueues.remove(thread);
    }
    if (active) notifyListeners();
    unawaited(() async {
      try {
        await send.store.setState(
          send.scope,
          send.id,
          QueueRecordState.accepted,
        );
      } on Object {
        if (active) {
          report(
            'Hermes accepted this prompt, but local cleanup could not finish. Do not send it again.',
          );
        }
      }
    }());
  }

  Future<void> _dispatchProtected(
    ChatThread thread,
    QueuedPrompt prompt,
  ) async {
    if (!_queueDispatching.add(thread)) return;
    final scope = prompt.scope;
    final profile = _profile;
    final generation = _loadGeneration;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final sessionGeneration = _sessionActionGeneration(thread);
    try {
      if (scope == null ||
          prompt.uncertain ||
          !queueAvailable(thread) ||
          transport is! QueueSubmissionTransport) {
        throw const QueueStorageException('unavailable');
      }
      final store = await _protectedQueueStore();
      final send = _ProtectedQueuedSend(
        prompt,
        scope,
        store,
        epoch,
        activityEpoch,
        sessionGeneration,
      );
      final attachments = <ChatAttachment>[];
      final outgoing = <OutgoingAttachment>[];
      for (final file in prompt.durable!.attachments) {
        final bytes = Uint8List.fromList(
          await store.readAttachment(scope, send.id, file.blobId),
        );
        final kind = file.isImage ? AttachmentKind.image : AttachmentKind.file;
        attachments.add(
          ChatAttachment(
            name: file.name,
            kind: kind,
            size: file.size,
            bytes: bytes,
          ),
        );
        outgoing.add(
          OutgoingAttachment(
            name: file.name,
            kind: kind,
            mimeType: file.mimeType,
            read: () async => bytes,
          ),
        );
      }
      if (!queueAvailable(thread) ||
          !_queueContextCurrent(thread, send, profile, generation) ||
          _entryFor(thread, send) == null) {
        return;
      }
      _queueErrors.remove(thread);
      _replaceQueueState(
        thread,
        send,
        QueueRecordState.queued,
        submitting: true,
      );
      _send(
        thread,
        prompt.text,
        const [],
        displayText: prompt.displayText,
        queued: true,
        readyAttachments: attachments,
        readyOutgoing: outgoing,
        protectedSend: send,
      );
    } on Object {
      _queueErrors[thread] =
          'Could not send this queued prompt. Its protected record was kept.';
      if (active) notifyListeners();
    } finally {
      _queueDispatching.remove(thread);
      if (active) notifyListeners();
    }
  }

  /// After a reply ended normally, holds the queued prompts of [thread] until
  /// the session reports it settled. Two seconds without that report (an older
  /// Hermes, or a missed frame) send them anyway.
  void _awaitSettle(ChatThread thread) {
    if (!active || _suspendedQueues.contains(thread)) return;
    if (_restoredQueues.contains(thread) ||
        thread.isReplying ||
        (_queues[thread]?.isEmpty ?? true)) {
      return;
    }
    if (_settleTimers.containsKey(thread)) return;
    _settleTimers[thread] = Timer(
      const Duration(seconds: 2),
      () => _settle(thread),
    );
  }

  /// Ends the settle wait of [thread], if one is running, and sends its
  /// queue. A thread whose queue is paused by a stop or a failure has no wait,
  /// so a late report does not send it.
  void _settle(ChatThread thread) {
    final timer = _settleTimers.remove(thread);
    if (timer == null) return;
    timer.cancel();
    _drainQueue(thread);
  }

  void _cancelSettleWaits() {
    for (final timer in _settleTimers.values) {
      timer.cancel();
    }
    _settleTimers.clear();
    _refetch.clear();
  }

  Future<bool> _enqueueProtected(
    ChatThread thread,
    String text,
    List<SharedFile> files,
    String? displayText,
  ) async {
    if (!_enqueueing.add(thread)) return false;
    final profile = _profile;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final initialScope = queueScope?.call(thread, profile);
    final wasReplying = thread.isReplying;
    try {
      if (profile == null ||
          profile.trim().isEmpty ||
          initialScope == null ||
          !await _waitForQueueBinding(thread, initialScope)) {
        throw const QueueStorageException('identity_unavailable');
      }
      final sessionGeneration = _sessionActionGeneration(thread);
      final scope = queueScope?.call(thread, profile);
      if (!active ||
          epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          !_sessionActionCurrent(thread, sessionGeneration) ||
          _sessionStates[thread]?.reclaimedReason != null ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(scope, initialScope)) {
        throw const QueueStorageException('identity_unavailable');
      }
      if (scope == null || !await _restoreQueue(thread)) {
        throw const QueueStorageException('identity_unavailable');
      }
      final record = await (await _protectedQueueStore()).commit(
        scope,
        text,
        displayText: displayText,
        files: [
          for (final file in files)
            QueueAttachmentInput(
              path: file.path,
              name: file.name,
              mimeType: file.mimeType,
              isImage: file.isImage,
            ),
        ],
      );
      if (epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          !_sessionActionCurrent(thread, sessionGeneration) ||
          _sessionStates[thread]?.reclaimedReason != null ||
          !_sameQueueOwner(queueScope?.call(thread, profile), initialScope)) {
        try {
          await (await _protectedQueueStore()).discard(scope, record.id);
        } on Object {
          // Revoked scopes remain protected until scoped cleanup succeeds.
        }
        throw const QueueStorageException('identity_unavailable');
      }
      _enqueueing.remove(thread);
      if (active && profile == _profile && _threads.contains(thread)) {
        (_queues[thread] ??= []).add(
          QueuedPrompt(
            text,
            files,
            displayText: displayText,
            durable: record,
            scope: scope,
          ),
        );
        if (_restoredQueues.contains(thread) ||
            thread.isReplying ||
            _settleTimers.containsKey(thread)) {
          notifyListeners();
        } else if (wasReplying) {
          if (_queueTurnReady.contains(thread) &&
              _holdOf(thread) == _Hold.none) {
            _queueSettled.contains(thread)
                ? _drainQueue(thread)
                : _awaitSettle(thread);
          }
          notifyListeners();
        } else {
          _drainQueue(thread);
        }
      }
      return true;
    } on Object {
      if (active) {
        report('Could not queue this prompt. Your draft was kept.');
      }
      return false;
    } finally {
      _enqueueing.remove(thread);
      if (_queues[thread]?.isEmpty ?? true) _restoredQueues.remove(thread);
    }
  }
}

class _ProtectedQueuedSend {
  _ProtectedQueuedSend(
    this.prompt,
    this.scope,
    this.store,
    this.epoch,
    this.activityEpoch,
    this.sessionGeneration,
  ) : claim = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
  final QueuedPrompt prompt;
  final QueueScope scope;
  final PromptQueueStore store;
  final int epoch;
  final int activityEpoch;
  final int sessionGeneration;
  final String claim;
  String get id => prompt.durable!.id;
  bool started = false;
  bool accepted = false;
  bool provenNotSubmitted = false;
  bool restored = false;
}
