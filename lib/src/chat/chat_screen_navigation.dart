part of 'chat_screen.dart';

/// Chat selection, commands, inspectors, and related destinations.
extension _ChatScreenNavigation on _ChatScreenState {
  void _showChats() {
    _composerFocus.unfocus();
    _rebuild(() => _detailOpen = false);
  }

  void _showDetail() {
    if (!mounted) return;
    _rebuild(() => _detailOpen = true);
    _scaffoldKey.currentState?.closeDrawer();
  }

  /// Puts the cursor in the composer of the new chat a window opens on, so
  /// typing can start at once. A phone opens on the chat list, and focus that
  /// something else took meanwhile stays where it is.
  void _focusComposerOnLaunch() {
    if (!mounted || !_showsWelcome || !(_wide || _mac || _detailOpen)) return;
    if (_maybeRead<AppLockController>()?.covered ?? false) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null && focused is! FocusScopeNode) return;
    _composerFocus.requestFocus();
  }

  /// Opens the toolbar search of a Mac window and puts the cursor in it. A
  /// compact window shows the sidebar too, where the results go.
  void _beginSearch() {
    final search = _chat.search;
    if (search == null) return;
    if (!search.active) {
      search.begin();
      final sidebar = MacSidebarScope.read(context);
      if (isMacCompact(context) && sidebar != null && !sidebar.overlayOpen) {
        sidebar.toggle(compact: true);
      }
    }
    if (_searchFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _openHit(ThreadSearchHit hit) {
    _showDetail();
    _chat.openSearchHit(hit);
    _closeDrawerIfNarrow();
  }

  /// Puts the cursor in the sidebar's search field, which an iPad shows beside
  /// the chat.
  void _focusSidebarSearch() => _searchFocus.requestFocus();

  /// Opens the Activity panel: the inspector beside or over a wide chat, a
  /// sheet on a phone. A second call closes the inspector.
  void _toggleActivity({String source = 'button'}) {
    final crumbs = _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none;
    if (_wide) {
      _rebuild(() => _activityOpen = !_activityOpen);
      crumbs(_activityOpen ? 'chat.activity.opened' : 'chat.activity.closed', {
        'surface': 'inspector',
        if (_activityOpen) 'source': source,
      });
      return;
    }
    final thread = _chat.selectedThread;
    if (thread == null) return;
    crumbs('chat.activity.opened', {'surface': 'sheet', 'source': source});
    final sheet = showKanbanDetentSheet(
      context,
      (controller) => BoundActivityPanel(
        chat: _chat,
        thread: thread,
        scrollController: controller,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
    unawaited(
      sheet.then((_) => crumbs('chat.activity.closed', {'surface': 'sheet'})),
    );
  }

  /// What the menu bar's File and Chat menus do here.
  Map<MacCommand, MacCommandHandler> _menuCommands({required bool ios}) {
    final thread = _chat.selectedThread;
    final housekeeping = _chat.housekeeping;
    final managed = thread != null && thread.remote && housekeeping != null;
    VoidCallback? on(ThreadAction action, {required bool when}) => when
        ? () => runThreadAction(
            context,
            action,
            thread: thread!,
            housekeeping: housekeeping,
          )
        : null;
    return {
      MacCommand.newChat: MacCommandHandler(_startThread),
      MacCommand.openInNewWindow: MacCommandHandler(
        _windows != null && thread != null && thread.remote
            ? () => unawaited(_openInWindow(thread))
            : null,
      ),
      // An iPad's Find is offered from the layout, where the sidebar is known.
      if (!ios)
        MacCommand.find: MacCommandHandler(
          _chat.search == null ? null : _beginSearch,
        ),
      MacCommand.pinThread: MacCommandHandler(
        on(ThreadAction.pin, when: managed),
        title: thread?.pinned ?? false ? 'Unpin' : 'Pin',
      ),
      MacCommand.renameThread: MacCommandHandler(
        on(ThreadAction.rename, when: managed && !thread.isCanonicalBotChat),
      ),
      MacCommand.copyTranscript: MacCommandHandler(
        on(
          ThreadAction.copyTranscript,
          when: thread != null && thread.messages.isNotEmpty,
        ),
      ),
      MacCommand.archiveThread: MacCommandHandler(
        on(ThreadAction.archive, when: managed),
      ),
      MacCommand.toggleInspector: MacCommandHandler(
        thread == null ? null : () => _toggleActivity(source: 'menu'),
        title: _activityOpen ? 'Hide Inspector' : 'Show Inspector',
      ),
      MacCommand.deleteThread: MacCommandHandler(
        on(ThreadAction.delete, when: managed),
      ),
    };
  }

  void _copyTranscript(ChatThread thread) => runThreadAction(
    context,
    ThreadAction.copyTranscript,
    thread: thread,
    housekeeping: thread.remote ? _chat.housekeeping : null,
  );

  /// "profile · model" under the chat's title, leaving out what is unknown.
  String? _toolbarSubtitle() {
    final model = (_chat.modelChoice ?? _chat.modelOptions?.current)?.modelId;
    final parts = [?_chat.profile, ?model];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  void _selectThread(String id) {
    _showDetail();
    if (_leaveToWindow(id, () => _selectThread(id))) return;
    _handoff?.cancel();
    _chat.select(id);
    _closeDrawerIfNarrow();
  }

  Future<void> _openProfiles() async {
    final owner = _avatarAuth?.ownerGeneration;
    _closeDrawerIfNarrow();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          repository: _profiles,
          models: _chat.models,
          chatProfile: _chat.profile,
          onSwitched: _chat.repository == null ? null : _chat.loadThreads,
        ),
      ),
    );
    if (!mounted || owner != _avatarAuth?.ownerGeneration) return;
    if (_profiles != null) await _loadRecipients();
    if (!mounted || owner != _avatarAuth?.ownerGeneration) return;
    await _chat.refreshModelOptions();
  }

  Future<void> _setupModel() async {
    final profile = _chat.profile;
    final owner = _avatarAuth?.ownerGeneration;
    await showModelSetup(context, profile);
    if (!mounted ||
        owner != _avatarAuth?.ownerGeneration ||
        profile != _chat.profile) {
      return;
    }
    await _chat.refreshModelOptions();
  }

  void _openMessaging() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagingScreen(
          repository: _messaging?.forProfile(_chat.profile),
          changeSource: _chat.transport is GatewayConnectionTransport
              ? _chat.transport as GatewayConnectionTransport
              : null,
        ),
      ),
    );
  }

  /// Skills asks for a message to be drafted when the user wants the agent to
  /// delete a skill; it is put in the composer for the user to send.
  Future<void> _openSkills() async {
    _closeDrawerIfNarrow();
    final draft = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            SkillsScreen(repository: _skills, chatProfile: _chat.profile),
      ),
    );
    if (draft == null || !mounted) return;
    widget.onShowChat?.call();
    _rebuild(() => _appendToComposer(draft));
  }

  void _openPlugins() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PluginsScreen(repository: _plugins!.forProfile(_chat.profile)),
      ),
    );
  }

  void _openMcp() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            McpServersScreen(repository: _mcp!, profiles: _profiles),
      ),
    );
  }

  void _openHelperModels() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HelperModelsScreen(repository: _models!, profile: _chat.profile),
      ),
    );
  }

  void _showConnection() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _closeDrawerIfNarrow() {
    MacSidebarScope.read(context)?.closeOverlay();
    if (!isWideLayout(context)) {
      _scaffoldKey.currentState?.closeDrawer();
      _chatsScaffoldKey.currentState?.closeDrawer();
    }
  }
}
