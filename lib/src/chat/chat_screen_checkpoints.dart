part of 'chat_screen.dart';

/// What the chat screen adds for checkpoints and context: the line after a
/// restore put the last prompt back, and Chat > Compress Conversation….
extension _ChatScreenCheckpoints on _ChatScreenState {
  /// A full restore removed the last prompt: it goes under the draft, and a
  /// line above the composer says so until the next edit.
  void _handBackFromRestore(String text) {
    _draftFromLink(text);
    _rebuild(
      () => _handedBack = (
        owner: (_chat.profile, _chat.selectedId),
        text: _composerController.text,
      ),
    );
  }

  bool get _showsHandBack {
    final handedBack = _handedBack;
    return handedBack != null &&
        handedBack.owner == (_chat.profile, _chat.selectedId) &&
        handedBack.text == _composerController.text;
  }

  /// The composer changed (an edit, a send, another chat's draft): the line
  /// goes.
  void _forgetHandBack() {
    if (_handedBack == null || _showsHandBack) return;
    _rebuild(() => _handedBack = null);
  }

  /// Chat > Compress Conversation…: on while the selected chat can compress
  /// (idle, a live session, connected, not locked, a server that offers it),
  /// and it opens the same confirmation as the Context details page.
  MacCommandHandler _compress() {
    final thread = _chat.selectedThread;
    final entry = widget.onCompressConversation;
    // Without a menu bar nothing here asks for a controller.
    final controller =
        thread == null ||
            !thread.remote ||
            entry == null ||
            MacCommandScope.registryOf(context) == null
        ? null
        : _chat.contextIn(thread);
    _followMenuContext(controller);
    return MacCommandHandler(
      controller != null && controller.canCompress
          ? () => unawaited(entry!(context, controller))
          : null,
      title: context.l10n.macosCompressConversation,
    );
  }

  void _followMenuContext(ContextController? controller) {
    if (identical(controller, _menuContext)) return;
    _menuContext?.removeListener(_menuContextChanged);
    _menuContext = controller?..addListener(_menuContextChanged);
  }

  /// The selected chat started or ended a compress, a reply or a connection:
  /// the menu item follows on the next build.
  void _menuContextChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuild(() {});
      });
    } else {
      _rebuild(() {});
    }
  }
}
