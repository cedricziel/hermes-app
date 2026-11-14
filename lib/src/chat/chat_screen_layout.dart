part of 'chat_screen.dart';

/// Responsive chat layout and the compact list/detail navigator.
extension _ChatScreenLayout on _ChatScreenState {
  Widget _buildScreen(BuildContext context) {
    final chat = _chat;
    final shellMenu = ShellMenu.button(context);
    final shellBar = buildChatAppBar(
      context,
      leading: shellMenu,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Chats'),
          if (_chat.profile != null)
            Text(
              _recipient.label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      actions: [
        NamedIconButton(
          label: 'New message',
          icon: AppIcons.compose,
          onPressed: _newThread,
        ),
      ],
    );
    if (chat.loadingThreads) {
      return Scaffold(
        appBar: shellBar,
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (chat.threadsFailed) {
      return Scaffold(
        appBar: shellBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your chats'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: chat.loadThreads,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    _mac = platformChromeOf(context) == PlatformChrome.macos;
    final macSidebar = hasMacSidebar(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            macSidebar || isWideLayout(context, width: constraints.maxWidth);
        _wide = isWide;
        final selected = chat.selectedThread;
        final bot = selected?.botContext;
        final showFiles = selected != null && filesShown(context)
            ? () => _showFiles(FilesOpenedFrom.header)
            : null;
        // Where the open chat runs, as a line under its title; none for a
        // chat that does not exist yet (its row is above the composer).
        final folderLine = selected != null && workspacesOffered(chat)
            ? folderLineBuilder(chat, selected)
            : null;
        _latestReply.follow(chat, selected);
        final showNewChatFab =
            !isWide && platformChromeOf(context) == PlatformChrome.ios;
        ThreadSidebar buildSidebar({
          Widget? navigation,
          bool fullPage = false,
        }) => ThreadSidebar(
          fullPage: fullPage,
          contentBottomPadding: fullPage && showNewChatFab
              ? NewChatFab.listBottomPadding
              : 0,
          avatarBuilder: (_) => _avatar(24),
          navigation: navigation,
          onOpenInNewWindow: _windows == null
              ? null
              : (thread) => unawaited(_openInWindow(thread)),
          threads: chat.threads
              .where((thread) => !thread.isCanonicalBotChat)
              .toList(),
          selectedId: chat.selectedId,
          onSelect: _pickInSidebar,
          onNewThread: _newThread,
          busy: chat.activeThreads,
          housekeeping: chat.housekeeping,
          search: chat.search,
          onOpenHit: _openHit,
          searchFocus: _searchFocus,
          searchProfile: chat.profile,
          onOpenProfiles: _profiles == null ? null : _openProfiles,
          onOpenMessaging: _messaging == null ? null : _openMessaging,
          onOpenSkills: _skills == null ? null : _openSkills,
          onOpenMemory: _skills == null ? null : _openMemory,
          memoryWaiting: _memoryWaiting?.waiting,
          onOpenPlugins: _plugins == null ? null : _openPlugins,
          onOpenMcp: _mcp == null ? null : _openMcp,
          onOpenProviders: _providersOffered
              ? () => _openProviders(ProvidersEntry.sidebar)
              : null,
          onOpenHelperModels: _models == null ? null : _openHelperModels,
        );

        final toolbar = workingToolbarSubtitle(
          chat,
          selected,
          profile: chat.profile,
          model: _toolbarModelId(),
        );
        final compactMessenger = !isWide && !_mac;
        final macSplit = isWide && _mac;
        final search = chat.search;
        final threadView = Provider<ReadAloud?>.value(
          value: _readAloud,
          child: boundChatThreadView(
            chat: chat,
            recipientChip: ProfileRecipientChip(
              profile: _recipient,
              state: _recipientState,
              avatars: _avatars,
              onTap:
                  selected == null ||
                      !selected.remote && selected.messages.isEmpty
                  ? _changeRecipient
                  : null,
              onRetry: _loadRecipients,
              onSetup: _openProfiles,
            ),
            onSetupModel: _setupModel,
            screen: _screen,
            onOpenScreen: () => _openViewer('preview'),
            onShowAgentDetails: _showAgentDetails,
            needsYou: _needsYou,
            // The inspector lists the same items, so it replaces the line
            // (a phone's sheet covers the chat, so there the line stays); the
            // Mac toolbar's subtitle takes its place on macOS.
            onOpenActivity: _mac || (isWide && _activityOpen)
                ? null
                : () => _toggleActivity(source: 'line'),
            thread: selected,
            greetingName: context.select<AuthController, String?>(
              (auth) => auth.identity?.displayName,
            ),
            sendTarget: () => (_chat.profile, _chat.selectedId),
            composerController: _composerController,
            composerFocus: _composerFocus,
            dictation: _voiceCall?.ended == false
                ? null
                : _dictation?.controller,
            voiceRecording: _voiceCall?.ended == false ? null : _voiceRecording,
            attachments: _attachments,
            attachmentSource: _attachmentSource,
            onAddAttachments: _addAttachments,
            onRemoveAttachment: (file) =>
                _rebuild(() => _attachments.remove(file)),
            onSend: _send,
            slashCommands: _slashCommands,
            commandRunning:
                _slashSending || _queueSending || !_recipientSendAllowed,
            starterPrompts: _showsWelcome ? _starterPrompts() : null,
            onPickStarter: _pickStarter,
            latestReply: _latestReply,
            editable: true,
            branchable: true,
            workingDirectoryRow: BoundWorkingDirectoryRow(chat: chat),
            workspaceNotice: selected == null
                ? null
                : BoundFolderMismatchNotice(chat: chat, thread: selected),
            header: !isWide
                // At a large text size the phone's folder line leaves the bar
                // and becomes a full-width row under it.
                ? (folderLine != null && workingDirectoryLineBelowBar(context)
                      ? folderLine(context, belowBar: true)
                      : null)
                : _mac
                ? ListenableBuilder(
                    listenable: search ?? const AlwaysStoppedAnimation(0),
                    builder: (context, _) => MacChatToolbar(
                      avatar: _avatar(),
                      title: bot?.title ?? selected?.title ?? 'Hermes',
                      subtitle: toolbar.subtitle,
                      subtitleBuilder: toolbar.subtitleBuilder,
                      onNewChat: _newThread,
                      onShowConnection: _showConnection,
                      activityOpen: _activityOpen,
                      activityWaiting: _needsYou.count,
                      onToggleActivity: selected == null
                          ? null
                          : _toggleActivity,
                      onCopyTranscript: selected == null
                          ? null
                          : () => _copyTranscript(selected),
                      onShowFiles: showFiles,
                      folderButton: workspacesOffered(chat)
                          ? BoundFolderToolbarButton(
                              chat: chat,
                              thread: selected,
                            )
                          : null,
                      searchQuery: search?.query ?? '',
                      searchActive: search?.active ?? false,
                      searchFocus: _searchFocus,
                      onSearchBegin: _beginSearch,
                      onSearchChanged: search?.update ?? (_) {},
                      onSearchSubmitted: search?.remember,
                      onSearchEnd: search?.end ?? () {},
                    ),
                  )
                : ChatHeader(
                    thread: selected,
                    avatar: _avatar(),
                    displayTitle: bot?.title,
                    housekeeping: chat.housekeeping,
                    onShowConnection: _showConnection,
                    onNewChat: _newThread,
                    callButton: _callButton,
                    onShowFiles: showFiles,
                    folderLine: folderLine,
                    activityOpen: _activityOpen,
                    activityWaiting: _needsYou.count,
                    onToggleActivity: selected == null ? null : _toggleActivity,
                  ),
          ),
        );

        final content = isWide
            ? InspectorLayout(
                content: threadView,
                shown: _activityOpen && selected != null,
                inspector: BoundActivityPanel(
                  chat: chat,
                  thread: selected,
                  screen: _screen,
                  onEnlargeScreen: () => _openViewer('card'),
                  selection: _agentSelection,
                ),
                panelKey: const Key('activity-inspector'),
                onDismissOverlay: _toggleActivity,
              )
            : threadView;

        final scaffold = Scaffold(
          key: _scaffoldKey,
          drawer: isWide || compactMessenger
              ? null
              : Drawer(
                  width: 280,
                  child: buildSidebar(navigation: widget.navigation),
                ),
          appBar: isWide
              ? null
              : buildChatAppBar(
                  context,
                  leading: compactMessenger
                      ? BackButton(onPressed: _showChats)
                      : null,
                  title: Row(
                    children: [
                      _avatar(),
                      const SizedBox(width: 8),
                      Expanded(
                        child:
                            folderLine != null &&
                                bot == null &&
                                !workingDirectoryLineBelowBar(context)
                            ? folderLine(
                                context,
                                belowBar: false,
                                title: selected?.title ?? 'New message',
                              )
                            : Text(
                                bot?.title ?? selected?.title ?? 'New message',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  actions: [
                    ?_callButton,
                    if (selected != null && selected.remote)
                      ThreadActionsButton(
                        key: const Key('header-thread-actions'),
                        thread: selected,
                        housekeeping: chat.housekeeping,
                        includeCopyTranscript: true,
                        onShowFiles: showFiles,
                      ),
                    if (selected != null)
                      ActivityButton(
                        open: false,
                        waiting: _needsYou.count,
                        onPressed: _toggleActivity,
                      ),
                    NewChatButton(onPressed: _newThread),
                  ],
                ),
          body: macSplit
              ? MacSplitView(
                  sidebar: buildSidebar(navigation: widget.navigation),
                  content: content,
                )
              : Row(
                  children: [
                    if (isWide)
                      SizedBox(
                        width: 280,
                        child: buildSidebar(navigation: widget.navigation),
                      ),
                    if (isWide) const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                ),
        );
        if (compactMessenger) {
          final phone = NavigatorPopHandler<Object?>(
            onPopWithResult: (_) => _showChats(),
            child: Navigator(
              key: _conversationNavigator,
              pages: [
                MaterialPage<void>(
                  key: const ValueKey('chats-home'),
                  child: Scaffold(
                    key: _chatsScaffoldKey,
                    drawer: Drawer(
                      child: ShellSidebar(
                        navigation: Column(
                          children: [
                            if (widget.navigation != null) widget.navigation!,
                            if (_profiles != null)
                              SidebarAction(
                                icon: AppIcons.person,
                                label: 'Profiles',
                                onTap: _openProfiles,
                              ),
                            if (_skills != null)
                              SidebarAction(
                                icon: AppIcons.extension,
                                label: 'Skills',
                                onTap: _openSkills,
                              ),
                            if (_skills != null)
                              SidebarAction(
                                icon: AppIcons.memory,
                                label: memoryEntryLabel(
                                  _memoryWaiting?.waiting,
                                ),
                                onTap: _openMemory,
                              ),
                            if (_messaging != null)
                              SidebarAction(
                                icon: AppIcons.bot,
                                label: 'Messaging',
                                onTap: _openMessaging,
                              ),
                            if (_plugins != null)
                              SidebarAction(
                                icon: AppIcons.extension,
                                label: 'Plugins',
                                onTap: _openPlugins,
                              ),
                            if (_mcp != null)
                              SidebarAction(
                                icon: AppIcons.power,
                                label: 'MCP servers',
                                onTap: _openMcp,
                              ),
                            if (_providersOffered)
                              SidebarAction(
                                icon: AppIcons.hub,
                                label: context.l10n.providersListTitle,
                                onTap: () =>
                                    _openProviders(ProvidersEntry.drawer),
                              ),
                            if (_models != null)
                              SidebarAction(
                                icon: AppIcons.tune,
                                label: 'Helper models',
                                onTap: _openHelperModels,
                              ),
                          ],
                        ),
                      ),
                    ),
                    appBar: buildChatAppBar(
                      context,
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Chats'),
                          if (_chat.profile != null)
                            Text(
                              _recipient.label,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                      leading: NamedIconButton(
                        key: const Key('shell-menu'),
                        label: MaterialLocalizations.of(context)
                            .openAppDrawerTooltip,
                        icon: AppIcons.menu,
                        onPressed: () =>
                            _chatsScaffoldKey.currentState?.openDrawer(),
                      ),
                      actions: [
                        NamedIconButton(
                          label: 'New message',
                          icon: AppIcons.compose,
                          onPressed: _newThread,
                        ),
                      ],
                    ),
                    body: buildSidebar(fullPage: true),
                    floatingActionButton: showNewChatFab
                        ? NewChatFab(onPressed: _newThread)
                        : null,
                  ),
                ),
                if (_detailOpen)
                  MaterialPage<void>(
                    key: const ValueKey('conversation-detail'),
                    child: scaffold,
                  ),
              ],
              onDidRemovePage: (page) {
                if (page.key == const ValueKey('conversation-detail') &&
                    mounted) {
                  _rebuild(() => _detailOpen = false);
                }
              },
            ),
          );
          return MacCommandScope(
            commands: {
              MacCommand.find: MacCommandHandler(
                !_detailOpen && search != null ? _focusSidebarSearch : null,
              ),
            },
            child: phone,
          );
        }
        if (platformChromeOf(context) != PlatformChrome.ios) return scaffold;
        return MacCommandScope(
          commands: {
            MacCommand.find: MacCommandHandler(
              isWide && search != null ? _focusSidebarSearch : null,
            ),
          },
          child: scaffold,
        );
      },
    );
  }
}
