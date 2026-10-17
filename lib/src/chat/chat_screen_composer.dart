part of 'chat_screen.dart';

/// Slash command discovery, starter prompts, and prompt submission.
extension _ChatScreenComposer on _ChatScreenState {
  void _onComposerText() {
    if (!_composerController.text.startsWith('/')) {
      _slashContext = null;
      _slashFetchGeneration++;
      return;
    }
    final contextKey = '${_chat.profile}\u0000${_chat.selectedId}';
    if (_slashContext == contextKey) return;
    _slashContext = contextKey;
    final generation = ++_slashFetchGeneration;
    _rebuild(() => _slashCommands = const []);
    _chat
        .slashCommands()
        .then((commands) {
          if (mounted &&
              _slashContext == contextKey &&
              _slashFetchGeneration == generation) {
            _rebuild(() => _slashCommands = commands);
          }
        })
        .catchError((Object _) {
          if (mounted &&
              _slashContext == contextKey &&
              _slashFetchGeneration == generation) {
            _rebuild(() => _slashCommands = const []);
          }
        });
  }

  bool get _showsWelcome => _chat.selectedThread?.messages.isEmpty ?? true;

  /// Reads the starter context again for another profile, or once it is
  /// older than the loader's max age. Called while the welcome view is shown,
  /// on a controller change or when the app comes back.
  void _refreshStarter() {
    final loader = _starterLoader;
    if (loader == null) return;
    final profile = _chat.profile;
    final last = _starterRequest;
    final sameProfile = last != null && last.profile == profile;
    if (sameProfile && DateTime.now().difference(last.at) < loader.maxAge) {
      return;
    }
    if (!sameProfile) _starter = null;
    _starterRequest = (profile: profile, at: DateTime.now());
    loader.load(profile).then((context) {
      if (!mounted || _chat.profile != profile) return;
      _rebuild(() => _starter = context);
    });
  }

  List<StarterPrompt> _starterPrompts() {
    final context = _starter;
    if (context == null) return kGenericStarterPrompts;
    ChatThread? thread;
    for (final t in _chat.threads) {
      if (!t.remote || t.id == _chat.selectedId || t.title == kUntitledChat) {
        continue;
      }
      if (thread == null || t.updatedAt.isAfter(thread.updatedAt)) thread = t;
    }
    return buildStarterPrompts(
      StarterContext(
        failedJob: context.failedJob,
        kanbanTask: context.kanbanTask,
        recentChat: thread == null
            ? null
            : StarterChat(id: thread.id, title: thread.title),
        skill: context.skill,
      ),
    );
  }

  void _pickStarter(StarterPrompt prompt) {
    switch (prompt.action) {
      case StarterAction.send:
        _send(prompt.text);
      case StarterAction.prefill:
        _rebuild(
          () => _composerController.value = TextEditingValue(
            text: prompt.text,
            selection: TextSelection.collapsed(offset: prompt.text.length),
          ),
        );
      case StarterAction.openThread:
        _selectThread(prompt.threadId!);
    }
  }

  /// The package composer reports attachments-only sends as an empty [text].
  Future<void> _send(String text) async {
    if (_queueSending) return;
    if (_slashSending) return;
    if (_leaveToWindow(
      _chat.selectedThread?.id,
      () => unawaited(_send(text)),
    )) {
      return;
    }
    final typed = text.trim();
    final files = List.of(_attachments);
    if (typed.isEmpty && files.isEmpty) return;
    if (typed.startsWith('/')) {
      if (files.isNotEmpty) {
        _showMessage('Remove attachments before running a slash command.');
        return;
      }
      unawaited(_sendSlash(typed));
      return;
    }
    if (!_recipientSendAllowed || !_chat.modelSendAllowed) return;
    _rebuild(() => _queueSending = true);
    final target = _chat.selectedThread;
    final profile = _chat.profile;
    bool accepted;
    try {
      accepted = await _chat.submit(typed, files);
    } on Object {
      _showMessage('Could not send this prompt. Your draft was kept.');
      return;
    } finally {
      if (mounted) _rebuild(() => _queueSending = false);
    }
    if (!mounted) return;
    if (!accepted ||
        profile != _chat.profile ||
        target != null && target != _chat.selectedThread ||
        _composerController.text.trim() != typed ||
        _attachments.length != files.length ||
        !files.every(_attachments.contains)) {
      return;
    }
    _rebuild(() {
      _composerController.clear();
      _attachments.clear();
    });
  }

  Future<void> _sendSlash(String command) async {
    if (_slashSending) return;
    _rebuild(() => _slashSending = true);
    try {
      if (!await _chat.runSlashCommand(command) || !mounted) return;
      if (_composerController.text.trim() == command) {
        _composerController.clear();
      }
    } finally {
      _slashSending = false;
      if (mounted) _rebuild(() {});
    }
  }
}
