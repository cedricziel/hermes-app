import 'dart:async';

import 'package:flutter/foundation.dart';

import '../voice/calls/call_bridge.dart';
import '../voice/calls/call_audio_decoder.dart';
import '../voice/calls/call_agent.dart';
import '../voice/calls/voice_call.dart';
import '../voice/calls/call_microphone.dart';
import '../voice/calls/call_readiness_checker.dart';
import '../voice/calls/call_speech_probe.dart';
import '../voice/voice_call_screen.dart';
import '../voice/dictation_dialog.dart';

import 'package:url_launcher/url_launcher.dart';

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
import '../memory/memory_destination.dart';
import '../memory/memory_proposal_session.dart';
import '../memory/memory_proposals_repository.dart';
import '../memory/memory_waiting_count.dart';
import '../models/hermes_models_repository.dart';
import '../models/widgets/model_setup_dialog.dart';
import '../live_activities/live_activities.dart';
import '../app_lock/app_lock_controller.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../plugins/hermes_plugin_manager_repository.dart';
import '../plugins/plugins_screen.dart';
import '../profiles/chat_profiles.dart';
import 'gateway_connection_transport.dart';
import 'invalidation/change_invalidation_binding.dart';
import 'invalidation/change_signal.dart';
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
import '../theme/app_icons.dart';
import '../widgets/named_icon_button.dart';
import '../profiles/profile_avatar_repository.dart';
import '../profiles/widgets/profile_avatar.dart';
import '../profiles/widgets/recipient_picker.dart';
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
import '../voice/voice_message_recording.dart';
import '../voice/voice_recording_view.dart';
import '../voice/dictation_settings.dart';
import '../voice/on_device_speech.dart';
import '../voice/voice_recorder.dart';
import '../watch/watch_complication.dart';
import 'slash_command.dart';
import '../bot_mode/bot_mode_chat_repository.dart';
import 'starter_context_loader.dart';
import 'starter_prompts.dart';
import 'activity/bound_activity_panel.dart';
import 'activity/widgets/activity_panel.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_header.dart';
import 'widgets/mac_chat_toolbar.dart';
import 'widgets/thread_actions_menu.dart';
import 'widgets/thread_sidebar.dart';
import 'widgets/new_chat_fab.dart';
import '../kanban/widgets/task_panel/kanban_task_sheet.dart';
import '../widgets/inspector_layout.dart';

part 'chat_screen_windows.dart';
part 'chat_screen_external_openings.dart';
part 'chat_screen_sharing.dart';
part 'chat_screen_recipients.dart';
part 'chat_screen_navigation.dart';
part 'chat_screen_composer.dart';
part 'chat_screen_layout.dart';
part 'chat_screen_calls.dart';

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
    this.voiceMessageRecorder,
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

  /// Optional microphone override for draft audio attachments.
  final VoiceRecorder? voiceMessageRecorder;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Owns resources and lifecycle; private parts group feature behavior and layout.
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _chat;

  /// How many staged memory changes wait in the chat's profile, for the
  /// Memory entry; null without a dashboard connection.
  MemoryWaitingCount? _memoryWaiting;
  var _wasLoadingThreads = false;
  HandoffController? _handoff;
  DockMenuController? _dock;
  HermesProfilesRepository? _profiles;
  ProfileAvatarRepository? _avatars;
  AuthController? _avatarAuth;
  int? _avatarOwner;
  List<HermesProfile> _recipients = const [];
  bool _profilesUnsupported = false;
  bool _recipientsLoading = false;
  bool _recipientsFailed = false;
  int _recipientRead = 0;
  int _recipientIntent = 0;
  (String?, String?) _composerOwner = (null, null);
  ChatThread? _composerThread;
  final _draftOwners = <ChatThread, (String?, String?)>{};
  final _drafts = <(String?, String?), TextEditingValue>{};
  final _draftFiles = <(String?, String?), List<SharedFile>>{};
  HermesMessagingRepository? _messaging;
  HermesSkillsRepository? _skills;
  HermesPluginManagerRepository? _plugins;
  HermesMcpRepository? _mcp;
  HermesModelsRepository? _models;
  HermesGatewayTransport? _ownedTransport;
  SessionActivity? _sessionActivity;
  final _composerController = TextEditingController();
  VoiceCall? _voiceCall;
  bool _callRouteOpen = false;
  bool _callHasEnded = true;
  ComposerDictation? _dictation;
  VoiceMessageRecording? _voiceRecording;
  (String?, String?)? _recordingOwner;
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
  ({bool held, int link, int? owner})? _pendingShare;
  late final AttentionNotifier _attention;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _chatsScaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFocus = FocusNode();
  Timer? _activeRefreshTimer;
  MenuBarExtraLink? _menuBar;
  bool _activeRefreshInFlight = false;
  bool _foreground = true;
  bool _routeVisible = true;
  ChangeInvalidationBinding? _listChanges;

  /// Whether the window is a Mac one, as of the last build.
  bool _mac = false;

  /// Whether the layout is wide (the inspector) or a phone (the sheet).
  bool _wide = false;

  /// Whether the Activity inspector is open; it stays open across chats.
  bool _activityOpen = false;
  bool _detailOpen = false;
  final _conversationNavigator = GlobalKey<NavigatorState>();

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
    if (transport is HermesGatewayTransport && auth?.baseUrl != null) {
      _avatars = ProfileAvatarRepository(
        transport.request,
        serverId: auth!.baseUrl!,
        accountId: auth.identity?.userId ?? '',
      );
    }
    _avatarAuth = auth;
    _avatarOwner = auth?.ownerGeneration;
    auth?.addListener(_checkAvatarOwner);
    if (_profiles != null) unawaited(_loadRecipients());
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
      appLock: appLock,
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
      onOpened: _showDetail,
      breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      onPrefill: (draft) => _composerController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      ),
      onDraft: _draftFromLink,
    )..addListener(_changed);
    if (transport != null && _skills != null) {
      _memoryWaiting = MemoryWaitingCount(
        MemoryProposalsRepository(
          MemoryProposalSession(transport),
          telemetry: repositories?.telemetry ?? const ConnectionTelemetry(),
        ),
      )..addListener(_memoryWaitingChanged);
    }
    if (auth != null &&
        transport is GatewayConnectionTransport &&
        _chat.repository != null) {
      final repository = _chat.repository!;
      final changes = _listChanges = ChangeInvalidationBinding(
        source: transport as GatewayConnectionTransport,
        auth: auth,
        resource: InvalidationResource.sessions,
        profile: () => _chat.profile,
        events: repositories?.telemetry.events ?? noopAppEventLogger,
      );
      var requestedGeneration = _chat.threadListGeneration;
      String? requestedProfile;
      changes.controller.register<
        ({int generation, String profile, ThreadPage page})
      >(
        InvalidationResource.sessions,
        readSnapshot: (scope) async {
          final generation = requestedGeneration = _chat.threadListGeneration;
          final profile = requestedProfile = scope.profile!;
          final count = _chat.threads.where((thread) => thread.remote).length;
          final page = await repository.loadThreadPage(
            limit: count > 50 ? count : 50,
            profile: profile,
          );
          return (generation: generation, profile: profile, page: page);
        },
        snapshotIsCurrent: (snapshot) =>
            _chat.active &&
            snapshot.generation == _chat.threadListGeneration &&
            snapshot.profile == _chat.profile &&
            !_chat.threadListInvalidationBlocked,
        applySnapshot: (snapshot) => _chat.applyInvalidatedThreads(
          snapshot.page,
          profile: snapshot.profile,
          generation: snapshot.generation,
        ),
        onFailure: (_) {
          final profile = requestedProfile;
          if (profile != null) {
            _chat.threadListInvalidationFailed(
              profile: profile,
              generation: requestedGeneration,
            );
          }
        },
      );
      changes.controller.addListener(_invalidationsChanged);
      _syncListChanges();
    }
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
      _voiceRecording = VoiceMessageRecording(
        recorder: widget.voiceMessageRecorder ?? RecordVoiceRecorder(),
        activity: _sessionActivity,
        canRecord: () =>
            mounted &&
            _foreground &&
            widget.visible &&
            _routeVisible &&
            _chat.active &&
            _voiceCall?.ended != false &&
            _dictation?.controller.busy != true &&
            !_slashSending &&
            !_queueSending,
        onAttach: (file) {
          if (mounted && _recordingOwner == (_chat.profile, _chat.selectedId)) {
            _rebuild(() => _attachments.add(file));
          }
        },
        onError: _showMessage,
      );
      _voiceRecording!.addListener(_recordingChanged);
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
      if (mounted) _onOpenRequest(initial: true);
    });
    _composerController.addListener(_onComposerText);
    if (_chat.repository != null) {
      unawaited(
        _chat.loadThreads().then(
          (_) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _focusComposerOnLaunch(),
          ),
        ),
      );
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
    _panelTookVoice = _windows?.panelTookVoice.listen((_) {
      _dictation?.controller.cancel();
      unawaited(_voiceRecording?.cancel());
    });
    _dictation?.controller.addListener(_takeVoice);
  }

  void _recordingChanged() {
    if (_voiceRecording?.phase == VoiceRecordingPhase.preparing) {
      _recordingOwner = (_chat.profile, _chat.selectedId);
      unawaited(_windows?.stopPanelDictation());
    }
  }

  void _takeVoice() {
    final recording = _dictation!.controller.busy;
    if (recording && !_recording) {
      unawaited(_voiceRecording?.cancel());
      unawaited(_windows?.stopPanelDictation());
    }
    _recording = recording;
  }

  void _invalidationsChanged() {
    if (mounted) setState(() {});
  }

  void _syncListChanges() => _listChanges?.sync(
    active: _foreground && widget.visible && _routeVisible,
    blocked: _chat.threadListInvalidationBlocked,
  );

  void _memoryWaitingChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    _syncListChanges();
    final loading = _chat.loadingThreads;
    if (_wasLoadingThreads && !loading) {
      unawaited(_memoryWaiting?.refresh(_chat.profile));
    }
    _wasLoadingThreads = loading;
    final thread = _chat.selectedThread;
    final owner = (_chat.profile, _chat.selectedId);
    final savedOwner = _draftOwners[thread];
    if (savedOwner != null &&
        savedOwner != owner &&
        savedOwner.$1 == owner.$1) {
      final draft = _drafts.remove(savedOwner);
      final files = _draftFiles.remove(savedOwner);
      if (draft != null) _drafts[owner] = draft;
      if (files != null) _draftFiles[owner] = files;
    }
    if (_composerOwner != owner) {
      unawaited(_voiceRecording?.cancel());
      final adoptedSessionId =
          thread != null &&
          identical(_composerThread, thread) &&
          _composerOwner.$1 == owner.$1;
      if (adoptedSessionId) {
        _drafts.remove(_composerOwner);
        _draftFiles.remove(_composerOwner);
      } else {
        _drafts[_composerOwner] = _composerController.value;
        _draftFiles[_composerOwner] = List.of(_attachments);
        _composerController.value = _drafts[owner] ?? TextEditingValue.empty;
        _attachments
          ..clear()
          ..addAll(_draftFiles[owner] ?? const []);
      }
      _composerOwner = owner;
    }
    _composerThread = thread;
    if (thread != null) _draftOwners[thread] = owner;
    _dictation?.followProfile();
    if (!_chat.loadingThreads) widget.chatProfiles?.showing(_chat.profile);
    _syncDock();
    setState(() {});
    if (!_chat.loadingThreads && !_chat.threadsFailed) {
      final pending = _pendingShare;
      if (pending != null) {
        _pendingShare = null;
        if (pending.link == _linkSeq &&
            pending.owner == _avatarAuth?.ownerGeneration) {
          _absorbShared(held: pending.held);
        }
      }
    }
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
    _routeVisible = ModalRoute.of(context)?.isCurrent != false;
    _syncListChanges();
    if (!_foreground || !widget.visible || !_routeVisible) {
      unawaited(_voiceRecording?.cancel());
    }
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

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  var _notificationTapReceived = false;

  /// Counts the requests taken, so work for an earlier one can tell it was
  /// overtaken.
  var _linkSeq = 0;

  /// Work a link asked for on the thread list. Loading replaces that list and
  /// would drop a new chat made meanwhile, so it waits for the load to end.
  Future<void> Function()? _whenLoaded;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    unawaited(_memoryWaiting?.refreshIfStale(_chat.profile));
    if (!_chat.loadingThreads && _showsWelcome) _refreshStarter();
  }

  @override
  void dispose() {
    _listChanges?.controller.removeListener(_invalidationsChanged);
    _listChanges?.dispose();
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
    _sessionActivity?.removeListener(_callOwnerChanged);
    _voiceCall?.removeListener(_callChanged);
    _voiceCall?.dispose();
    _chat
      ..removeListener(_changed)
      ..dispose();
    _avatarAuth?.removeListener(_checkAvatarOwner);
    _avatars?.dispose();
    _memoryWaiting
      ?..removeListener(_memoryWaitingChanged)
      ..dispose();
    _ownedTransport?.close();
    _voiceRecording?.dispose();
    _dictation?.dispose();
    _sessionActivity?.dispose();
    _composerController.removeListener(_onComposerText);
    _composerController.dispose();
    _composerFocus.dispose();
    _latestReply.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Keep registered callbacks as instance methods: extension tear-offs do not
  // retain callback identity across addListener/removeListener calls.
  void _checkAvatarOwner() => _ChatScreenRecipients(this)._checkAvatarOwner();
  void _onComposerText() => _ChatScreenComposer(this)._onComposerText();
  void _onOpenRequest({bool initial = false}) =>
      _ChatScreenExternalOpenings(this)._onOpenRequest(initial: initial);
  void _onShared() => _ChatScreenSharing(this)._onShared();
  void _syncDock() => _ChatScreenWindows(this)._syncDock();
  void _advertise() => _ChatScreenWindows(this)._advertise();

  // State updates stay on the State instance, including those requested by parts.
  void _rebuild(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => MacCommandScope(
    commands: _menuCommands(
      ios: platformChromeOf(context) == PlatformChrome.ios,
    ),
    child: _buildScreen(context),
  );
}
