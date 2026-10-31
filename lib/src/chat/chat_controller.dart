import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../background/running_replies.dart';
import '../core/safe_notifier.dart';
import '../bot_mode/bot_chat_context.dart';
import '../bot_mode/bot_mode_chat_repository.dart';
import '../memory/memory_decisions.dart';
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/model_options_state.dart';
import '../live_activities/live_activities.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../share/shared_item.dart';
import '../surfaces/chat_hints.dart';
import '../surfaces/surface_snapshot.dart'
    show
        PendingKind,
        PendingRequest,
        SurfaceSnapshot,
        kDefaultProfile,
        kMaxRecentChats;
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import '../watch/watch_complication.dart';
import 'chat_controller_sync.dart';
import 'chat_message_mapper.dart';
import 'chat_models.dart';
import 'chat_reply.dart';
import 'chat_transport.dart';
import 'chat_warning_state.dart';
import 'chat_session_state.dart';
import 'owned_session_transport.dart';
import 'todo_plan/todo_plan_state.dart';
import 'moa_progress_state.dart';
import 'session_usage/session_usage_controller.dart';
import 'side_results/side_result_state.dart';
import 'connector_operation_controller.dart';
import 'connector_operation_state.dart';
import 'connector_operation_transport.dart';
import 'gateway_connection_transport.dart';
import 'billing_verification_controller.dart';
import 'billing_verification_transport.dart';
import '../app_lock/app_lock_controller.dart';
import 'process_output_state.dart';
import 'reactions/reaction_state.dart';
import 'gateway/gateway_rpc_client.dart'
    show GatewayRpcException, GatewayConnectionClosed;
import 'hermes_chat_repository.dart';
import 'mock_chat_data.dart';
import 'queued_prompt.dart';
import 'queue_storage/queue_record.dart';
import 'queue_storage/durable_queue_store.dart';
import 'slash_command.dart';
import 'thread_housekeeping.dart';
import 'thread_search.dart';
import 'widgets/message_actions.dart' show TurnAction, TurnActionStatus;

part 'chat_controller_billing.dart';
part 'chat_controller_commands.dart';
part 'chat_controller_connectors.dart';
part 'chat_controller_history.dart';
part 'chat_controller_progress.dart';
part 'chat_controller_queues.dart';
part 'chat_controller_reactions.dart';
part 'chat_controller_requests.dart';
part 'chat_controller_sending.dart';
part 'chat_controller_session_binding.dart';
part 'chat_controller_session_state.dart';
part 'chat_controller_streaming.dart';
part 'chat_controller_surfaces.dart';

const couldNotOpenChat = 'Could not open that chat.';

/// The `session.active_list` statuses of a session that still runs a turn.
const _runningStatuses = {
  'starting',
  'waiting',
  'working',
  'streaming',
  'resuming',
};
const _couldNotStop = 'Could not stop the reply. Try again.';

/// An external open interrupted by suspension, for owner-controlled recovery.
class InterruptedChatOpening {
  const InterruptedChatOpening({
    required this.target,
    required this.fetchMissing,
    this.prompt,
  });

  final NotificationTarget target;
  final bool fetchMissing;
  final String? prompt;
}

/// The chat's state without its screen: the threads of the active profile,
/// their messages, the replies streaming into them and the agent's input
/// requests.
///
/// Threads and messages are read through [repository]; without one it holds
/// mock data (see `mock_chat_data.dart`). Messages go out through [transport];
/// without one the reply is a canned placeholder.
///
/// Owns shared state and lifecycle. Feature implementations live in private
/// `chat_controller_*.dart` parts, behind the same public instance API.
/// Implementation names differ from public methods so internal calls still
/// dispatch through instance overrides.
class ChatController extends ChangeNotifier with SafeNotifier {
  ChatController({
    this.repository,
    this.profiles,
    this.models,
    this.transport,
    this.activity,
    this.appLock,
    this.billingBrowser,
    this.billingCopyCode,
    this.botChats,
    this.queueStore,
    this.queueScope,
    this.queueChanges,
    this.canShowQueues,
    required this._attention,
    this.liveActivities,
    this.watchStatus,
    this.runningReplies,
    required this.report,
    this.onShowChat,
    this.onOpenJob,
    this.onOpenNewChat,
    this.onLaunchNotification,
    this.onOpened,
    this.onPrefill,
    this.onSurfaceChange,
    this.readSnapshot,
    this.onDraft,
    this.breadcrumbs = Breadcrumbs.none,
    this.events = noopAppEventLogger,
    this.connectorBrowser,
    this.usageTelemetry = const ConnectionTelemetry(),
    this.replayGrace = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _clock = now ?? DateTime.now,
       _watchSource = watchStatus?.source() {
    final repository = this.repository;
    if (repository == null) {
      _threads = buildMockThreads();
      _selectedId = _threads.isNotEmpty ? _threads.first.id : null;
    } else {
      _threads = [];
      housekeeping = ThreadHousekeeping(
        repository: repository,
        threads: () => _threads,
        profile: () => _profile,
        changed: notifyListeners,
        report: report,
        removed: _threadRemoved,
        prepareDelete: _prepareQueueDeletion,
        history: _history,
        canWork: () => active,
      );
      search = ThreadSearch(
        (query) => repository.searchThreads(query, profile: _profile),
        searchAll: profiles == null ? null : _searchAllProfiles,
        recentStore: SharedPreferencesAsync(),
        canWork: () => active,
      );
    }
    queueChanges?.addListener(_queueIdentityChanged);
    _activeActivity = activity?.value ?? true;
    activity?.addListener(_activityChanged);
    appLock?.addListener(_billingLockChanged);
    _listenOwnedSessions();
    search?.setActivity(_activeActivity);
    housekeeping?.setActivity(_activeActivity);
    if (!_activeActivity) return;
    // Whatever an earlier run left is old news now that the app is in front.
    forgetRunningReplies();
    unawaited(runningReplies?.clearAnnounced());
  }

  /// The verified session owner closes this gate before transport suspension.
  final ValueListenable<bool>? activity;
  bool _activeActivity = true;
  int _activityEpoch = 0;

  /// Whether protected work can start or publish into this controller.
  bool get active => !disposed && _activeActivity && (activity?.value ?? true);
  bool _currentActivity(int epoch) => active && epoch == _activityEpoch;

  void _activityChanged() {
    if (disposed) return;
    final epoch = ++_activityEpoch;
    final next = activity!.value;
    _activeActivity = false;
    _suspendActivity();
    if (!next || disposed || epoch != _activityEpoch) return;
    _activeActivity = true;
    _listenOwnedSessions();
    housekeeping?.setActivity(true);
    search?.setActivity(true);
    if (!_currentActivity(epoch)) return;
    unawaited(
      Future<void>.microtask(() {
        if (_currentActivity(epoch)) return _resumeActivity();
      }),
    );
  }

  void _suspendActivity() {
    search?.setActivity(false);
    housekeeping?.setActivity(false);
    _loadGeneration++;
    _openGeneration++;
    _activeRefresh++;
    _pauses++;
    _loadingThreads = false;
    _loadingMessages.clear();
    _interruptedOpening = _requestedOpening ?? _interruptedOpening;
    _requestedOpening = null;
    _pendingTap = null;
    _pendingFetch = false;
    _pendingTapPrompt = null;
    _opening = Future<void>.value();
    for (final thread in _generations.keys.toList()) {
      _generations[thread] = _generations[thread]! + 1;
    }
    _queueEpoch++;
    _queueRestoring.clear();
    _cancelQueueBindings();
    _loadedQueues.clear();
    _restoredQueues.addAll(
      _queues.keys.where(
        (thread) => _queues[thread]!.any((prompt) => prompt.durable != null),
      ),
    );
    _suspendedQueues.addAll(_queues.keys);
    _undoing.clear();
    _interrupts.clear();
    _holds.clear();
    for (final subscription in _replies) {
      unawaited(subscription.cancel());
    }
    _replies.clear();
    _stopFollowing();
    _sending.clear();
    _cancelSettleWaits();
    _replayEnds?.cancel();
    notifyListeners();
  }

  Future<void> _resumeActivity() async {
    final epoch = _activityEpoch;
    final generation = _loadGeneration;
    if (repository == null) return;
    var profile = _profile;
    if (profile != null && profiles != null) {
      try {
        final known = await profiles!.list();
        if (!_currentActivity(epoch) || generation != _loadGeneration) return;
        if (!known.any((p) => p.name == profile)) {
          _threadsFailed = true;
          notifyListeners();
          return;
        }
      } on Object {
        if (!_currentActivity(epoch) || generation != _loadGeneration) return;
        _threadsFailed = true;
        notifyListeners();
        return;
      }
    }
    if (!_currentActivity(epoch)) return;
    if (generation != _loadGeneration) return;
    await _loadThreads(profile, preserveSelection: true);
  }

  final HermesChatRepository? repository;
  final HermesProfilesRepository? profiles;
  final HermesModelsRepository? models;
  final ChatTransport? transport;
  final AppLockController? appLock;
  final Future<bool> Function(Uri)? billingBrowser;
  final Future<void> Function(String)? billingCopyCode;
  final _billing = <(String?, String), BillingVerificationController>{};
  final _billingBindings = <(String?, String), OwnedSessionBinding>{};

  BillingVerificationController? billingVerificationIn(ChatThread thread) =>
      _ChatControllerBilling(this)._billingVerificationInImpl(thread);

  final BotModeChatRepository? botChats;
  final Future<PromptQueueStore> Function()? queueStore;
  final QueueScope? Function(ChatThread thread, String? profile)? queueScope;
  final Listenable? queueChanges;
  final bool Function()? canShowQueues;
  bool get queuesVisible => _ChatControllerQueues(this)._queuesVisibleImpl;
  var _queueEpoch = 0;
  final _restoredQueues = <ChatThread>{};
  final _loadedQueues = <ChatThread>{};
  final _queuePreparing = <ChatThread>{};
  final _queueRemoving = <ChatThread>{};
  final _queueDispatching = <ChatThread>{};
  static const _queueMissingTarget =
      'This conversation is unavailable. Its queued prompts were kept in their original scope.';
  final _queueErrors = <ChatThread, String>{};
  final _queueUnavailable = <ChatThread>{};
  final _queueRestoring = <ChatThread, Future<bool>>{};
  final _hiddenQueueOrder = <ChatThread, List<(QueueScope, String)>>{};
  final _knownQueueAcceptance = <(String, String)>{};
  bool queueNeedsReview(ChatThread thread) =>
      _ChatControllerQueues(this)._queueNeedsReviewImpl(thread);
  bool queueBusy(ChatThread thread) =>
      _ChatControllerQueues(this)._queueBusyImpl(thread);
  String? queueErrorIn(ChatThread thread) =>
      _ChatControllerQueues(this)._queueErrorInImpl(thread);
  bool queueAvailable(ChatThread thread) =>
      _ChatControllerQueues(this)._queueAvailableImpl(thread);
  void queueReviewed(QueuedPrompt prompt) =>
      _ChatControllerQueues(this)._queueReviewedImpl(prompt);
  void inspectQueued(ChatThread thread) =>
      _ChatControllerQueues(this)._inspectQueuedImpl(thread);

  final _queueBindings = <ChatThread, Completer<bool>>{};
  final _bindingScopes = <ChatThread, QueueScope>{};

  Future<PromptQueueStore>? _openedQueueStore;
  final _enqueueing = <ChatThread>{};

  int _openGeneration = 0;

  /// Counts the chat opens so far; an open that was started earlier has been
  /// overtaken once this has moved on.
  int get openGeneration => _openGeneration;
  final AttentionNotifier _attention;

  /// Shows replies sent here as Live Activities; null where there are none.
  final LiveActivities? liveActivities;

  /// Tells the watch's complications what a reply sent here is doing; null
  /// where there is no watch.
  final WatchComplicationStatus? watchStatus;
  final WatchComplicationSource? _watchSource;

  /// The chats whose reply was running when the app left, for a background
  /// run to announce; null where there are no background runs.
  final RunningReplies? runningReplies;

  /// How long after the app returns the ending of a reply a background run
  /// announced may still arrive as a replay. Later than that, an ending is a
  /// new one.
  final Duration replayGrace;
  final DateTime Function() _clock;
  Timer? _replayEnds;

  /// Whether [runningReplies] holds what [rememberRunningReplies] wrote, so a
  /// reply that ends meanwhile is taken off it.
  var _replyListWritten = false;

  /// Counts the pauses, so that a return that is still asking the server does
  /// not wipe the list a later pause wrote.
  var _pauses = 0;

  /// The replies of chats that left the screen (another profile was opened, or
  /// this one loaded again) and have not ended: the threads on screen no longer
  /// show them, but the list for a background run must.
  final _carried = <(String?, String)>{};

  /// When each reply in the list was first remembered, so that pausing again
  /// does not make an old reply young; kept until its turn ends.
  final _rememberedSince = <(String?, String), DateTime>{};

  /// Tells the user something went wrong.
  final ValueChanged<String> report;

  /// Asks the host to bring the chat to the front.
  final VoidCallback? onShowChat;

  /// Delegates launch delivery before the controller applies its target.
  final ValueChanged<NotificationTarget>? onLaunchNotification;

  /// Called for a notification about a scheduled task.
  final void Function(NotificationTarget target)? onOpenJob;

  /// Called for a notification about a question that never reached Hermes.
  final void Function(NotificationTarget target)? onOpenNewChat;

  /// Called after a chat asked for from outside was selected.
  final VoidCallback? onOpened;

  /// Restores a draft returned by a command such as `/undo`.
  final ValueChanged<String>? onPrefill;

  /// Told when the chat list loaded, a reply ended or an input request
  /// opened, closed or expired, with what the system surfaces show of it.
  final void Function(SurfaceTrigger trigger, ChatHints hints)? onSurfaceChange;

  /// The snapshot the system surfaces show, which knows the open requests of
  /// every profile, as far as the last look at the server.
  final Future<SurfaceSnapshot?> Function()? readSnapshot;

  /// Adds text from a link to the composer, under what is typed there. It is
  /// never sent.
  final ValueChanged<String>? onDraft;

  /// Notes what the user did, for a crash report. It is never given text,
  /// titles, profile names or ids.
  final Breadcrumbs breadcrumbs;
  final AppEventLogger events;
  final ConnectionTelemetry usageTelemetry;
  final Future<bool> Function(Uri)? connectorBrowser;
  final _usage = <ChatThread, SessionUsageController>{};
  final _ownedBindings = <ChatThread, OwnedSessionBinding>{};
  StreamSubscription<OwnedSessionChange>? _ownedSubscription;

  final _moaStates = <ChatThread, MoaProgressState>{};
  final _moaBindings = <ChatThread, OwnedSessionBinding>{};
  final _moaForeground = <ChatThread, ChatMessage>{};
  final _moaUnavailable = <ChatThread>{};

  List<MoaProgress> moaIn(ChatThread thread) =>
      _ChatControllerProgress(this)._moaInImpl(thread);

  void moaDetailsOpened() =>
      _ChatControllerProgress(this)._moaDetailsOpenedImpl();

  final _todoPlans = <(String?, String), TodoPlanState>{};
  final _todoBindings = <(String?, String), OwnedSessionBinding>{};
  final _todoLive = <(String?, String), int>{};
  final _todoResumes =
      <(String?, String), (OwnedSessionBinding, Object, int)>{};

  TodoPlanState? todoPlanIn(ChatThread thread) =>
      _ChatControllerProgress(this)._todoPlanInImpl(thread);

  SessionUsageController? usageIn(ChatThread thread) =>
      _ChatControllerSessionBinding(this)._usageInImpl(thread);

  final _reactions = <ChatThread, ReactionState>{};

  final _sideResults = <ChatThread, SideResultState>{};
  SideResultState? sideResultsIn(ChatThread thread) =>
      _ChatControllerSessionBinding(this)._sideResultsInImpl(thread);

  final _memoryDecisions = <ChatThread, MemoryDecisions>{};

  /// The staged memory writes of [thread], approved or rejected through its
  /// session. They are dropped with the thread.
  MemoryDecisions memoryDecisionsIn(ChatThread thread) =>
      _memoryDecisions.putIfAbsent(
        thread,
        () => MemoryDecisions(
          available: () => active && thread.remote && transport != null,
          run: (command) async => (await transport!.runSlashCommand(
            threadId: thread.id,
            profile: _profile,
            command: command,
          )).output,
          telemetry: usageTelemetry,
          breadcrumbs: breadcrumbs,
        ),
      );

  final _processOutputs = <ChatThread, ProcessOutputState>{};
  ProcessOutputState? processOutputsIn(ChatThread thread) =>
      _ChatControllerSessionBinding(this)._processOutputsInImpl(thread);

  final _connectorOperations =
      <(String?, String), ConnectorOperationController>{};
  final _connectorBindings = <(String?, String), OwnedSessionBinding>{};
  ConnectorOperationController? _connectionOperations;
  Object? _connectorConnection;
  StreamSubscription<GatewayConnectionEvent>? _connectorActivitySubscription;
  int _connectorActivityGeneration = 0;

  ConnectorOperationController? connectorOperationsIn(ChatThread thread) =>
      _ChatControllerConnectors(this)._connectorOperationsInImpl(thread);

  ConnectorOperationController? get connectionOperations =>
      _ChatControllerConnectors(this)._connectionOperationsImpl;

  void processOutputDetailsOpened() =>
      _ChatControllerSessionBinding(this)._processOutputDetailsOpenedImpl();

  final _warnings = <ChatThread, ChatWarningState>{};
  final _warningGenerations = <ChatThread, int>{};
  int _nextWarningGeneration = 0;

  final _sessionStates = <ChatThread, ChatSessionState>{};
  final _sessionActionGenerations = <ChatThread, int>{};
  int _nextSessionActionGeneration = 0;

  final _reclaimedQueueReview = <ChatThread>{};

  ChatSessionState? sessionStateIn(ChatThread thread) =>
      _ChatControllerSessionState(this)._sessionStateInImpl(thread);

  void sessionDetailsOpened() =>
      _ChatControllerSessionState(this)._sessionDetailsOpenedImpl();

  void reopenSession(ChatThread thread) =>
      _ChatControllerSessionState(this)._reopenSessionImpl(thread);

  List<AgentNotice> noticesIn(ChatThread thread) =>
      _ChatControllerSessionState(this)._noticesInImpl(thread);

  void dismissNotice(ChatThread thread, AgentNotice notice) =>
      _ChatControllerSessionState(this)._dismissNoticeImpl(thread, notice);

  void warningDetailsOpened() =>
      _ChatControllerSessionState(this)._warningDetailsOpenedImpl();

  ThreadHousekeeping? housekeeping;

  /// Whether the last chat asked for from outside could not be opened.
  bool get openFailed => _openFailed;
  bool _openFailed = false;

  void _failOpen() {
    _openFailed = true;
    breadcrumbs('chat.open.failed');
    report(couldNotOpenChat);
    notifyListeners();
  }

  /// The sidebar's session search; null without a repository.
  ThreadSearch? search;

  late List<ChatThread> _threads;
  List<ChatThread> get threads => _threads;

  bool _loadingThreads = false;
  bool get loadingThreads => _loadingThreads;
  bool _threadsFailed = false;
  bool get threadsFailed => _threadsFailed;

  /// The profile whose sessions are listed; null leaves it to the dashboard.
  String? _profile;
  String? get profile => _profile;
  int _loadGeneration = 0;

  ModelOptions? _modelOptions;
  ModelOptions? get modelOptions => _modelOptions;
  ModelOptionsState _modelOptionsState = ModelOptionsState.loading;
  int _modelOptionsGeneration = 0;

  ModelOptionsState get modelOptionsState =>
      models == null ? ModelOptionsState.unsupported : _modelOptionsState;

  /// Whether the current model can be used without guessing configuration.
  bool get modelSendAllowed {
    final state = modelOptionsState;
    if (state == ModelOptionsState.unsupported) return true;
    if (state == ModelOptionsState.incomplete) return false;
    final choice = modelChoice ?? _modelOptions?.current;
    if (choice == null) return false;
    if (_modelOptions?.model(choice) != null) return true;
    return state != ModelOptionsState.ready &&
        selectedThread?.remote == true &&
        choice.providerId.isNotEmpty &&
        choice.modelId.isNotEmpty;
  }

  /// Refreshes only the current profile's model discovery, preserving drafts.
  Future<void> refreshModelOptions() =>
      _loadModelOptions(_profile, _loadGeneration);

  /// The model picked before there is a thread to hold it.
  ModelChoice? _newChatModel;

  /// The model picked for the selected thread, or for a new one.
  ModelChoice? get modelChoice {
    final selected = selectedThread;
    return selected == null ? _newChatModel : selected.modelChoice;
  }

  void chooseModel(ModelChoice choice) {
    if (!active || (models != null && _modelOptions?.model(choice) == null)) {
      return;
    }
    final selected = selectedThread;
    if (selected == null) {
      _newChatModel = choice;
    } else {
      selected.modelChoice = choice;
    }
    notifyListeners();
  }

  final _unloaded = <String>{};

  /// Threads with older rows on the server, by how many rows were read so far.
  final _olderRows = <String, int>{};

  /// Threads the dashboard knows by their [ChatThread.id]; a thread created
  /// here is not one until the transport reports its id.
  final _bound = <ChatThread>{};
  var _sentMessages = 0;
  final _replies = <StreamSubscription<ChatEvent>>{};

  /// The listeners for turns Hermes chains after a reply, which outlive it.
  final _following = <StreamSubscription<ChatEvent>>{};

  /// The prompts sent while a thread was replying, oldest first.
  final _queueTurnReady = <ChatThread>{};
  final _queueSettled = <ChatThread>{};
  final _queues = <ChatThread, List<QueuedPrompt>>{};
  final _suspendedQueues = <ChatThread>{};

  /// The threads whose queue waits for the session to settle, each with the
  /// fallback timer that sends it when no settle report comes.
  final _settleTimers = <ChatThread, Timer>{};

  /// The threads that changed on the server in a way the stream cannot carry,
  /// to read again once their reply is over.
  final _refetch = <ChatThread>{};
  String? _selectedId;
  String? get selectedId => _selectedId;
  final _emptyController = InMemoryChatController();
  final _chatControllers = <String, InMemoryChatController>{};
  NotificationTarget? _pendingTap;

  /// Whether the held tap came from another destination, which may fetch a
  /// session the loaded threads do not hold, unlike a notification tap.
  bool _pendingFetch = false;

  /// The text a link brought with the held tap, for its composer once the
  /// chat is open.
  String? _pendingTapPrompt;
  InterruptedChatOpening? _requestedOpening;
  InterruptedChatOpening? _interruptedOpening;

  /// Takes the interrupted intent once activity is verified again. The owner
  /// must arbitrate newer intents and dismissal before opening it or its draft.
  InterruptedChatOpening? takeInterruptedOpening() {
    if (!active) return null;
    final opening = _interruptedOpening;
    _interruptedOpening = null;
    return opening;
  }

  void _finishOpening(InterruptedChatOpening? opening) {
    if (identical(opening, _requestedOpening)) _requestedOpening = null;
  }

  ChatThread? get selectedThread {
    for (final thread in _threads) {
      if (thread.id == _selectedId) return thread;
    }
    return null;
  }

  /// Whether [id] has older messages on the server than those loaded.
  bool hasOlder(String id) => _olderRows.containsKey(id);

  int get threadListGeneration => _loadGeneration;
  bool get threadListInvalidationBlocked =>
      _loadingThreads || (housekeeping?.hasPendingChanges ?? false);
  bool threadListAvailable(ChatThread thread) =>
      !_queueUnavailable.contains(thread);

  /// Applies list availability without dispatching or deleting queued work.
  void setThreadListAvailability(ChatThread thread, {required bool available}) {
    if (available) {
      _queueUnavailable.remove(thread);
      if (_queueErrors[thread] == _queueMissingTarget) {
        _queueErrors.remove(thread);
      }
    } else {
      _queueUnavailable.add(thread);
      if (queueStore != null && queueBusy(thread)) _restoredQueues.add(thread);
      if (_queues[thread]?.isNotEmpty ?? false) {
        _queueErrors.putIfAbsent(thread, () => _queueMissingTarget);
        if (_queues[thread]!.any((prompt) => prompt.durable != null)) {
          _restoredQueues.add(thread);
        }
      }
    }
  }

  void threadListInvalidationFailed({
    required String profile,
    required int generation,
  }) {
    if (!active || _profile != profile || _loadGeneration != generation) return;
    _threadsFailed = true;
    notifyListeners();
  }

  /// Reads the first page of [profile]'s chats, at least as many as the list
  /// holds, so that a change merges into everything the user can see.
  Future<ThreadPage> readThreadListPage(String profile) {
    final count = _threads.where((thread) => thread.remote).length;
    return repository!.loadThreadPage(
      limit: count > 50 ? count : 50,
      profile: profile,
    );
  }

  /// Whether a [refreshThreadList] was asked for while the list could not
  /// take it, and waits for the list to settle.
  bool _listRefreshPending = false;

  /// Reads the shown profile's chats again, for a chat that appeared on the
  /// server, and merges them in without touching the open chat or any reply
  /// in flight. While the list is loading or has pending changes it waits
  /// and reads when they are done; a failed read leaves the list as it is.
  Future<void> refreshThreadList() async {
    final profile = _profile;
    if (!active || repository == null || profile == null) return;
    if (threadListInvalidationBlocked) {
      _listRefreshPending = true;
      return;
    }
    final generation = _loadGeneration;
    try {
      final page = await readThreadListPage(profile);
      final applied = applyInvalidatedThreads(
        page,
        profile: profile,
        generation: generation,
      );
      // A change that started during the read: wait for it and read again.
      if (!applied &&
          active &&
          _profile == profile &&
          generation == _loadGeneration &&
          threadListInvalidationBlocked) {
        _listRefreshPending = true;
      }
    } on Object {
      // The next find, or opening the screen again, reads the list.
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_listRefreshPending && !threadListInvalidationBlocked) {
      _listRefreshPending = false;
      unawaited(refreshThreadList());
    }
  }

  bool applyInvalidatedThreads(
    ThreadPage page, {
    required String profile,
    required int generation,
  }) {
    if (!active ||
        _profile != profile ||
        generation != _loadGeneration ||
        threadListInvalidationBlocked) {
      return false;
    }
    final known = {for (final thread in _threads) thread.id: thread};
    final present = <String>{};
    final next = <ChatThread>[];
    for (final fresh in page.threads) {
      if (!present.add(fresh.id)) continue;
      final thread = known[fresh.id] ?? fresh;
      if (!identical(thread, fresh) && thread.remote) {
        thread
          ..title = fresh.title
          ..named = fresh.named
          ..pinned = fresh.pinned
          ..updatedAt = fresh.updatedAt;
        // The open chat was marked read when it opened; the list may be older.
        if (thread.id != _selectedId) thread.unread = fresh.unread;
      }
      if (thread.remote) {
        _bound.add(thread);
        if (!known.containsKey(thread.id)) _unloaded.add(thread.id);
        setThreadListAvailability(thread, available: true);
      }
      next.add(thread);
    }
    for (final thread in _threads) {
      if (present.contains(thread.id)) continue;
      final retained =
          !thread.remote ||
          page.hasMore ||
          thread.id == _selectedId ||
          thread.isReplying ||
          (_queues[thread]?.isNotEmpty ?? false) ||
          queueBusy(thread) ||
          _followingIds.contains(thread.id);
      if (!retained) continue;
      next.add(thread);
      if (thread.remote && !page.hasMore) {
        setThreadListAvailability(thread, available: false);
      }
    }
    _threads =
        housekeeping?.begin(
          ThreadPage(
            threads: next,
            nextOffset: page.nextOffset,
            hasMore: page.hasMore,
          ),
        ) ??
        next;
    _threadsFailed = false;
    notifyListeners();
    return true;
  }

  String? _failedListProfile;

  /// Lists [profile], retrying the failed owner when omitted after a failure.
  /// Initial loading discovers the server default without changing it.
  Future<void> loadThreads([String? profile]) =>
      _loadThreads(profile ?? (_threadsFailed ? _failedListProfile : null));

  /// The first page of a thread's messages that is being read, by thread id.
  final _loadingMessages = <String, Future<void>>{};

  Future<void> loadOlder(String id) =>
      _ChatControllerHistory(this)._loadOlderImpl(id);

  /// Reads [id] again from the dashboard after it changed elsewhere (another
  /// window): its title and pin, and its messages once they were loaded. A
  /// chat that is gone leaves the list. Nothing is read while a reply streams
  /// into it, which would replace the reply in progress.
  Future<void> refreshThread(String id) =>
      _ChatControllerHistory(this)._refreshThreadImpl(id);

  /// Whether [target] names a chat on [profile]. A thread id is only unique
  /// within a profile, so one posted under another profile is not ours. A
  /// notification from an earlier build carries no profile; it still matches
  /// on its thread id alone.
  static bool _isOnProfile(NotificationTarget? target, String? profile) =>
      target != null && (target.profile == null || target.profile == profile);

  /// Opens the chat [target] names. With [fetchMissing] one the loaded
  /// threads do not hold is fetched, on its own profile. A [prompt] goes to
  /// the composer once the chat is open, and is dropped when it cannot be.
  void open(
    NotificationTarget target, {
    required bool fetchMissing,
    String? prompt,
  }) {
    if (!active) return;
    final epoch = _activityEpoch;
    final requested = _requestedOpening = InterruptedChatOpening(
      target: target,
      fetchMissing: fetchMissing,
      prompt: prompt,
    );
    _interruptedOpening = null;
    final generation = ++_openGeneration;
    breadcrumbs('chat.open.requested', {'fetch_missing': fetchMissing});
    onShowChat?.call();
    if (!_currentActivity(epoch)) return;
    if (_loadingThreads) {
      _pendingTap = target;
      _pendingFetch = fetchMissing;
      _pendingTapPrompt = prompt;
    } else if (_isOnProfile(target, _profile) &&
        _threads.any((t) => t.id == target.threadId)) {
      select(target.threadId);
      if (!_currentActivity(epoch)) return;
      onOpened?.call();
      if (!_currentActivity(epoch)) return;
      if (prompt != null) onDraft?.call(prompt);
      _finishOpening(requested);
    } else if (fetchMissing) {
      _opening = _openMissing(
        target,
        generation: generation,
        prompt: prompt,
      ).whenComplete(() => _finishOpening(requested));
    } else {
      _failOpen();
      _finishOpening(requested);
    }
  }

  /// Opens a chat the loaded threads do not hold: one on another profile, or
  /// older than the first page of sessions.
  Future<void> _openMissing(
    NotificationTarget target, {
    int? generation,
    String? prompt,
  }) async {
    if (!active) return;
    final epoch = _activityEpoch;
    generation ??= _openGeneration;
    final repository = this.repository;
    final profile = target.profile ?? _profile;
    if (repository == null) return _failOpen();
    try {
      if (profile != _profile) await loadThreads(profile);
      if (!active || generation != _openGeneration) return;
      // A failed switch leaves the old profile's threads on screen.
      if (profile != _profile) return _failOpen();
      if (!_threads.any((t) => t.id == target.threadId)) {
        final thread = await repository.loadThread(
          target.threadId,
          profile: profile,
        );
        if (!active || generation != _openGeneration) return;
        if (thread == null) return _failOpen();
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
        notifyListeners();
      }
      if (!_currentActivity(epoch) || generation != _openGeneration) return;
      select(target.threadId);
      if (!_currentActivity(epoch)) return;
      onOpened?.call();
      if (!_currentActivity(epoch)) return;
      if (prompt != null) onDraft?.call(prompt);
    } on Object {
      if (active && generation == _openGeneration) _failOpen();
    }
  }

  /// [profile] if the server has it, else null (and a note), so a link never
  /// moves the chat to a profile that does not exist. The current profile and
  /// a chat with no profiles to ask are taken as they are; a profile list that
  /// cannot be read counts as not knowing the profile.
  Future<String?> knownProfile(String? profile) async {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return null;
    final profiles = this.profiles;
    if (profile == null || profile == _profile || profiles == null) {
      return profile;
    }
    try {
      final known = await profiles.list();
      if (!_currentActivity(epoch)) return null;
      if (known.any((p) => p.name == profile)) return profile;
    } on Object {
      // Falls through: an unreadable list cannot vouch for the profile.
    }
    if (!_currentActivity(epoch)) return null;
    breadcrumbs('deeplink.ignored', {'reason': 'unknown_profile'});
    return null;
  }

  /// Opens the chat of the open request in another profile that the snapshot
  /// has had longest, for when the open profile has none of its own. The
  /// snapshot can be out of date, so each request, oldest first, is checked
  /// with the server before anything changes: the first whose session still
  /// waits is opened (switching to its profile), and when none does nothing
  /// moves and this is false, which leaves the chat list showing.
  Future<bool> openOldestStoredRequest() async {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return false;
    final read = readSnapshot;
    final transport = this.transport;
    if (read == null) return false;
    final SurfaceSnapshot? snapshot;
    try {
      snapshot = await read();
    } on Object {
      return false;
    }
    if (!_currentActivity(epoch)) return false;
    final current = _profile ?? kDefaultProfile;
    final waiting = [
      for (final request in snapshot?.pending ?? const <PendingRequest>[])
        if (request.profile != current) request,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final request in waiting) {
      if (transport != null) {
        final Map<String, String> statuses;
        try {
          statuses = await transport.activeStatuses(profile: request.profile);
        } on Object {
          if (!_currentActivity(epoch)) return false;
          rethrow;
        }
        if (!_currentActivity(epoch)) return false;
        if (statuses[request.threadId] != 'waiting') continue;
      }
      final profile = await knownProfile(request.profile);
      if (!_currentActivity(epoch)) return true;
      if (profile == null) continue;
      open(
        NotificationTarget(threadId: request.threadId, profile: profile),
        fetchMissing: true,
      );
      return true;
    }
    return false;
  }

  /// Opens the chat whose open approval, question or input request was
  /// raised first, judged by when its reply began, among the loaded chats.
  /// False when no loaded chat holds one.
  bool openOldestRequest() {
    if (!active) return false;
    final epoch = _activityEpoch;
    ChatThread? oldest;
    DateTime? since;
    for (final thread in _threads) {
      for (final message in thread.messages) {
        if (!message.awaitingInput) continue;
        if (since == null || message.createdAt.isBefore(since)) {
          oldest = thread;
          since = message.createdAt;
        }
      }
    }
    if (oldest == null) return false;
    onShowChat?.call();
    if (!_currentActivity(epoch)) return false;
    select(oldest.id);
    if (!_currentActivity(epoch)) return false;
    onOpened?.call();
    return true;
  }

  Future<bool> restoreHandoff(
    NotificationTarget target,
    bool Function() valid,
  ) async {
    final repository = this.repository;
    final profile = target.profile;
    if (!active || repository == null || profile == null || !valid()) {
      return false;
    }
    final generation = ++_openGeneration;
    bool current() => active && generation == _openGeneration && valid();
    try {
      final runningThread = _profile == profile
          ? _threads.where((t) => t.id == target.threadId).firstOrNull
          : null;
      if (runningThread?.isReplying == true) {
        _selectedId = runningThread!.id;
        _markRead(runningThread);
        notifyListeners();
        if (!current()) return false;
        onOpened?.call();
        return true;
      }

      if (profiles != null &&
          !(await profiles!.list()).any((p) => p.name == profile)) {
        return false;
      }
      if (!current()) return false;
      final thread = await repository.loadThread(
        target.threadId,
        profile: profile,
      );
      if (thread == null || !current()) return false;
      final page = await repository.loadMessagePage(
        target.threadId,
        profile: profile,
      );
      if (!current()) return false;
      if (_profile != profile || _loadingThreads) {
        await _loadThreads(profile, valid: current);
      }
      if (current() && _threadsFailed) {
        throw StateError('Could not load the profile');
      }
      if (!current() || _profile != profile || _threadsFailed) return false;
      final existing = _threads
          .where((t) => t.id == target.threadId)
          .firstOrNull;
      final selected = existing ?? thread;
      if (existing == null) {
        _threads.insert(0, selected);
        _bound.add(selected);
      }
      selected.messages
        ..clear()
        ..addAll(page.messages);
      _unloaded.remove(selected.id);
      if (page.hasMore) _olderRows[selected.id] = page.rows;
      if (thread.unread) selected.unread = true;
      _selectedId = selected.id;
      _markRead(selected);
      await controllerFor(selected).setMessages(chatThreadToFlyer(selected));
      if (!current()) return false;
      notifyListeners();
      if (!current()) return false;
      _pickUp(selected);
      if (!current()) return false;
      onOpened?.call();
      return true;
    } on Object {
      if (!current()) return false;
      rethrow;
    }
  }

  Future<void> openBot(BotChatContext context) async {
    if (!active) return;
    final generation = ++_openGeneration;
    onShowChat?.call();
    final repository = this.repository;
    if (repository == null) return _failOpen();
    final profile = context.bot.name;
    try {
      if (_loadingThreads || _profile != profile) await loadThreads(profile);
      if (!active || generation != _openGeneration) return;
      if (_profile != profile) return _failOpen();
      var thread = _threads.where((t) => t.id == context.storedId).firstOrNull;
      if (thread == null) {
        thread = await repository.loadThread(
          context.storedId,
          profile: profile,
        );
        if (!active || generation != _openGeneration) return;
        if (thread == null) return _failOpen();
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
      }
      thread.botContext = context;
      thread
        ..title = BotModeChatRepository.title
        ..named = true;
      select(thread.id);
      onOpened?.call();
    } on Object {
      if (active && generation == _openGeneration) _failOpen();
    }
  }

  /// The chats of every profile that match [query], newest first. Each
  /// profile is asked at once; one that fails is left out, and the search
  /// fails only when all of them do.
  Future<List<ThreadSearchHit>> _searchAllProfiles(String query) async {
    if (!active) return const [];
    final epoch = _activityEpoch;
    final repository = this.repository!;
    final known = await profiles!.list();
    if (!_currentActivity(epoch)) return const [];
    final answers = await Future.wait([
      for (final profile in known)
        repository
            .searchThreads(query, profile: profile.name)
            .then<List<ThreadSearchHit>?>(
              (h) => h,
              onError: (Object _) => null,
            ),
    ]);
    if (!_currentActivity(epoch)) return const [];
    if (answers.isNotEmpty && answers.every((a) => a == null)) {
      throw StateError('No profile could be searched');
    }
    return [for (final hits in answers) ...?hits]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Opens a chat the search found, on the profile it was found in.
  void openSearchHit(ThreadSearchHit hit) {
    if (!active) return;
    search?.remember(search!.query);
    open(
      NotificationTarget(threadId: hit.id, profile: hit.profile ?? _profile),
      fetchMissing: true,
    );
  }

  /// Moves on to the first remaining thread when the open one is archived or
  /// deleted.
  void _threadRemoved(ChatThread thread) {
    _removeMoa(thread);
    _undoing.remove(thread);
    _turnProblems.remove(thread);
    _sessionActionGenerations.remove(thread);
    _removeTodo((_profile, thread.id));
    _removeConnector((_profile, thread.id));
    _removeBilling((_profile, thread.id));
    _ownedBindings.remove(thread);
    _usage.remove(thread)?.dispose();
    _reactions.remove(thread)?.dispose();
    _sideResults.remove(thread)?.dispose();
    _processOutputs.remove(thread)?.clear();
    _memoryDecisions.remove(thread)?.dispose();
    _sessionStates.remove(thread);
    _reclaimedQueueReview.remove(thread);
    _warnings.remove(thread)?.clear();
    _warningGenerations.remove(thread);
    _queues.remove(thread);
    _loadedQueues.remove(thread);
    _restoredQueues.remove(thread);
    _hiddenQueueOrder.remove(thread);
    _queueUnavailable.remove(thread);
    _finishQueueBinding(thread, false);
    _suspendedQueues.remove(thread);
    _settleTimers.remove(thread)?.cancel();
    _refetch.remove(thread);
    liveActivities?.endChat(thread.id, _profile);
    _watchSource?.drop(thread);
    _announcedTurns.remove(thread);
    _carried.remove((_profile, thread.id));
    _rememberedSince.remove((_profile, thread.id));
    _touched.remove(thread);
    _reportSurface(SurfaceTrigger.threads);
    if (_selectedId != thread.id) return;
    _selectedId = _threads.firstOrNull?.id;
    if (_selectedId != null) _loadMessages(_selectedId!);
  }

  /// Asks the transport to drop a connection the OS killed during sleep, and
  /// re-checks which sessions are mid-turn afterwards.
  void checkConnection() {
    if (!active) return;
    final epoch = _activityEpoch;
    transport?.checkConnection().then((_) {
      if (_currentActivity(epoch)) unawaited(refreshActive());
    }, onError: (Object _) {});
  }

  // Registered callbacks retain instance tear-off identity through disposal.
  void _queueIdentityChanged() =>
      _ChatControllerQueues(this)._queueIdentityChanged();
  void _billingLockChanged() =>
      _ChatControllerBilling(this)._billingLockChanged();

  void _cancelOwnedSubscription() {
    unawaited(_ownedSubscription?.cancel());
    _ownedSubscription = null;
  }

  void _cancelConnectorActivitySubscription() {
    unawaited(_connectorActivitySubscription?.cancel());
    _connectorActivitySubscription = null;
  }

  @override
  void dispose() {
    queueChanges?.removeListener(_queueIdentityChanged);
    _cancelQueueBindings();
    activity?.removeListener(_activityChanged);
    appLock?.removeListener(_billingLockChanged);
    _activityEpoch++;
    housekeeping?.setActivity(false);
    _replayEnds?.cancel();
    for (final reply in _replies) {
      reply.cancel();
    }
    for (final thread in _announcedTurns) {
      _abandon(thread);
    }
    _stopFollowing();
    _cancelSettleWaits();
    search?.dispose();
    _emptyController.dispose();
    for (final controller in _chatControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  InMemoryChatController controllerFor(ChatThread? thread) {
    if (thread == null) return _emptyController;
    return _chatControllers.putIfAbsent(
      thread.id,
      () => InMemoryChatController(messages: chatThreadToFlyer(thread)),
    );
  }

  /// Leaves no chat selected, as when the selected one moves to a window of
  /// its own.
  void clearSelection() {
    if (!active) return;
    if (_selectedId == null) return;
    breadcrumbs('chat.thread.closed');
    _openGeneration++;
    _selectedId = null;
    notifyListeners();
  }

  /// The last open of a chat that had to be fetched. It never throws.
  Future<void> _opening = Future<void>.value();

  /// Starts a new chat once a chat that was being opened has been opened, so
  /// the new one stays in front. A new chat nothing was written in is reused
  /// instead of adding a second empty one.
  Future<void> newThreadWhenOpened({bool Function()? valid}) async {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return;
    await _opening.catchError((Object _) {});
    if (!_currentActivity(epoch) || valid?.call() == false) return;
    final selected = selectedThread;
    if (selected != null && !selected.remote && selected.messages.isEmpty) {
      return;
    }
    newThread();
  }

  void newThread() {
    if (!active) return;
    breadcrumbs('chat.thread.new');
    _openGeneration++;
    final thread = ChatThread(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAt: DateTime.now(),
      modelChoice: _newChatModel,
    );
    _threads.insert(0, thread);
    _selectedId = thread.id;
    notifyListeners();
  }

  void select(String id) {
    if (!active) return;
    final epoch = _activityEpoch;
    breadcrumbs('chat.thread.selected', {
      'remote': _threads.any((t) => t.id == id && t.remote),
    });
    _openGeneration++;
    _openFailed = false;
    _selectedId = id;
    notifyListeners();
    if (!_currentActivity(epoch)) return;
    final load = repository != null ? _loadMessages(id) : Future<void>.value();
    final thread = _threads.where((t) => t.id == id).firstOrNull;
    if (thread != null) {
      _markRead(thread);
      unawaited(_restoreQueue(thread));
      final profile = _profile;
      unawaited(
        load.then((_) {
          if (_currentActivity(epoch) &&
              _profile == profile &&
              _selectedId == id &&
              _threads.contains(thread)) {
            _pickUp(thread);
          }
        }),
      );
    }
    unawaited(refreshActive());
  }

  /// Tells the dashboard [thread] was read, once per opening. A failure is
  /// only logged and the chat counts as unread again, so the next opening
  /// retries.
  void _markRead(ChatThread thread) {
    final repository = this.repository;
    if (repository == null || !thread.remote || !thread.unread) return;
    thread.unread = false;
    unawaited(
      repository
          .markRead(thread.id, profile: _profile)
          .then<void>(
            (_) {},
            onError: (Object e) {
              thread.unread = true;
              events('chat.mark_read_failed', {
                'error_type': '${e.runtimeType}',
              });
            },
          ),
    );
  }

  /// Starts following [thread] once, so a turn running there that this client
  /// never streamed (started on the TUI or another device) streams into it
  /// and shows its replying indicator. An idle thread closes the stream
  /// without events.
  void _pickUp(ChatThread thread) {
    if (queueStore != null) unawaited(_restoreQueue(thread));
    final transport = this.transport;
    if (!active || transport == null || !thread.remote) return;
    if (thread.isReplying) return;
    _followUps(transport, thread, _profile);
  }

  final _followingIds = <String>{};

  /// How many sends of a thread are streaming. A thread that is followed while
  /// its own send runs is not abandoned: the send goes on feeding it.
  final _sending = <ChatThread, int>{};

  /// The remote threads a turn is running in right now, by id — including
  /// turns started outside this client. Drives the sidebar's working
  /// indicator; a thread this client is streaming into already counts
  /// through its pending reply.
  final _active = <String>{};
  var _activeRefresh = 0;
  Set<String> get activeThreads => Set.unmodifiable(_active);

  /// Asks the transport which sessions are mid-turn and marks their threads,
  /// dropping ones whose turn ended. False when the transport could not
  /// say, so a poll can back off.
  Future<bool> refreshActive() async {
    final transport = this.transport;
    if (transport == null || !active) return true;
    final generation = _loadGeneration;
    final refresh = ++_activeRefresh;
    final Map<String, String> statuses;
    try {
      statuses = await transport.activeStatuses();
    } on Object {
      return false;
    }
    if (!active || generation != _loadGeneration || refresh != _activeRefresh) {
      return true;
    }
    final working = <String>{
      for (final thread in _threads)
        if (statuses[thread.id] == 'working' ||
            statuses[thread.id] == 'waiting')
          thread.id,
    };
    var changed = working.length != _active.length;
    if (!changed) {
      for (final id in working) {
        if (!_active.contains(id)) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return true;
    _active
      ..clear()
      ..addAll(working);
    notifyListeners();
    return true;
  }

  /// Loaded messages are keyed `<session>-<row id>`, so a count of the
  /// thread's messages would collide with them.
  String _newMessageId(ChatThread thread) =>
      '${thread.id}-local-${_sentMessages++}';

  Future<List<SlashCommand>> slashCommands() =>
      _ChatControllerCommands(this)._slashCommandsImpl();

  /// Runs a gateway command without putting it through prompt.submit or the
  /// reply queue. Display-only command output stays in this visit's chat.
  Future<bool> runSlashCommand(String command) =>
      _ChatControllerCommands(this)._runSlashCommandImpl(command);

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? lastPromptText(ChatThread thread) =>
      _ChatControllerCommands(this)._lastPromptTextImpl(thread);

  /// Whether the last prompt of [thread] can be taken back on the server:
  /// edited, or sent again in place of its turn.
  bool canEditLastPrompt(ChatThread thread) =>
      _ChatControllerCommands(this)._canEditLastPromptImpl(thread);

  /// Sends the text of the last prompt again. The server drops the turn it
  /// replaces first, so the model does not see that reply again. A command, a
  /// prompt that had files (they are not sent again) and a server that cannot
  /// undo get a new turn instead.
  Future<void> retry(ChatThread thread) =>
      _ChatControllerCommands(this)._retryImpl(thread);

  /// Takes the last prompt of [thread] back on the server and puts its text
  /// in the composer. Its files are not put back.
  Future<void> editLastPrompt(ChatThread thread) =>
      _ChatControllerCommands(this)._editLastPromptImpl(thread);

  /// The retry or edit running on the last turn of [thread], or why the last
  /// one failed.
  TurnActionStatus turnActionStatus(ChatThread thread) =>
      _ChatControllerCommands(this)._turnActionStatusImpl(thread);

  /// The threads whose last turn is being dropped, and for what, so a second
  /// tap does not drop the turn before it too.
  final _undoing = <ChatThread, TurnAction>{};

  /// Why the last retry or edit of a thread failed, until the next one or the
  /// next prompt.
  final _turnProblems = <ChatThread, String>{};

  /// The prompts waiting in [thread] for its reply to end.
  List<QueuedPrompt> queuedIn(ChatThread thread) =>
      _ChatControllerQueues(this)._queuedInImpl(thread);

  /// Whether [thread] holds queued prompts that no reply will send, because
  /// the last one was stopped or failed.
  bool queuePaused(ChatThread thread) =>
      _ChatControllerQueues(this)._queuePausedImpl(thread);

  FutureOr<void> removeQueued(ChatThread thread, QueuedPrompt prompt) =>
      _ChatControllerQueues(this)._removeQueuedImpl(thread, prompt);

  /// Explicitly resumes queued work after review; unsent prompts stay queued.
  void sendQueued(ChatThread thread) =>
      _ChatControllerQueues(this)._sendQueuedImpl(thread);

  /// Sends [typed] and [files] in the selected thread, or in a new one, and
  /// streams the reply into it. While the thread replies, or holds a paused
  /// queue, the prompt joins its queue instead. Returns false when it was
  /// neither sent nor queued, after telling the user why.
  FutureOr<bool> submit(String typed, List<SharedFile> files) {
    if (!active) return false;
    if (!modelSendAllowed) {
      report('Choose a usable model before sending. Your draft was kept.');
      return false;
    }
    return _submitTo(selectedThread, typed, files);
  }

  FutureOr<bool> _submitTo(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
  }) {
    if (!active) return false;
    if (_queueUnavailable.contains(selected)) {
      report(_queueMissingTarget);
      return false;
    }
    final scopedProfile = _profile != null && _profile!.trim().isNotEmpty;
    if (selected != null &&
        queueStore != null &&
        !scopedProfile &&
        (selected.isReplying || _queues.containsKey(selected))) {
      report(
        "This chat's profile could not be confirmed. Your draft was kept.",
      );
      return false;
    }
    if (selected != null &&
        (_enqueueing.contains(selected) ||
            _queuePreparing.contains(selected) ||
            _queueRemoving.contains(selected))) {
      return false;
    }
    if (selected != null &&
        queueStore != null &&
        scopedProfile &&
        _bound.contains(selected) &&
        !_loadedQueues.contains(selected)) {
      return _submitAfterQueueRestore(selected, typed, files, displayText);
    }
    if (_sessionStates[selected]?.reclaimedReason != null) {
      report('Reopen this session before sending another prompt.');
      return false;
    }
    _turnProblems.remove(selected);
    if (selected == null ||
        !selected.isReplying && !_queues.containsKey(selected)) {
      return _send(selected, typed, files, displayText: displayText);
    }
    if (_sizesOrExplain(files) == null) return false;
    if (queueStore != null) {
      return _enqueueProtected(selected, typed, files, displayText);
    }
    (_queues[selected] ??= []).add(
      QueuedPrompt(typed, files, displayText: displayText),
    );
    (selected.isReplying || _settleTimers.containsKey(selected))
        ? notifyListeners()
        : _drainQueue(selected);
    return true;
  }

  /// The app is leaving the front: remembers the chats whose reply still runs,
  /// in this profile and in the ones left since, which a background run
  /// announces once they finish. What an earlier run announced is forgotten:
  /// it described the last time the app was away.
  void rememberRunningReplies() =>
      _ChatControllerSurfaces(this)._rememberRunningRepliesImpl();

  /// The app is in front: the replies are shown here, so nothing is left for
  /// a background run to announce. A reply that a run finished or whose
  /// session no longer runs has ended, and is not carried on. What a run
  /// announced stays on record only for the replay of its ending, which
  /// [replayGrace] allows for.
  void forgetRunningReplies() =>
      _ChatControllerSurfaces(this)._forgetRunningRepliesImpl();

  /// The threads the Live Activities and the watch status were told about,
  /// whatever profile is in view: a reply goes on in a profile that went out of
  /// view, and closing the chat must end it on both too.
  final _announcedTurns = <ChatThread>{};

  void _titled(ChatThread thread, String title) {
    if (thread.isCanonicalBotChat) return;
    thread
      ..title = title
      ..named = true;
  }

  /// Gives a thread created here the id the dashboard stored it under, so it
  /// stays one row and later sends continue that session.
  void _bindThread(ChatThread thread, String id) {
    if (_bound.contains(thread)) return;
    if (thread.id != id || !thread.remote) {
      _invalidateSessionActions(thread);
    }
    final controller = _chatControllers.remove(thread.id);
    if (_selectedId == thread.id) _selectedId = id;
    thread.id = id;
    thread.remote = true;
    _bound.add(thread);
    _finishQueueBinding(thread, true);
    notifyListeners();
    if (controller != null) _chatControllers[id] = controller;
  }

  void _retargetBoundThread(ChatThread thread, String id) {
    if (thread.id == id) return;
    _invalidateSessionActions(thread);
    final previousId = thread.id;
    _removeTodo((_profile, previousId));
    _removeConnector((_profile, previousId));
    _removeBilling((_profile, previousId));
    final controller = _chatControllers.remove(previousId);
    if (_selectedId == previousId) _selectedId = id;
    _unloaded.remove(previousId);
    _olderRows.remove(previousId);
    if (_followingIds.remove(previousId)) _followingIds.add(id);
    if (_active.remove(previousId)) _active.add(id);
    thread.id = id;
    if (controller != null) _chatControllers[id] = controller;
    _syncTodo(thread, _profile);
    notifyListeners();
  }

  /// When a reply last ended or a request last changed in a chat, which the
  /// list the server gave us does not know yet.
  final _touched = <ChatThread, DateTime>{};

  /// When each open request was first seen; Hermes sends no creation time.
  final _requestSeen = <String, DateTime>{};

  Future<void> answerApproval(
    ChatThread thread,
    String requestId,
    String choice,
  ) =>
      _ChatControllerRequests(this)
          ._answerApprovalImpl(thread, requestId, choice);

  /// Why the queue of a thread is held while a stop is in flight. A queue is
  /// otherwise paused by nothing but its absent settle wait, so the record
  /// only matters until the interrupts asked for are answered.
  final _holds = <ChatThread, _Hold>{};

  /// The interrupts sent for the current reply of a thread that have not been
  /// answered. A send of its own forgets the ones before it.
  final _interrupts = <ChatThread, int>{};

  /// Bumped when the user sends in a thread. An interrupt's answer is about
  /// the generation it was sent in, and changes no hold of a later one.
  final _generations = <ChatThread, int>{};

  Future<void> stopReply(ChatThread thread) =>
      _ChatControllerRequests(this)._stopReplyImpl(thread);

  Future<void> skipUnsupported(
    ChatThread thread,
    String requestId,
    UnsupportedKind kind,
  ) =>
      _ChatControllerRequests(this)
          ._skipUnsupportedImpl(thread, requestId, kind);

  Future<void> answerVaultRequest(
    ChatThread thread,
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) => _ChatControllerRequests(this)._answerVaultRequestImpl(
    thread,
    requestId,
    kind,
    identifier: identifier,
    password: password,
    code: code,
  );

  Future<void> answerClarify(
    ChatThread thread,
    String requestId,
    Map<String, List<String>> answers,
  ) =>
      _ChatControllerRequests(this)
          ._answerClarifyImpl(thread, requestId, answers);
}
