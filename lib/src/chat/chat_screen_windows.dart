part of 'chat_screen.dart';

/// Conversation-window routing, Dock actions, and Handoff advertisement.
extension _ChatScreenWindows on _ChatScreenState {
  /// Shows a chat where it already is: in its conversation window when one is
  /// open, otherwise in this window, including a chat outside the loaded
  /// pages or on another profile. With [raiseMain] the main window comes
  /// forward first, which may be hidden.
  Future<({bool opened, bool inWindow})> _showChat(
    String threadId,
    String profile,
    bool Function() valid, {
    bool raiseMain = false,
    void Function(int generation)? onRestoring,
  }) async {
    final window = _windows?.windowFor(threadId, profile);
    if (window != null && await _windows!.focus(window.windowId)) {
      return (opened: true, inWindow: true);
    }
    if (raiseMain) unawaited(_windows?.showMainWindow());
    // The restore takes the next generation synchronously.
    onRestoring?.call(_chat.openGeneration + 1);
    final opened = await _chat.restoreHandoff(
      NotificationTarget(threadId: threadId, profile: profile),
      valid,
    );
    if (opened && valid() && mounted) {
      widget.onShowChat?.call();
      _advertise();
    }
    return (opened: opened, inWindow: false);
  }

  /// A chat picked in the Dock menu. The menu may be a few seconds old, so a
  /// chat that is gone reports the failure and creates nothing.
  Future<DockOpenResult> _openFromDock(String id, String profile) async {
    _handoff?.cancel();
    int? started;
    // A newer open (another pick, a sidebar click) has moved the generation on.
    bool overtaken() => started != null && _chat.openGeneration != started;
    try {
      final shown = await _showChat(
        id,
        profile,
        () => mounted,
        raiseMain: true,
        onRestoring: (generation) => started = generation,
      );
      if (shown.inWindow) return DockOpenResult.inWindow;
      if (shown.opened) return DockOpenResult.inMain;
      if (overtaken()) return DockOpenResult.superseded;
      _showMessage(couldNotOpenChat);
      return DockOpenResult.unavailable;
    } on Object catch (error) {
      if (overtaken()) return DockOpenResult.superseded;
      _showMessage(couldNotOpenChat);
      return error is DioException
          ? DockOpenResult.network
          : DockOpenResult.failed;
    }
  }

  /// New Chat from the Dock menu, which may have been picked on another page.
  void _newChatFromDock() {
    _startThread();
    widget.onShowChat?.call();
  }

  void _syncDock() => _dock?.setChats(_chat.threads, _chat.profile);

  /// Reads again the chats of this profile that have been open in a
  /// conversation window, which may have changed them.
  void _refreshFromWindows() {
    _chat.checkConnection();
    for (final chat in _windows?.touched ?? const <ConversationRef>[]) {
      if (chat.profile == _chat.profile) _chat.refreshThread(chat.threadId);
    }
  }

  /// Opens [thread] in a conversation window of its own (macOS). Once the
  /// window is up, the selected chat leaves the main window, so only its
  /// window answers, retries, stops or sends in it; a new window takes over
  /// what the composer held.
  Future<void> _openInWindow(ChatThread? thread) async {
    final windows = _windows;
    if (windows == null || thread == null || !thread.remote) return;
    final selected = thread.id == _chat.selectedId;
    final hasWindow = windows.windowFor(thread.id, _chat.profile) != null;
    final draft = selected && !hasWindow
        ? ConversationDraft(
            text: _composerController.text,
            files: List.of(_attachments),
          )
        : null;
    final shown = await windows.open(
      thread.id,
      profile: _chat.profile,
      title: thread.title,
      draft: draft == null || draft.isEmpty ? null : draft,
    );
    if (!shown || !mounted || _chat.selectedId != thread.id) return;
    // Only what went to the window; anything typed meanwhile stays.
    if (draft != null && _composerController.text == draft.text) {
      _rebuild(() {
        _composerController.clear();
        _attachments.removeWhere(draft.files.contains);
      });
    }
    final remaining = _composerController.value;
    final remainingFiles = List.of(_attachments);
    _chat.clearSelection();
    _composerController.value = remaining;
    _attachments
      ..clear()
      ..addAll(remainingFiles);
  }

  /// Offers the chat in front for Handoff: a key conversation window's, or
  /// else the one selected here.
  void _advertise() {
    if (!mounted) return;
    if (_windows?.keyWindow?.args case final args?) {
      return _handoff?.advertise(
        args.profile == null
            ? null
            : HandoffActivity.parse({
                'version': 1,
                'serverUrl': args.baseUrl,
                'profile': args.profile,
                'threadId': args.threadId,
              }),
      );
    }
    final thread = _chat.selectedThread;
    final server = _maybeRead<AuthController>()?.baseUrl;
    final profile = _chat.profile;
    _handoff?.advertise(
      widget.visible &&
              ModalRoute.of(context)?.isCurrent != false &&
              thread?.remote == true &&
              server != null &&
              profile != null
          ? HandoffActivity.parse({
              'version': 1,
              'serverUrl': server,
              'profile': profile,
              'threadId': thread!.id,
            })
          : null,
    );
  }

  /// A chat is followed by one engine at a time: when [id] has a
  /// conversation window, brings that up and returns true. Should the
  /// window turn out to be gone, [instead] runs once it has been forgotten.
  bool _leaveToWindow(String? id, VoidCallback instead) {
    final window = id == null ? null : _windows?.windowFor(id, _chat.profile);
    if (window == null) return false;
    unawaited(
      _windows!.focus(window.windowId).then((shown) {
        if (!shown && mounted) instead();
      }),
    );
    return true;
  }

  /// A click on a sidebar row; a second one on the same row within the
  /// double-click time opens the chat in a window of its own (macOS).
  void _pickInSidebar(String id) {
    final now = clock.now();
    final last = _lastPick;
    _lastPick = (id: id, at: now);
    if (_windows != null &&
        last != null &&
        last.id == id &&
        now.difference(last.at) <= kDoubleTapTimeout) {
      _lastPick = null;
      final thread = _chat.threads.where((t) => t.id == id).firstOrNull;
      return unawaited(_openInWindow(thread));
    }
    _selectThread(id);
  }
}
