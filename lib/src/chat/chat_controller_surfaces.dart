part of 'chat_controller.dart';

/// Reply announcements, background continuity, and system surface snapshots.
extension _ChatControllerSurfaces on ChatController {
  /// Moves the chat's Live Activity and the watch's status along for
  /// [event], and posts the notification it deserves unless [notify] is
  /// false. [profile] is the one the turn was sent under: the thread on
  /// screen only counts when the chat is still on that profile.
  void _announce(
    ChatThread thread,
    ChatEvent event,
    String? profile, {
    bool notify = true,
    bool ownTurn = false,
  }) {
    if (!active) return;
    final epoch = _activityEpoch;
    // The turn Hermes ran ahead of the prompt ends before the prompt's own
    // turn does, so its completion says nothing about the chat.
    if (!(ownTurn && event is ReplyCompleted)) {
      if (event is ReplyCompleted) _replyEnded(thread, profile);
      _announcedTurns.add(thread);
      liveActivities?.onEvent(thread, event);
      _watchSource?.onEvent(
        thread,
        event,
        title: _watchTitle(thread),
        threadId: _watchThreadId(thread, profile),
      );
    }
    if (!notify) return;
    void announce() {
      if (!_currentActivity(epoch)) return;
      _attention.announce(
        thread,
        event,
        selectedThreadId: profile == _profile ? _selectedId : null,
        profile: profile,
      );
    }

    final store = runningReplies;
    if (store == null || event is! ReplyCompleted) return announce();
    // A background run may have told the user of this very ending already;
    // the replay on return, or a reconnect during its wake, would tell again.
    store
        .takeAnnounced(profile, thread.id)
        .then(
          (was) => was ? null : announce(),
          onError: (Object _) => announce(),
        )
        .ignore();
  }

  void _carryReplies() {
    for (final thread in _threads) {
      if (thread.remote && thread.isReplying) {
        _carried.add((_profile, thread.id));
      }
    }
  }

  /// The app is leaving the front: remembers the chats whose reply still runs,
  /// in this profile and in the ones left since, which a background run
  /// announces once they finish. What an earlier run announced is forgotten:
  /// it described the last time the app was away.
  void _rememberRunningRepliesImpl() {
    if (!active) return;
    final store = runningReplies;
    if (store == null) return;
    final now = _clock();
    _pauses++;
    _replayEnds?.cancel();
    _carried.removeWhere((key) => _expired(key, now));
    final running = {
      for (final thread in _threads)
        if (thread.remote && thread.isReplying) (_profile, thread.id),
      ..._carried,
    };
    _rememberedSince.removeWhere((key, _) => !running.contains(key));
    for (final key in running) {
      _rememberedSince.putIfAbsent(key, () => now);
    }
    _replyListWritten = true;
    unawaited(store.clearAnnounced());
    unawaited(
      store.replace([
        for (final (profile, id) in running)
          RunningReply(
            profile: profile,
            threadId: id,
            since: _rememberedSince[(profile, id)]!,
          ),
      ]),
    );
  }

  bool _expired((String?, String) key, DateTime now) {
    final since = _rememberedSince[key];
    return since != null && now.difference(since) > kRunningReplyLifetime;
  }

  /// The app is in front: the replies are shown here, so nothing is left for
  /// a background run to announce. A reply that a run finished or whose
  /// session no longer runs has ended, and is not carried on. What a run
  /// announced stays on record only for the replay of its ending, which
  /// [replayGrace] allows for.
  void _forgetRunningRepliesImpl() {
    if (!active) return;
    final store = runningReplies;
    if (store == null) return;
    final written = _replyListWritten;
    _replyListWritten = false;
    if (written) {
      _replayEnds?.cancel();
      _replayEnds = Timer(replayGrace, () {
        if (active) unawaited(store.clearAnnounced());
      });
    }
    unawaited(
      _resumeRunningReplies(store, written, _pauses).catchError((Object _) {}),
    );
  }

  Future<void> _resumeRunningReplies(
    RunningReplies store,
    bool written,
    int pauses,
  ) async {
    // Each await below can outlast a pause, whose list and carried replies
    // are newer than anything this return learns: it stops at the first one.
    if (written && _carried.isNotEmpty) {
      final left = {
        for (final reply in await store.read()) (reply.profile, reply.threadId),
      };
      if (!active || pauses != _pauses) return;
      _carried.retainAll(left);
      if (!await _dropEnded(pauses)) return;
    }
    if (!active || pauses != _pauses) return;
    await store.clear();
  }

  /// Takes off [_carried] the replies whose session reports a turn that has
  /// ended; false when a pause came meanwhile. A server that cannot say, or
  /// does not list a session, decides nothing: the expiry does.
  Future<bool> _dropEnded(int pauses) async {
    final transport = this.transport;
    if (!active) return false;
    if (transport == null) return true;
    for (final profile in {for (final (profile, _) in _carried) profile}) {
      final statuses = await transport.activeStatuses(profile: profile);
      if (!active || pauses != _pauses) return false;
      _carried.removeWhere((key) {
        if (key.$1 != profile) return false;
        final status = statuses[key.$2];
        if (status == null || _runningStatuses.contains(status)) return false;
        _rememberedSince.remove(key);
        return true;
      });
    }
    return active && pauses == _pauses;
  }

  void _replyEnded(ChatThread thread, String? profile) {
    _carried.remove((profile, thread.id));
    _rememberedSince.remove((profile, thread.id));
    final store = runningReplies;
    if (store == null || !_replyListWritten) return;
    unawaited(
      store.forget([
        RunningReply(
          profile: profile,
          threadId: thread.id,
          since: DateTime.now(),
        ),
      ]),
    );
  }

  /// The title the watch face may show: a name, never one made from the
  /// prompt, a file name or the first message.
  String? _watchTitle(ChatThread thread) => thread.named ? thread.title : null;

  /// The id the watch uses for [thread], once the dashboard stores it.
  String? _watchThreadId(ChatThread thread, String? profile) =>
      thread.remote ? boundThreadId(profile, thread.id) : null;

  String _openRequestIds(ChatMessage reply) => onSurfaceChange == null
      ? ''
      : [
          for (final request in reply.inputRequests)
            if (request.status == InputRequestStatus.pending) request.requestId,
        ].join(',');

  void _reportSurface(SurfaceTrigger trigger) {
    if (active) onSurfaceChange?.call(trigger, _surfaceHints());
  }

  ChatHints _surfaceHints() {
    final now = DateTime.now();
    final threads = <ThreadHint>[];
    final requests = <RequestHint>[];
    final seen = <String, DateTime>{};
    for (final thread in _threads) {
      if (!thread.remote || thread.isCanonicalBotChat) continue;
      final touched = _touched[thread];
      final snippet = thread.messages.lastOrNull?.content;
      // A title made from the prompt would put its words on widgets.
      final title = thread.named ? thread.title : kUnnamedChatLabel;
      threads.add(
        ThreadHint(
          id: thread.id,
          title: title,
          updatedAt: touched != null && touched.isAfter(thread.updatedAt)
              ? touched
              : thread.updatedAt,
          snippet: snippet,
        ),
      );
      for (final message in thread.messages) {
        for (final request in message.inputRequests) {
          if (request.status != InputRequestStatus.pending) continue;
          final first = _requestSeen[request.requestId] ?? now;
          seen[request.requestId] = first;
          requests.add(
            RequestHint(
              threadId: thread.id,
              threadTitle: title,
              kind: switch (request) {
                ApprovalRequest() => PendingKind.approval,
                ClarifyRequest() => PendingKind.question,
                _ => PendingKind.input,
              },
              requestId: request.requestId,
              seenAt: first,
            ),
          );
        }
      }
    }
    _requestSeen
      ..clear()
      ..addAll(seen);
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ChatHints(
      profile: _profile,
      threads: threads.take(kMaxRecentChats).toList(),
      requests: requests,
    );
  }
}
