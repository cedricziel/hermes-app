part of 'chat_screen.dart';

/// Notification, deep-link, and menu-bar chat opening intents.
extension _ChatScreenExternalOpenings on _ChatScreenState {
  void _openFromNotification(NotificationTarget target) {
    _notificationTapReceived = true;
    _queueNotification(target);
  }

  void _openLaunchNotification(NotificationTarget target) {
    if (!_notificationTapReceived &&
        _linkSeq == 0 &&
        _chat.openGeneration == 0) {
      _queueNotification(target, isLaunch: true);
    }
  }

  void _queueNotification(NotificationTarget target, {bool isLaunch = false}) {
    final navigate = widget.onExternalNavigation;
    if (navigate == null) {
      _applyNotification(target);
    } else {
      navigate(() {
        if (mounted) _applyNotification(target);
      }, isLaunch);
    }
  }

  void _applyNotification(NotificationTarget target) {
    _handoff?.cancel();
    if (target.isJob) return widget.onOpenJob?.call(target);
    if (target.prompt != null) return _openNewChatFromNotification(target);
    if (target.isMessageSummary) return widget.onShowChat?.call();
    _chat.open(target, fetchMissing: target.isMessage);
  }

  /// A notification about a question that never reached Hermes: a new chat
  /// with the question in the composer, as a `hermes://new?prompt=` link does.
  void _openNewChatFromNotification(NotificationTarget target) {
    widget.openRequests?.requestNew(
      profile: target.profile,
      prompt: target.prompt,
    );
  }

  /// Another destination asked for something. Unlike a notification tap, a
  /// session is fetched when the loaded threads do not hold it, on its own
  /// profile.
  void _onOpenRequest({bool initial = false}) {
    final request = widget.openRequests?.takeRequest();
    if (request == null) return;
    _handoff?.cancel();
    // The latest request wins over any earlier one still waiting or running.
    final link = ++_linkSeq;
    final pending = _pendingShare;
    if (initial && link == 1 && pending?.link == 0) {
      _pendingShare = (held: pending!.held, link: link, owner: pending.owner);
    }
    _whenLoaded = null;
    switch (request) {
      case OpenSessionRequest(:final bot?):
        unawaited(_chat.openBot(bot));
      case OpenSessionRequest(:final target, :final prompt, fromLink: true):
        unawaited(_openLinkedChat(target, prompt, link));
      case OpenSessionRequest(:final target, :final prompt):
        _chat.open(target, fetchMissing: true, prompt: prompt);
      case NewChatRequest():
        _afterThreadsLoad(() => _openNewChat(request, link));
      case OldestPendingRequest():
        _afterThreadsLoad(_openOldestRequest);
    }
  }

  void _afterThreadsLoad(Future<void> Function() work) {
    _whenLoaded = work;
    if (!_chat.loadingThreads) _runWhenLoaded();
  }

  void _runWhenLoaded() {
    final work = _whenLoaded;
    _whenLoaded = null;
    if (work != null) unawaited(work());
  }

  /// A chat from a link. A profile the server lacks is ignored. A chat that
  /// has a window of its own is shown there; otherwise the main window comes
  /// back if it was hidden, and the chat opens in it.
  Future<void> _openLinkedChat(
    NotificationTarget target,
    String? prompt,
    int link,
  ) async {
    final profile = await _chat.knownProfile(target.profile);
    if (!mounted || link != _linkSeq) return;
    final windows = _windows;
    if (windows?.windowFor(target.threadId, profile ?? _chat.profile)
        case final window?) {
      if (await windows!.focus(window.windowId)) return;
      if (!mounted || link != _linkSeq) return;
    }
    unawaited(windows?.showMainWindow());
    _chat.open(
      NotificationTarget(threadId: target.threadId, profile: profile),
      fetchMissing: true,
      prompt: prompt,
    );
  }

  /// A new chat from a link: in its profile if the server has it, with its
  /// text in the composer, sending nothing, and with dictation running when
  /// asked for and offered.
  Future<void> _openNewChat(NewChatRequest request, int link) async {
    bool overtaken() => !mounted || link != _linkSeq;
    unawaited(_windows?.showMainWindow());
    widget.onShowChat?.call();
    final profile = await _chat.knownProfile(request.profile);
    if (overtaken()) return;
    if (profile != null &&
        _chat.repository != null &&
        profile != _chat.profile) {
      await _chat.loadThreads(profile);
      if (overtaken()) return;
      if (_chat.profile != profile) {
        _showMessage('Could not switch profile');
        return;
      }
    }
    final draft = _composerController.value;
    final files = List.of(_attachments);
    await _chat.newThreadWhenOpened(valid: () => !overtaken());
    if (overtaken()) return;
    _composerController.value = draft;
    _attachments
      ..clear()
      ..addAll(files);
    _showDetail();
    _closeDrawerIfNarrow();
    if (request.prompt case final prompt?) _appendToComposer(prompt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
    final dictation = _dictation;
    if (!request.dictate || dictation == null) return;
    await dictation.refresh();
    if (overtaken()) return;
    // The lock may have come on during the waits above.
    final covered = _maybeRead<AppLockController>()?.covered ?? false;
    if (!covered && dictation.controller.available) {
      unawaited(dictation.controller.start());
    }
  }

  /// The chat holding the request that has waited longest, else the chat
  /// list: the drawer on a phone, the sidebar that is already there when wide.
  Future<void> _openOldestRequest() async {
    unawaited(_windows?.showMainWindow());
    // What this profile shows is live; the snapshot only speaks for the
    // others, and a chat it names is kept only if it has a request open.
    if (_chat.openOldestRequest()) return;
    if (await _chat.openOldestStoredRequest() || !mounted) return;
    widget.onShowChat?.call();
    if (!_wide && !_mac) {
      _showChats();
      return;
    }
    if (hasMacSidebar(context)) {
      final sidebar = MacSidebarScope.read(context);
      if (isMacCompact(context) && sidebar != null && !sidebar.overlayOpen) {
        sidebar.toggle(compact: true);
      }
    } else if (!isWideLayout(context)) {
      _chat.clearSelection();
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  /// Text from a link goes under what is typed, so a draft is not lost.
  void _draftFromLink(String text) {
    _appendToComposer(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  /// The menu bar item asks for a chat; opening it puts the chat screen in
  /// front.
  void _openFromMenuBar(NotificationTarget target) {
    _handoff?.cancel();
    _chat.open(target, fetchMissing: true);
  }

  void _newFromMenuBar() {
    widget.onShowChat?.call();
    _startThread();
  }
}
