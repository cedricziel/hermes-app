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
      if (!_activityOpen) _agentSelection.clear();
      crumbs(_activityOpen ? 'chat.activity.opened' : 'chat.activity.closed', {
        'surface': 'inspector',
        if (_activityOpen) 'source': source,
      });
      return;
    }
    final thread = _chat.selectedThread;
    if (thread == null) return;
    crumbs('chat.activity.opened', {'surface': 'sheet', 'source': source});
    final grower = _activitySheet = DraggableScrollableController();
    void grow([int tries = 0]) {
      // A detail needs the room: the sheet goes to its full height.
      if (_agentSelection.key == null) return;
      if (grower.isAttached) {
        unawaited(
          grower.animateTo(
            1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      } else if (tries < 8 && mounted) {
        // The sheet is still being pushed.
        WidgetsBinding.instance.addPostFrameCallback((_) => grow(tries + 1));
      }
    }

    _agentSelection.addListener(grow);
    grow();
    final sheet = showKanbanDetentSheet(
      sheet: grower,
      context,
      (controller) => ListenableBuilder(
        // The profile may change while the sheet is open, and with it the
        // screen.
        listenable: _chat,
        builder: (_, _) => BoundActivityPanel(
          chat: _chat,
          thread: thread,
          screen: _screen,
          onEnlargeScreen: () => _openViewer('card'),
          scrollController: controller,
          selection: _agentSelection,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
    unawaited(
      sheet.then((_) {
        crumbs('chat.activity.closed', {'surface': 'sheet'});
        if (mounted) {
          _agentSelection
            ..removeListener(grow)
            ..clear();
        }
        _activitySheet = null;
        grower.dispose();
      }),
    );
  }

  /// Shows an agent's details from the transcript's agent card: the Activity
  /// panel opens at that agent (it only opens, never closes).
  void _showAgentDetails(String agentId) {
    final thread = _chat.selectedThread;
    final roster = thread == null ? null : _chat.subagentsIn(thread);
    if (roster == null) return;
    // The sheet listens for a selection to grow, so it opens first.
    if (_wide ? !_activityOpen : _activitySheet == null) {
      _toggleActivity(source: 'transcript');
    }
    _agentSelection.select(agentKeyOf(roster, agentId), source: 'transcript');
  }

  /// What the menu bar's File and Chat menus do here.
  Map<MacCommand, MacCommandHandler> _menuCommands({
    required bool ios,
    required bool files,
  }) {
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
      // Disabled while the server has no Files, or no chat is open.
      MacCommand.showFiles: MacCommandHandler(
        files && thread != null ? () => _showFiles(FilesOpenedFrom.menu) : null,
      ),
    };
  }

  /// Opens the Files page of the chat in front.
  void _showFiles(FilesOpenedFrom from) {
    _closeDrawerIfNarrow();
    unawaited(openFiles(context, _chat, from: from));
  }

  void _copyTranscript(ChatThread thread) => runThreadAction(
    context,
    ThreadAction.copyTranscript,
    thread: thread,
    housekeeping: thread.remote ? _chat.housekeeping : null,
  );

  /// "profile · model" under the chat's title, leaving out what is unknown.
  String? _toolbarModelId() =>
      (_chat.modelChoice ?? _chat.modelOptions?.current)?.modelId;

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

  /// The composer's "Set up a model": Model providers where the server has it
  /// (on the lost provider when the default's provider lost its key), the
  /// terminal command otherwise.
  Future<void> _setupModel() async {
    if (_providersOffered) {
      _openProviders(ProvidersEntry.composer, focus: _setupFocus());
      return;
    }
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

  Future<void> _openMemory() async {
    _closeDrawerIfNarrow();
    await openMemory(
      context,
      from: MemoryEntryPoint.sidebar,
      profile: _chat.profile,
      transport: _chat.transport,
    );
    if (mounted) unawaited(_memoryWaiting?.refresh(_chat.profile));
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

  /// Whether the Tools entry shows: the server has answered a list.
  bool get _toolsOffered =>
      _tools != null && (_toolsAvailability?.offered ?? false);

  Future<void> _openTools() async {
    _closeDrawerIfNarrow();
    final availability = _toolsAvailability;
    // A chat on the server's default profile names none: use the profile the
    // list was last asked for.
    final profile =
        _chat.profile ??
        availability?.requestedProfile ??
        availability?.profile;
    final tools = profile == null ? null : _tools?.forProfile(profile);
    if (tools == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToolsScreen(
          repository: tools,
          availability: availability,
          // A deleted profile: read the list of profiles again.
          onProfileGone: _profiles == null
              ? null
              : () => unawaited(_loadRecipients()),
        ),
      ),
    );
    // Switches made there change what the entry and the count know.
    if (mounted) unawaited(availability?.refresh(tools.profile));
  }

  /// Whether the Model providers entries show: the server answers the
  /// model options the screen reads (a 404 there means an older Hermes).
  bool get _providersOffered =>
      _providers != null &&
      _chat.modelOptionsState != ModelOptionsState.unsupported;

  /// Where Model providers starts for a profile that cannot chat: on the
  /// provider that lost its key, else at "Add a provider".
  ProvidersFocus _setupFocus() =>
      ProvidersFocus.providerOrAdd(_chat.modelOptions?.missing?.providerId);

  /// The welcome card for a profile with no usable model, or null while the
  /// starter prompts show.
  Widget? _welcomeCard() {
    final data = _providers == null
        ? null
        : connectCardFor(
            _chat.modelOptionsState,
            _chat.modelOptions,
            profile: _chat.profile ?? 'default',
          );
    if (data == null) return null;
    return ConnectModelCard(
      data: data,
      onPressed: data.kind == ConnectCardKind.loading
          ? () => unawaited(_chat.refreshModelOptions())
          : () => _openProviders(
              ProvidersEntry.welcome,
              focus: ProvidersFocus.providerOrAdd(data.providerId),
            ),
    );
  }

  /// A failed reply's "Check model providers": the default model's provider.
  void _checkProviders() => _openProviders(
    ProvidersEntry.reply,
    focus: ProvidersFocus.providerOrAdd(
      _chat.modelOptions?.current?.providerId,
    ),
  );

  void _openProviders(ProvidersEntry source, {ProvidersFocus? focus}) {
    final providers = _providers;
    if (providers == null) return;
    _closeDrawerIfNarrow();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ProvidersScreen(
              repository: providers,
              profile: _chat.profile,
              entry: source,
              focus: focus,
              // The pill and the welcome view follow what the screen did.
              onChanged: () => unawaited(_chat.refreshModelOptions()),
            ),
          ),
        )
        .then((_) {
          if (mounted) unawaited(_chat.refreshModelOptions());
        });
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
