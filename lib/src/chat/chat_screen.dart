import 'dart:async';

import 'package:hermes_app/src/theme/breakpoints.dart';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show noopAppEventLogger;
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';

import '../auth/auth_controller.dart';
import '../auth/session_activity.dart';
import '../background/running_replies.dart';
import '../handoff/handoff_controller.dart';
import '../handoff/handoff_activity.dart';
import '../messaging/messaging_screen.dart';
import '../messaging/hermes_messaging_repository.dart';
import '../mcp/hermes_mcp_repository.dart';
import '../mcp/mcp_servers_screen.dart';
import '../models/hermes_models_repository.dart';
import '../live_activities/live_activities.dart';
import '../app_lock/app_lock_controller.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../plugins/hermes_plugin_manager_repository.dart';
import '../plugins/plugins_screen.dart';
import '../profiles/chat_profiles.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/profiles_screen.dart';
import '../settings/helper_models_screen.dart';
import '../screens/home_screen.dart';
import '../share/share_controller.dart';
import '../share/shared_item.dart';
import '../macos/dock/dock_menu_controller.dart';
import '../macos/mac_commands.dart';
import '../macos/mac_sidebar.dart';
import '../macos/menu_bar_extra/menu_bar_extra_link.dart';
import '../shell/shell_navigation.dart';
import '../skills/hermes_skills_repository.dart';
import '../skills/skills_screen.dart';
import '../surfaces/surface_snapshot_store.dart';
import '../surfaces/surface_snapshots.dart';
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import '../theme/platform_chrome.dart';
import '../windows/conversation_window_args.dart';
import '../windows/conversation_windows.dart';
import 'attachments/attachment_source.dart';
import 'attachments/plugin_attachment_source.dart';
import 'chat_controller.dart';
import 'queue_storage/queue_persistence.dart';
import 'chat_models.dart';
import 'chat_thread_bindings.dart';
import 'chat_open_requests.dart';
import 'chat_transport.dart';
import 'gateway/gateway_connection.dart';
import 'gateway/hermes_gateway_transport.dart';
import 'hermes_chat_repository.dart';
import '../voice/composer_dictation.dart';
import '../voice/dictation_settings.dart';
import '../voice/on_device_speech.dart';
import '../voice/voice_recorder.dart';
import '../watch/watch_complication.dart';
import 'slash_command.dart';
import '../bot_mode/bot_mode_chat_repository.dart';
import 'starter_context_loader.dart';
import 'starter_prompts.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_header.dart';
import 'widgets/mac_chat_toolbar.dart';
import 'widgets/thread_actions_menu.dart';
import 'widgets/thread_sidebar.dart';

/// The chat screen — Hermes's main destination once connected and signed
/// in: an assistant-ui-style thread UI with a persistent thread rail beside a
/// centered message column.
///
/// Threads and messages are read from the dashboard through [repository]
/// (defaulting to the signed-in [AuthController.api]). Messages go out
/// through [transport] and its reply streams into the thread; without one
/// the reply is a canned placeholder. Without any repository the screen shows
/// mock data (see `mock_chat_data.dart`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.repository,
    this.transport,
    this.profiles,
    this.models,
    this.messaging,
    this.skills,
    this.plugins,
    this.mcp,
    this.onShowChat,
    this.onExternalNavigation,
    this.onShareEntry,
    this.attachmentSource,
    this.openRequests,
    this.onOpenJob,
    this.navigation,
    this.starterContext,
    this.visible = true,
    this.shareEntry = 0,
    this.chatProfiles,
    this.voiceRecorder,
  });

  final HermesChatRepository? repository;
  final ChatTransport? transport;
  final HermesProfilesRepository? profiles;
  final HermesModelsRepository? models;
  final HermesMessagingRepository? messaging;
  final HermesSkillsRepository? skills;
  final HermesPluginManagerRepository? plugins;
  final HermesMcpRepository? mcp;

  /// Reads what the welcome view's starter prompts are built from; the
  /// connected dashboard's when null.
  final StarterContextLoader? starterContext;

  /// Asks the host to bring the chat to the front, for a notification tap or
  /// shared content that arrives while something else is shown.
  final VoidCallback? onShowChat;

  /// Lets the host defer notification and share work until it can safely return to its root.
  final void Function(VoidCallback action, bool isLaunch)? onExternalNavigation;

  /// Recovers pending shares only if this explicit Chat entry is still current.
  final void Function(VoidCallback action, int entry)? onShareEntry;

  /// Where the attach control, drops and paste get their files; the platform's
  /// plugins unless a test supplies its own.
  final AttachmentSource? attachmentSource;

  /// Where another destination asks the chat to open a session.
  final ChatOpenRequests? openRequests;

  /// Called for a tapped notification that is about a scheduled task, which
  /// the chat cannot show.
  final void Function(NotificationTarget target)? onOpenJob;

  /// The shell's destinations, shown at the top of the thread sidebar: next to
  /// the chat on a wide layout, in the drawer on a narrow one.
  final Widget? navigation;

  /// Whether the shell currently shows this chat destination.
  final bool visible;

  /// Changes when the user explicitly enters Chat, including reselecting it.
  final int shareEntry;

  /// The profiles the window's sidebar switches between. The chat reports
  /// the profile it shows and follows a switch made there.
  final ChatProfiles? chatProfiles;

  /// The microphone for dictation; the platform's unless a test supplies its
  /// own.
  final VoiceRecorder? voiceRecorder;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _chat;
  HandoffController? _handoff;
  DockMenuController? _dock;
  HermesProfilesRepository? _profiles;
  HermesMessagingRepository? _messaging;
  HermesSkillsRepository? _skills;
  HermesPluginManagerRepository? _plugins;
  HermesMcpRepository? _mcp;
  HermesModelsRepository? _models;
  HermesGatewayTransport? _ownedTransport;
  SessionActivity? _sessionActivity;
  final _composerController = TextEditingController();
  ComposerDictation? _dictation;
  List<SlashCommand> _slashCommands = const [];
  String? _slashContext;
  int _slashFetchGeneration = 0;
  bool _slashSending = false;
  bool _queueSending = false;
  final _composerFocus = FocusNode();
  final List<SharedFile> _attachments = [];
  late final AttachmentSource _attachmentSource;
  late final ShareController _share;

  /// A quote that waits for the threads to load.
  ({SharedQuote quote, bool held})? _pendingQuote;
  late final AttentionNotifier _attention;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFocus = FocusNode();
  Timer? _activeRefreshTimer;
  MenuBarExtraLink? _menuBar;
  bool _activeRefreshInFlight = false;
  bool _foreground = true;

  /// Whether the window is a Mac one, as of the last build.
  bool _mac = false;

  /// The reply of the open thread that can be asked again: its last message,
  /// once that is a finished reply.
  final _latestReply = LatestReply();

  StarterContextLoader? _starterLoader;

  /// Conversation windows (macOS); null elsewhere.
  ConversationWindows? _windows;
  StreamSubscription<void>? _mainFocused;

  /// The quick panel and this window never record at once: whichever starts
  /// last stops the other.
  StreamSubscription<void>? _panelTookVoice;
  var _recording = false;

  /// The last thread picked in the sidebar and when, to tell a double-click.
  ({String id, DateTime at})? _lastPick;

  /// The starter context of the profile last asked for, null until it has
  /// loaded.
  StarterContext? _starter;
  ({String? profile, DateTime at})? _starterRequest;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.openRequests?.addListener(_onOpenRequest);
    final liveActivities = _maybeRead<LiveActivities?>();
    final appLock = _maybeRead<AppLockController>();
    _attention = AttentionNotifier(
      service: _maybeRead<NotificationService>(),
      settings: _maybeRead<NotificationSettings>(),
      onOpen: _openFromNotification,
      activities: liveActivities,
      appLock: () => appLockHidesRequests(appLock),
    );
    final repositories = HermesRepositories.maybeOf(context);
    final api = repositories?.api;
    _profiles = widget.profiles ?? repositories?.profiles;
    _messaging = widget.messaging ?? repositories?.messaging;
    _skills = widget.skills ?? repositories?.skills;
    _plugins = widget.plugins ?? repositories?.pluginManager;
    _mcp = widget.mcp ?? repositories?.mcp;
    _models = widget.models ?? repositories?.models;
    _starterLoader =
        widget.starterContext ??
        (repositories == null ? null : StarterContextLoader(repositories));
    var transport = widget.transport;
    if (transport == null && api != null) {
      final auth = context.read<AuthController>();
      final telemetry = repositories?.telemetry.gateway();
      transport = _ownedTransport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: auth.baseUrl!,
          authRequired: auth.status?.authRequired ?? true,
          api: api,
          telemetry: telemetry,
        ),
        telemetry: telemetry,
        events: repositories?.telemetry.events ?? noopAppEventLogger,
      );
    }
    final auth = _maybeRead<AuthController>();
    if (auth?.verifiedOwner != null) {
      _sessionActivity = SessionActivity(auth!);
    }
    final queues = _maybeRead<QueuePersistence>();
    _chat = ChatController(
      activity: _sessionActivity,
      queueStore: queues?.open,
      queueScope: queues == null
          ? null
          : (thread, profile) => queues.scopeFor(thread.id, profile),
      queueChanges: queues,
      canShowQueues: queues == null ? null : () => queues.visible,
      events: repositories?.telemetry.events ?? noopAppEventLogger,
      usageTelemetry: repositories?.telemetry ?? const ConnectionTelemetry(),
      repository: widget.repository ?? repositories?.chat,
      profiles: _profiles,
      models: _models,
      transport: transport,
      botChats: transport is HermesGatewayTransport
          ? BotModeChatRepository(transport.request)
          : null,
      attention: _attention,
      liveActivities: liveActivities,
      onSurfaceChange: _maybeRead<SurfaceSnapshots?>()?.chatChanged,
      readSnapshot: _maybeRead<SurfaceSnapshotStore?>()?.read,
      watchStatus: _maybeRead<WatchComplicationStatus?>(),
      runningReplies: _maybeRead<RunningReplies?>(),
      report: _showMessage,
      onShowChat: () => widget.onShowChat?.call(),
      onOpenJob: (target) => widget.onOpenJob?.call(target),
      onOpenNewChat: _openNewChatFromNotification,
      onLaunchNotification: _openLaunchNotification,
      onOpened: () => _scaffoldKey.currentState?.closeDrawer(),
      breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      onPrefill: (draft) => _composerController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      ),
      onDraft: _draftFromLink,
    )..addListener(_changed);
    if (_chat.repository case final repository?) {
      final auth = _maybeRead<AuthController>();
      final baseUrl = auth?.baseUrl;
      _dictation = ComposerDictation(
        repository: repository,
        connect: api == null || baseUrl == null
            ? ([_ = const {}]) => Future.error(StateError('No dashboard'))
            : hermesMixedSocketConnect(
                baseUrl: baseUrl,
                authRequired: auth?.status?.authRequired ?? true,
                api: api,
                path: '/api/audio/transcribe-stream',
                telemetry: repositories?.telemetry.gateway(),
              ),
        recorder: widget.voiceRecorder ?? RecordVoiceRecorder(),
        field: _composerController,
        activity: _sessionActivity,
        profile: () => _chat.profile,
        settings: _maybeRead<DictationSettings>(),
        onDevice: _maybeRead<OnDeviceSpeech>(),
        breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      );
      unawaited(_dictation!.refresh());
    }
    _handoff = _maybeRead<HandoffController>();
    _handoff?.bind((activity, valid) async {
      final shown = await _showChat(activity.threadId, activity.profile, valid);
      return shown.opened;
    });
    _dock = _maybeRead<DockMenuController?>()
      ?..bind(this, open: _openFromDock, newChat: _newChatFromDock)
      ..addListener(_syncDock);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onOpenRequest();
    });
    _composerController.addListener(_onComposerText);
    if (_chat.repository != null) {
      _chat.loadThreads();
      widget.chatProfiles?.attach(_chat.loadThreads);
    }
    _attachmentSource = widget.attachmentSource ?? PluginAttachmentSource();
    _share = context.read<ShareController>()..addListener(_onShared);
    if (widget.onExternalNavigation == null) {
      _absorbShared(held: true);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _queueShared(held: true, isLaunch: true);
      });
    }
    _windows = _maybeRead<ConversationWindows?>()?..addListener(_advertise);
    _menuBar = _maybeRead<MenuBarExtraLink?>()
      ?..connect(
        chat: _chat,
        openChat: _openFromMenuBar,
        newChat: _newFromMenuBar,
      );
    _mainFocused = _windows?.mainFocused.listen((_) => _refreshFromWindows());
    _panelTookVoice = _windows?.panelTookVoice.listen(
      (_) => _dictation?.controller.cancel(),
    );
    _dictation?.controller.addListener(_takeVoice);
  }

  void _takeVoice() {
    final recording = _dictation!.controller.busy;
    if (recording && !_recording) unawaited(_windows?.stopPanelDictation());
    _recording = recording;
  }

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
    _newThread();
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
      setState(() {
        _composerController.clear();
        _attachments.removeWhere(draft.files.contains);
      });
    }
    _chat.clearSelection();
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

  void _changed() {
    if (!mounted) return;
    _dictation?.followProfile();
    widget.chatProfiles?.showing(_chat.profile);
    _syncDock();
    setState(() {});
    if (_pendingQuote != null && !_chat.loadingThreads) _deliverQuote();
    if (_whenLoaded != null && !_chat.loadingThreads) _runWhenLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _advertise());
    _onComposerText();
    if (!_chat.loadingThreads && _showsWelcome) _refreshStarter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateActivePolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _advertise());
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shareEntry != oldWidget.shareEntry) {
      final entry = widget.shareEntry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _queueShared(held: true, entry: entry);
      });
    }
    if (widget.visible != oldWidget.visible) {
      _updateActivePolling();
      WidgetsBinding.instance.addPostFrameCallback((_) => _advertise());
    }
  }

  void _updateActivePolling() {
    _activeRefreshTimer?.cancel();
    if (!_foreground ||
        !widget.visible ||
        _chat.transport == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _activeRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_activeRefreshInFlight) return;
      _activeRefreshInFlight = true;
      try {
        await _chat.refreshActive();
      } on Object {
        return;
      } finally {
        _activeRefreshInFlight = false;
      }
    });
  }

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
    setState(() => _slashCommands = const []);
    _chat
        .slashCommands()
        .then((commands) {
          if (mounted &&
              _slashContext == contextKey &&
              _slashFetchGeneration == generation) {
            setState(() => _slashCommands = commands);
          }
        })
        .catchError((Object _) {
          if (mounted &&
              _slashContext == contextKey &&
              _slashFetchGeneration == generation) {
            setState(() => _slashCommands = const []);
          }
        });
  }

  bool get _showsWelcome => _chat.selectedThread?.messages.isEmpty ?? true;

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  var _notificationTapReceived = false;

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
    _chat.open(target, fetchMissing: false);
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
  void _onOpenRequest() {
    final request = widget.openRequests?.takeRequest();
    if (request == null) return;
    _handoff?.cancel();
    // The latest request wins over any earlier one still waiting or running.
    final link = ++_linkSeq;
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

  /// Counts the requests taken, so work for an earlier one can tell it was
  /// overtaken.
  var _linkSeq = 0;

  /// Work a link asked for on the thread list. Loading replaces that list and
  /// would drop a new chat made meanwhile, so it waits for the load to end.
  Future<void> Function()? _whenLoaded;

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
    await _chat.newThreadWhenOpened();
    if (overtaken()) return;
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
    _newThread();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onShared() => _queueShared(
    held: _share.deliveringInitial,
    isLaunch: _share.deliveringInitial,
  );

  void _queueShared({bool held = false, bool isLaunch = false, int? entry}) {
    if (!_share.hasPending) return;
    void deliver() {
      if (!mounted || !_share.hasPending) return;
      widget.onShowChat?.call();
      setState(() => _absorbShared(held: held));
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
    final items = _share.take();
    if (items.isEmpty) return;

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
    _handoff?.cancel();
    // After a frame: a chat opened from a launch or a tap is set up by then.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chat.newThreadWhenOpened();
      if (!mounted) return;
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
    setState(() => _attachments.addAll(added));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateActivePolling();
    if (state case AppLifecycleState.paused || AppLifecycleState.hidden) {
      _dictation?.controller.cancel();
    }
    if (state == AppLifecycleState.paused) _chat.rememberRunningReplies();
    if (!_foreground) return;
    _chat.forgetRunningReplies();
    unawaited(_dictation?.refresh());
    _chat.checkConnection();
    if (!_chat.loadingThreads && _showsWelcome) _refreshStarter();
  }

  @override
  void dispose() {
    _menuBar?.disconnect(_chat);
    _handoff?.bind(null);
    _handoff?.advertise(null);
    _dock
      ?..removeListener(_syncDock)
      ..release(this);
    _activeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.chatProfiles?.attach(null);
    widget.openRequests?.removeListener(_onOpenRequest);
    _share.removeListener(_onShared);
    _mainFocused?.cancel();
    _panelTookVoice?.cancel();
    _windows?.removeListener(_advertise);
    _attention.dispose();
    _chat
      ..removeListener(_changed)
      ..dispose();
    _ownedTransport?.close();
    _dictation?.dispose();
    _sessionActivity?.dispose();
    _composerController.removeListener(_onComposerText);
    _composerController.dispose();
    _composerFocus.dispose();
    _latestReply.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _newThread() {
    _handoff?.cancel();
    _chat.newThread();
    _closeDrawerIfNarrow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
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
    _chat.openSearchHit(hit);
    _closeDrawerIfNarrow();
  }

  /// Puts the cursor in the sidebar's search field, which an iPad shows beside
  /// the chat.
  void _focusSidebarSearch() => _searchFocus.requestFocus();

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
      MacCommand.newChat: MacCommandHandler(_newThread),
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
    if (_leaveToWindow(id, () => _selectThread(id))) return;
    _handoff?.cancel();
    _chat.select(id);
    _closeDrawerIfNarrow();
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

  void _openProfiles() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          repository: _profiles,
          models: _chat.models,
          chatProfile: _chat.profile,
          onSwitched: _chat.repository == null ? null : _chat.loadThreads,
        ),
      ),
    );
  }

  void _openMessaging() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagingScreen(repository: _messaging),
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
    setState(() => _appendToComposer(draft));
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
    }
  }

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
      setState(() => _starter = context);
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
        setState(
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
    setState(() => _queueSending = true);
    final target = _chat.selectedThread;
    final profile = _chat.profile;
    bool accepted;
    try {
      accepted = await _chat.submit(typed, files);
    } on Object {
      _showMessage('Could not send this prompt. Your draft was kept.');
      return;
    } finally {
      if (mounted) setState(() => _queueSending = false);
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
    setState(() {
      _composerController.clear();
      _attachments.clear();
    });
  }

  Future<void> _sendSlash(String command) async {
    if (_slashSending) return;
    setState(() => _slashSending = true);
    try {
      if (!await _chat.runSlashCommand(command) || !mounted) return;
      if (_composerController.text.trim() == command) {
        _composerController.clear();
      }
    } finally {
      _slashSending = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => MacCommandScope(
    commands: _menuCommands(
      ios: platformChromeOf(context) == PlatformChrome.ios,
    ),
    child: _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    final chat = _chat;
    // Without its own drawer, the chat keeps the shell's menu reachable on a
    // narrow layout, or the other destinations would be too.
    final shellMenu = ShellMenu.button(context);
    final shellBar = shellMenu == null
        ? null
        : buildChatAppBar(context, leading: shellMenu);
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
        final selected = chat.selectedThread;
        final bot = selected?.botContext;
        _latestReply.follow(chat, selected);
        ThreadSidebar buildSidebar({Widget? navigation}) => ThreadSidebar(
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
          onOpenPlugins: _plugins == null ? null : _openPlugins,
          onOpenMcp: _mcp == null ? null : _openMcp,
          onOpenHelperModels: _models == null ? null : _openHelperModels,
        );

        final macSplit = isWide && _mac;
        final search = chat.search;
        final threadView = boundChatThreadView(
          chat: chat,
          thread: selected,
          greetingName: context.select<AuthController, String?>(
            (auth) => auth.identity?.displayName,
          ),
          sendTarget: () => (_chat.profile, _chat.selectedId),
          composerController: _composerController,
          composerFocus: _composerFocus,
          dictation: _dictation?.controller,
          attachments: _attachments,
          attachmentSource: _attachmentSource,
          onAddAttachments: _addAttachments,
          onRemoveAttachment: (file) =>
              setState(() => _attachments.remove(file)),
          onSend: _send,
          slashCommands: _slashCommands,
          commandRunning: _slashSending || _queueSending,
          starterPrompts: _showsWelcome ? _starterPrompts() : null,
          onPickStarter: _pickStarter,
          latestReply: _latestReply,
          editable: true,
          header: !isWide
              ? null
              : _mac
              ? ListenableBuilder(
                  listenable: search ?? const AlwaysStoppedAnimation(0),
                  builder: (context, _) => MacChatToolbar(
                    title: bot?.title ?? selected?.title ?? 'Hermes',
                    subtitle: _toolbarSubtitle(),
                    onNewChat: _newThread,
                    onShowConnection: _showConnection,
                    onCopyTranscript: selected == null
                        ? null
                        : () => _copyTranscript(selected),
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
                  displayTitle: bot?.title,
                  housekeeping: chat.housekeeping,
                  onShowConnection: _showConnection,
                  onNewChat: _newThread,
                ),
        );

        final scaffold = Scaffold(
          key: _scaffoldKey,
          drawer: isWide
              ? null
              : Drawer(
                  width: 280,
                  child: buildSidebar(navigation: widget.navigation),
                ),
          appBar: isWide
              ? null
              : buildChatAppBar(
                  context,
                  title: Text(bot?.title ?? selected?.title ?? 'Hermes'),
                  actions: [
                    if (selected != null && selected.remote)
                      ThreadActionsButton(
                        key: const Key('header-thread-actions'),
                        thread: selected,
                        housekeeping: chat.housekeeping,
                        includeCopyTranscript: true,
                      ),
                    NewChatButton(onPressed: _newThread),
                  ],
                ),
          body: macSplit
              ? MacSplitView(
                  sidebar: buildSidebar(navigation: widget.navigation),
                  content: threadView,
                )
              : Row(
                  children: [
                    if (isWide)
                      SizedBox(
                        width: 280,
                        child: buildSidebar(navigation: widget.navigation),
                      ),
                    if (isWide) const VerticalDivider(width: 1),
                    Expanded(child: threadView),
                  ],
                ),
        );
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
