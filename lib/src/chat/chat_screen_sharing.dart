part of 'chat_screen.dart';

/// Share delivery and attachment/composer prefill.
extension _ChatScreenSharing on _ChatScreenState {
  void _onShared() => _queueShared(
    held: _share.deliveringInitial,
    isLaunch: _share.deliveringInitial,
  );

  void _queueShared({bool held = false, bool isLaunch = false, int? entry}) {
    if (!_share.hasPending) return;
    void deliver() {
      if (!mounted || !_share.hasPending) return;
      widget.onShowChat?.call();
      _rebuild(() => _absorbShared(held: held));
    }

    final navigate = widget.onExternalNavigation;
    if (entry != null && widget.onShareEntry != null) {
      widget.onShareEntry!(deliver, entry);
    } else if (navigate == null) {
      deliver();
    } else {
      navigate(deliver, isLaunch);
    }
  }

  /// Takes what was shared. [held] says it was waiting before this screen
  /// existed, i.e. through setup, sign-in or a reconnect.
  void _absorbShared({bool held = false}) {
    if (_chat.loadingThreads || _chat.threadsFailed) {
      _pendingShare = (
        held: held || (_pendingShare?.held ?? false),
        link: _linkSeq,
        owner: _avatarAuth?.ownerGeneration,
      );
      return;
    }
    final items = _share.take();
    if (items.isEmpty) return;
    _detailOpen = true;

    final shared = items.whereType<SharedText>().map((i) => i.text).join('\n');
    if (shared.isNotEmpty) _appendToComposer(shared);
    _attachments.addAll(items.whereType<SharedFile>());
    final quote = items.whereType<SharedQuote>().lastOrNull;
    if (quote != null) _openQuote(quote, held: held);
  }

  /// Puts text selected in another app, quoted, into the composer of a new
  /// chat. Sends nothing. While the threads load the quote waits, and a later
  /// one replaces it: loading swaps the thread list, which would drop a new
  /// chat made earlier.
  void _openQuote(SharedQuote quote, {required bool held}) {
    _pendingQuote = (quote: quote, held: held);
    if (!_chat.loadingThreads) _deliverQuote();
  }

  void _deliverQuote() {
    final pending = _pendingQuote;
    if (pending == null) return;
    _pendingQuote = null;
    (_maybeRead<Breadcrumbs>() ?? Breadcrumbs.none)('chat.share.quote', {
      'held': pending.held,
    });
    _appendToComposer(pending.quote.asBlockQuote, separator: '\n\n');
    final draft = _composerController.value;
    final files = List.of(_attachments);
    final link = _linkSeq;
    final owner = _avatarAuth?.ownerGeneration;
    bool current() =>
        mounted && link == _linkSeq && owner == _avatarAuth?.ownerGeneration;
    _handoff?.cancel();
    // After a frame: a chat opened from a launch or a tap is set up by then.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!current()) return;
      await _chat.newThreadWhenOpened(valid: current);
      if (!current()) return;
      _showDetail();
      _composerController.value = draft;
      _attachments
        ..clear()
        ..addAll(files);
      _closeDrawerIfNarrow();
      _composerFocus.requestFocus();
    });
  }

  /// Adds [text] under whatever the user has already typed, sending nothing.
  void _appendToComposer(String text, {String separator = '\n'}) {
    final draft = _composerController.text;
    final combined = draft.isEmpty ? text : '$draft$separator$text';
    _composerController.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  void _addAttachments(List<SharedFile> files) {
    final added = newAttachments(_attachments, files);
    if (added.isEmpty) return;
    _rebuild(() => _attachments.addAll(added));
  }
}
