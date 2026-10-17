part of 'chat_screen.dart';

/// Account-scoped recipient discovery, selection, and new chats.
extension _ChatScreenRecipients on _ChatScreenState {
  void _checkAvatarOwner() {
    final auth = _avatarAuth;
    if (auth == null || auth.ownerGeneration == _avatarOwner) return;
    _avatarOwner = auth.ownerGeneration;
    _avatars?.dispose();
    _avatars = null;
    _recipients = const [];
    _profilesUnsupported = false;
    _recipientsLoading = false;
    _recipientsFailed = false;
    _recipientRead++;
    _recipientIntent++;
    _composerController.clear();
    _attachments.clear();
    _drafts.clear();
    _draftFiles.clear();
    _composerThread = null;
    _draftOwners.clear();
    if (mounted) _rebuild(() {});
  }

  Future<void> _loadRecipients() async {
    await _recipientOptions();
  }

  RecipientSelectorState get _recipientState {
    if (_profiles == null || _profilesUnsupported) {
      return RecipientSelectorState.ready;
    }
    if (_recipientsLoading) return RecipientSelectorState.loading;
    if (_recipientsFailed) return RecipientSelectorState.failed;
    if (_recipients.isEmpty) return RecipientSelectorState.empty;
    if (_chat.profile == null) {
      return _chat.loadingThreads
          ? RecipientSelectorState.loading
          : RecipientSelectorState.choose;
    }
    return _recipients.any((profile) => profile.name == _chat.profile)
        ? RecipientSelectorState.ready
        : RecipientSelectorState.unavailable;
  }

  bool get _recipientSendAllowed =>
      _recipientState == RecipientSelectorState.ready;

  HermesProfile get _recipient =>
      _recipients
          .where((profile) => profile.name == _chat.profile)
          .firstOrNull ??
      HermesProfile(
        name: _chat.profile ?? '',
        displayName: _chat.profile == null ? 'Hermes' : '',
      );

  Widget _avatar([double size = 32]) =>
      ProfileAvatar(profile: _recipient, size: size, repository: _avatars);

  Future<({List<HermesProfile> profiles, bool failed})>
  _recipientOptions() async {
    final generation = ++_recipientRead;
    final owner = _avatarAuth?.ownerGeneration;
    bool current() =>
        mounted &&
        generation == _recipientRead &&
        owner == _avatarAuth?.ownerGeneration;
    _rebuild(() {
      _recipientsLoading = true;
      _recipientsFailed = false;
    });
    try {
      final profiles = await _profiles!.list();
      if (!current()) return (profiles: const <HermesProfile>[], failed: true);
      _rebuild(() {
        _recipients = profiles;
        _recipientsLoading = false;
        _profilesUnsupported = false;
      });
      return (profiles: profiles, failed: false);
    } on Object catch (error) {
      if (current()) {
        final unsupported =
            error is DioException && error.response?.statusCode == 404;
        _rebuild(() {
          _recipientsLoading = false;
          _profilesUnsupported = unsupported;
          _recipientsFailed = !unsupported;
        });
      }
      return (profiles: const <HermesProfile>[], failed: true);
    }
  }

  Future<HermesProfile?> _pickRecipient() async {
    final repository = _profiles;
    if (repository == null || _profilesUnsupported && _chat.profile == null) {
      return _recipient;
    }
    final owner = _avatarAuth?.ownerGeneration;
    var pending = _recipientOptions();
    return showDialog<HermesProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
            child: FutureBuilder<({List<HermesProfile> profiles, bool failed})>(
              future: pending,
              builder: (context, snapshot) => RecipientPicker(
                profiles: snapshot.data?.profiles ?? const [],
                selectedProfile: _chat.profile,
                loading: snapshot.connectionState != ConnectionState.done,
                failed: snapshot.data?.failed ?? false,
                onRetry: () => update(() {
                  pending = _recipientOptions();
                }),
                onSetup: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openProfiles());
                },
                avatars: _avatars,
                onSelected: (profile) {
                  if (!mounted || owner != _avatarAuth?.ownerGeneration) {
                    Navigator.of(dialogContext).pop();
                    return;
                  }
                  Navigator.of(dialogContext).pop(profile);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeRecipient() async {
    final previousOwner = _composerOwner;
    final draft = _composerController.value;
    final files = List.of(_attachments);
    final owner = _avatarAuth?.ownerGeneration;
    final link = _linkSeq;
    final target = await _newThread();
    if (mounted &&
        target != null &&
        owner == _avatarAuth?.ownerGeneration &&
        link == _linkSeq &&
        target.$1 == _chat.profile &&
        target.$2 == _chat.selectedThread &&
        target.$2.messages.isEmpty) {
      _drafts.remove(previousOwner);
      _draftFiles.remove(previousOwner);
      _composerController.value = draft;
      _rebuild(
        () => _attachments
          ..clear()
          ..addAll(files),
      );
    }
  }

  Future<(String?, ChatThread)?> _newThread() async {
    final intent = ++_recipientIntent;
    final link = _linkSeq;
    final owner = _avatarAuth?.ownerGeneration;
    bool current() =>
        mounted &&
        intent == _recipientIntent &&
        link == _linkSeq &&
        owner == _avatarAuth?.ownerGeneration;
    final profile = await _pickRecipient();
    if (!current() || profile == null) return null;
    if (_chat.repository != null &&
        profile.name.isNotEmpty &&
        (_chat.loadingThreads || _chat.profile != profile.name)) {
      await _chat.loadThreads(profile.name);
      if (!current() || _chat.threadsFailed || _chat.profile != profile.name) {
        return null;
      }
    }
    _startThread();
    final thread = _chat.selectedThread;
    return thread == null ? null : (_chat.profile, thread);
  }

  void _startThread() {
    _recipientIntent++;
    _showDetail();
    _handoff?.cancel();
    _chat.newThread();
    _closeDrawerIfNarrow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }
}
