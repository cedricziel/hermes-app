part of 'chat_controller.dart';

/// Prompt submission and the lifetime of its initial reply stream.
extension _ChatControllerSending on ChatController {
  bool _send(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
    bool queued = false,
    List<ChatAttachment>? readyAttachments,
    List<OutgoingAttachment>? readyOutgoing,
    _ProtectedQueuedSend? protectedSend,
  }) {
    if (protectedSend != null &&
        (selected == null || !_bound.contains(selected))) {
      return false;
    }
    if (_sessionStates[selected]?.reclaimedReason != null) return false;
    if (!active) return false;
    final epoch = _activityEpoch;
    final sizes = readyAttachments == null ? _sizesOrExplain(files) : <int>[];
    if (sizes == null) return false;
    final attachments = <ChatAttachment>[...?readyAttachments];
    final outgoing = <OutgoingAttachment>[...?readyOutgoing];
    for (final (i, file) in files.indexed) {
      final kind = file.isImage ? AttachmentKind.image : AttachmentKind.file;
      attachments.add(
        ChatAttachment(
          name: file.name,
          kind: kind,
          path: file.path,
          size: sizes[i],
        ),
      );
      outgoing.add(
        OutgoingAttachment(
          name: file.name,
          kind: kind,
          mimeType: file.mimeType,
          read: File(file.path).readAsBytes,
        ),
      );
    }

    final label = typed.isEmpty
        ? (readyAttachments?.firstOrNull?.name ?? files.first.name)
        : displayText ?? typed;
    final thread =
        selected ??
        ChatThread(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: label,
          updatedAt: DateTime.now(),
          modelChoice: _newChatModel,
        );
    if (selected == null) {
      _threads.insert(0, thread);
      _selectedId = thread.id;
    }
    // A chat that has a name keeps it, even when its messages are not loaded
    // or a retry or an edit emptied them; only a chat with none gets a title
    // made from the prompt, which is not a name.
    if (protectedSend == null && thread.messages.isEmpty && !thread.named) {
      thread
        ..title = label.length > 48 ? '${label.substring(0, 48)}…' : label
        ..named = false;
    }

    final threadId = _bound.contains(thread) ? thread.id : null;
    final userMessage = ChatMessage(
      id: _newMessageId(thread),
      role: ChatRole.user,
      content: displayText ?? typed,
      submittedText: displayText == null ? null : typed,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    if (protectedSend == null) {
      thread.messages.add(userMessage);
      for (final flyer in chatMessageToFlyer(userMessage)) {
        controllerFor(thread).insertMessage(flyer);
      }
    }
    // A reply of its own: no stop asked before it is about it, and the answer
    // to one is no longer about this thread's current reply.
    _holds.remove(thread);
    _interrupts.remove(thread);
    _generations.update(thread, (n) => n + 1, ifAbsent: () => 1);
    final placeholder = _addPlaceholder(thread);
    thread.updatedAt = DateTime.now();
    notifyListeners();
    if (!_currentActivity(epoch)) return false;
    final transport = this.transport;
    if (transport == null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!_currentActivity(epoch)) return;
        _updateReply(thread, placeholder, () {
          placeholder.status = MessageStatus.sent;
          placeholder.content = buildMockReply(label);
        });
        _drainQueue(thread);
      });
    } else {
      _streamReply(
        transport,
        thread,
        placeholder,
        typed,
        outgoing,
        threadId,
        queued: queued,
        submittedUser: userMessage,
        protectedSend: protectedSend,
        deferredUser: protectedSend == null ? null : userMessage,
      );
      if (!_currentActivity(epoch)) return false;
      unawaited(_attention.askForPermission());
    }
    return true;
  }

  /// Appends the assistant message a reply that is about to stream fills in.
  ChatMessage _addPlaceholder(ChatThread thread) {
    _queueTurnReady.remove(thread);
    _queueSettled.remove(thread);
    // A new turn starts: a completion that comes now is its, not the settled
    // reply's before it.
    _settledReply(thread)?.settledWithoutCompletion = false;
    // The queue waited for the session to settle after the turn before. This
    // one decides when it may go on.
    _settleTimers.remove(thread)?.cancel();
    return _insertReply(thread);
  }

  /// Adds a thinking assistant message to [thread], at the end or, with
  /// [before], in front of that message.
  ChatMessage _insertReply(ChatThread thread, {ChatMessage? before}) {
    final reply = ChatMessage(
      id: _newMessageId(thread),
      role: ChatRole.assistant,
      content: '',
      createdAt: before?.createdAt ?? DateTime.now(),
      status: MessageStatus.thinking,
    );
    final at = before == null ? -1 : thread.messages.indexOf(before);
    if (at < 0) {
      thread.messages.add(reply);
    } else {
      thread.messages.insert(at, reply);
    }
    final chat = controllerFor(thread);
    final slot = at < 0
        ? -1
        : chat.messages.indexWhere(
            (m) => m.id == chatMessageToFlyer(before!).firstOrNull?.id,
          );
    for (final (i, flyer) in chatMessageToFlyer(reply).indexed) {
      chat.insertMessage(flyer, index: slot < 0 ? null : slot + i);
    }
    return reply;
  }

  /// The size of each of [files], or null after telling the user which one
  /// cannot be sent. The composer keeps its text and attachments then.
  List<int>? _sizesOrExplain(List<SharedFile> files) {
    final sizes = <int>[];
    for (final file in files) {
      final int size;
      try {
        size = File(file.path).lengthSync();
      } on FileSystemException {
        report(attachmentFailedMessage(file.name, kAttachmentUnreadable));
        return null;
      }
      if (size > kMaxAttachmentBytes) {
        report(attachmentTooLargeMessage(file.name));
        return null;
      }
      sizes.add(size);
    }
    return sizes;
  }

  void _streamReply(
    ChatTransport transport,
    ChatThread thread,
    ChatMessage reply,
    String text,
    List<OutgoingAttachment> attachments,
    String? threadId, {
    bool queued = false,
    required ChatMessage submittedUser,
    _ProtectedQueuedSend? protectedSend,
    ChatMessage? deferredUser,
  }) {
    _beginMoaTurn(thread, reply);
    final epoch = _activityEpoch;
    final queueGeneration = _loadGeneration;
    late final StreamSubscription<ChatEvent> subscription;
    final profile = _profile;
    // A new turn: what a run announced of an earlier one says nothing of it.
    unawaited(runningReplies?.takeAnnounced(profile, thread.id));
    _rememberedSince.remove((profile, thread.id));
    var failed = false;
    var stopped = false;
    var folded = false;
    var settled = false;
    final own = _OwnTurn();
    String outcome(Object? error) {
      if (error != null || reply.isPending && !folded) return 'failed';
      if (folded) return 'folded';
      if (stopped) return 'stopped';
      return failed || reply.status == MessageStatus.error
          ? 'failed'
          : 'completed';
    }

    void end([Object? error]) {
      if (!_currentActivity(epoch)) return;
      _finishMoaTurn(thread, reply);
      if (!_bound.contains(thread)) _finishQueueBinding(thread, false);
      if (protectedSend != null && !protectedSend.accepted) {
        if (!protectedSend.restored && protectedSend.started) {
          _replaceQueueState(
            thread,
            protectedSend,
            QueueRecordState.submissionStarted,
          );
          _restoredQueues.add(thread);
        } else if (!protectedSend.provenNotSubmitted) {
          _replaceQueueState(thread, protectedSend, QueueRecordState.queued);
        }
      }
      _replies.remove(subscription);
      if (error != null || (!folded && reply.isPending)) {
        _discardWarnings(thread);
      }
      _sending.update(thread, (n) => n - 1);
      if (_sending[thread] == 0) _sending.remove(thread);
      breadcrumbs('chat.reply.ended', {'outcome': outcome(error)});
      _closeOwnTurn(
        thread,
        own,
        profile,
        failed: error != null,
        announceFailure: !reply.isPending,
      );
      if (!_currentActivity(epoch)) return;
      if (folded) {
        // The prompt went into the turn already running, whose events follow
        // on the thread's follow-ups.
        if (error == null) {
          _followUps(transport, thread, profile);
          if (!_currentActivity(epoch)) return;
          // A stop of the running turn in flight decides when the queue goes
          // on: its answer, or the end of that turn.
          if (_holdOf(thread) == _Hold.none) _awaitSettle(thread);
          unawaited(refreshActive());
        } else {
          _turnEnded(thread, halted: true);
          // No notification: the prompt's reply was folded away, so none is
          // pending to announce.
          _announce(
            thread,
            const ReplyCompleted('', failed: true),
            profile,
            notify: false,
          );
          notifyListeners();
        }
      } else if (reply.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, reply, () => failReply(reply, error));
        if (!_currentActivity(epoch)) return;
        _announce(thread, const ReplyCompleted('', failed: true), profile);
        // A send that gave up asks for the thread to be read again: what
        // Hermes ran meanwhile is in its history. The read keeps this failed
        // turn after it (see [refreshThread]).
        _refetchIfIdle(thread);
      } else if (error == null) {
        // The watch is parked whatever ended the reply, so the follow-ups
        // listen to it. Only a reply that ended well drains the queue; after a
        // failure or a stop it stays paused for the user.
        final halted = failed || stopped || reply.status == MessageStatus.error;
        final drain = _turnEnded(
          thread,
          halted: halted,
          idleOnly: reply.settledWithoutCompletion,
        );
        _followUps(transport, thread, profile);
        if (!_currentActivity(epoch)) return;
        if (drain) {
          if (settled) {
            _drainQueue(thread);
          } else {
            _awaitSettle(thread);
          }
        }
        _refetchIfIdle(thread);
        unawaited(refreshActive());
        if (!drain) notifyListeners();
      } else {
        // The queue is left paused; the screen shows it.
        _turnEnded(thread, halted: true);
        notifyListeners();
      }
    }

    _sending.update(thread, (n) => n + 1, ifAbsent: () => 1);
    liveActivities?.begin(thread, profile: profile);
    _announcedTurns.add(thread);
    _watchSource?.begin(
      thread,
      title: _watchTitle(thread),
      threadId: _watchThreadId(thread, profile),
    );
    if (!_currentActivity(epoch)) return;
    breadcrumbs('chat.reply.started', {
      'queued': queued,
      'attachments': attachments.length,
    });
    final Stream<ChatEvent> stream;
    if (protectedSend == null) {
      stream = transport.send(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: thread.modelChoice,
        queued: queued,
      );
    } else {
      stream = (transport as QueueSubmissionTransport).sendQueued(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: thread.modelChoice,
        queueDispatchAllowed: () =>
            queueAvailable(thread) &&
            _queueContextCurrent(
              thread,
              protectedSend,
              profile,
              queueGeneration,
            ) &&
            _entryFor(thread, protectedSend) != null,
        beforeSubmit: () async {
          if (!queueAvailable(thread) ||
              !_queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              ) ||
              _entryFor(thread, protectedSend) == null) {
            throw QueueSubmissionNotStarted(
              StateError('Queue scope unavailable'),
            );
          }
          await protectedSend.store.beginSubmission(
            protectedSend.scope,
            protectedSend.id,
            protectedSend.claim,
          );
          protectedSend.started = true;
          _replaceQueueState(
            thread,
            protectedSend,
            QueueRecordState.submissionStarted,
            submitting: true,
          );
          if (!queueAvailable(thread) ||
              !_queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            throw QueueSubmissionNotStarted(
              StateError('Queue scope unavailable'),
            );
          }
        },
        onNotSubmitted: () => _restoreNotSubmitted(thread, protectedSend),
      );
    }
    subscription = stream.listen(
      (event) {
        if (!_currentActivity(epoch)) return;
        if (event is PromptAcknowledged) {
          if (protectedSend == null ||
              _queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            _assignPromptReceipt(
              thread,
              submittedUser,
              event,
              profile,
              inserted: protectedSend == null,
            );
          }
          return;
        }
        if (event is PromptAccepted &&
            protectedSend != null &&
            PromptAccepted.allowedStatuses.contains(event.status)) {
          if (deferredUser != null &&
              _queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            final index = thread.messages.indexOf(reply);
            thread.messages.insert(
              index < 0 ? thread.messages.length : index,
              deferredUser,
            );
            _reactionHistory(thread);
            if (!_queueContextCurrent(
              thread,
              protectedSend,
              profile,
              queueGeneration,
            )) {
              _acceptedQueue(thread, protectedSend);
              return;
            }
            final controller = controllerFor(thread);
            final flyerIndex = controller.messages.indexWhere(
              (item) => item.id == chatMessageToFlyer(reply).firstOrNull?.id,
            );
            for (final flyer in chatMessageToFlyer(deferredUser)) {
              controller.insertMessage(
                flyer,
                index: flyerIndex < 0 ? null : flyerIndex,
              );
            }
          }
          _acceptedQueue(thread, protectedSend);
          return;
        }
        if (event is ReplyCompleted) {
          failed = event.failed;
          stopped = event.stopped;
        }
        if (event is PromptFolded) folded = true;
        if (event is SessionInfo && event.running == false) settled = true;
        if (event is UnsolicitedEvent) {
          _onOwnTurnEvent(thread, reply, own, event.event, profile);
          return;
        }
        _onReplyEvent(thread, reply, event, profile);
      },
      onError: end,
      onDone: end,
      cancelOnError: true,
    );
    _replies.add(subscription);
  }
}
