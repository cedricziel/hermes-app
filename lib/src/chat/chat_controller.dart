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
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
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

part 'chat_controller_reactions.dart';

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

  BillingVerificationController? billingVerificationIn(ChatThread thread) {
    final owner = (_profile, thread.id),
        controller = _billing[(_profile, thread.id)],
        binding = _billingBindings[(_profile, thread.id)];
    return controller != null &&
            binding != null &&
            _threads.contains(thread) &&
            _currentBilling(owner, controller, binding, _activityEpoch)
        ? controller
        : null;
  }

  bool _currentBilling(
    (String?, String) owner,
    BillingVerificationController controller,
    OwnedSessionBinding binding,
    int epoch,
  ) {
    final source = transport;
    return appLock != null &&
        _currentActivity(epoch) &&
        _profile == owner.$1 &&
        _billing[owner] == controller &&
        _billingBindings[owner] == binding &&
        source is OwnedSessionTransport &&
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) ==
            binding;
  }

  BillingVerificationController? _adoptBilling(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    if (appLock == null) return null;
    final existing = _billing[owner];
    if (existing != null && _billingBindings[owner] == binding) return existing;
    _removeBilling(owner);
    final source = transport, epoch = _activityEpoch;
    final controller = BillingVerificationController(
      now: _clock,
      openBrowser: billingBrowser,
      copyCode: billingCopyCode,
      events: events,
      breadcrumbs: breadcrumbs,
    );
    _billing[owner] = controller;
    _billingBindings[owner] = binding;
    bool current() =>
        _currentBilling(owner, controller, binding, epoch) &&
        !(appLock?.covered ?? true);
    controller.addListener(notifyListeners);
    controller.setLocked(appLock?.covered ?? true);
    controller.bind(
      BillingVerificationScope(
        connection: binding.connection,
        attachment: binding,
        sessionId: binding.runtimeId,
        profile: binding.profile,
      ),
      authorize: current,
      supported: source is BillingVerificationTransport
          ? () => (source as BillingVerificationTransport)
                .billingVerificationSupported(binding)
          : () => false,
      request: source is BillingVerificationTransport
          ? (_) {
              if (!current()) throw StateError('Billing attachment retired');
              return (source as BillingVerificationTransport).stepUpBilling(
                binding,
                authorize: current,
              );
            }
          : null,
    );
    return controller;
  }

  void _removeBilling((String?, String) owner) {
    _billingBindings.remove(owner);
    _billing.remove(owner)?.dispose();
  }

  void _clearBilling() {
    for (final controller in _billing.values) {
      controller.dispose();
    }
    _billing.clear();
    _billingBindings.clear();
  }

  void _billingLockChanged() {
    if (disposed) return;
    for (final controller in _billing.values.toList()) {
      controller.setLocked(appLock?.covered ?? true);
    }
  }

  void _onBillingOwnership(OwnedSessionChange change) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_billingBindings[owner] == change.binding) {
        _removeBilling(owner);
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if ((owner.$1?.isEmpty ?? true) ||
        source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) !=
            change.binding) {
      return;
    }
    _adoptBilling(owner, change.binding);
  }

  bool _onBillingEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! BillingVerificationReceived) return false;
    final source = transport;
    if (!active ||
        profile != _profile ||
        (profile?.isEmpty ?? true) ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return true;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final owner = (profile, thread.id),
        epoch = _activityEpoch,
        controller = _adoptBilling((profile, thread.id), binding);
    if (controller == null ||
        !_currentBilling(owner, controller, binding, epoch)) {
      return true;
    }
    controller.acceptVerification({
      'verification_url': event.details.verificationUrl,
      'user_code': event.details.userCode,
    }, attachment: binding);
    return true;
  }

  final BotModeChatRepository? botChats;
  final Future<PromptQueueStore> Function()? queueStore;
  final QueueScope? Function(ChatThread thread, String? profile)? queueScope;
  final Listenable? queueChanges;
  final bool Function()? canShowQueues;
  bool get queuesVisible => canShowQueues?.call() ?? true;
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
  bool queueNeedsReview(ChatThread thread) => _restoredQueues.contains(thread);
  bool queueBusy(ChatThread thread) =>
      _queueRemoving.contains(thread) ||
      _enqueueing.contains(thread) ||
      _queuePreparing.contains(thread) ||
      _queueDispatching.contains(thread) ||
      _queueRestoring.containsKey(thread);
  String? queueErrorIn(ChatThread thread) => _queueErrors[thread];
  bool queueAvailable(ChatThread thread) =>
      active &&
      _profile != null &&
      _profile!.trim().isNotEmpty &&
      queuesVisible &&
      !_queueUnavailable.contains(thread) &&
      !(_queues[thread]?.any(
            (prompt) =>
                prompt.scope != null &&
                prompt.scope!.conversationId != thread.id,
          ) ??
          false) &&
      _sessionStates[thread]?.reclaimedReason == null &&
      _bound.contains(thread);
  void queueReviewed(QueuedPrompt prompt) => breadcrumbs(
    'chat.queue.reviewed',
    {'count': 1, 'state': prompt.uncertain ? 'uncertain' : 'unsent'},
  );
  void inspectQueued(ChatThread thread) {
    if (!active || !_threads.contains(thread)) return;
    select(thread.id);
    if (repository != null) unawaited(refreshThread(thread.id));
  }

  final _queueBindings = <ChatThread, Completer<bool>>{};
  final _bindingScopes = <ChatThread, QueueScope>{};
  bool _sameQueueOwner(QueueScope? current, QueueScope expected) =>
      current != null &&
      current.serverKey == expected.serverKey &&
      current.accountKey == expected.accountKey &&
      current.profile == expected.profile;
  void _finishQueueBinding(ChatThread thread, bool bound) {
    _bindingScopes.remove(thread);
    final wait = _queueBindings.remove(thread);
    if (wait != null && !wait.isCompleted) wait.complete(bound);
  }

  void _cancelQueueBindings() {
    for (final thread in _queueBindings.keys.toList()) {
      _finishQueueBinding(thread, false);
    }
  }

  void _queueIdentityChanged() {
    _queueEpoch++;
    _queueRestoring.clear();
    for (final entry in _bindingScopes.entries.toList()) {
      if (!_sameQueueOwner(
        queueScope?.call(entry.key, _profile),
        entry.value,
      )) {
        _finishQueueBinding(entry.key, false);
      }
    }
    for (final entry in _queues.entries.toList()) {
      final current = queueScope?.call(entry.key, _profile);
      if (!queuesVisible ||
          entry.value.any(
            (prompt) =>
                prompt.scope != null &&
                !_sameQueueOwner(current, prompt.scope!),
          )) {
        _hiddenQueueOrder[entry.key] = [
          for (final prompt in entry.value)
            if (prompt.scope != null && prompt.durable != null)
              (prompt.scope!, prompt.durable!.id),
        ];
        _queues.remove(entry.key);
        _loadedQueues.remove(entry.key);
        _settleTimers.remove(entry.key)?.cancel();
      }
    }
    if (selectedThread case final thread? when active && queuesVisible) {
      unawaited(_restoreQueue(thread));
    }
    notifyListeners();
  }

  Future<bool> _waitForQueueBinding(ChatThread thread, QueueScope scope) {
    if (_bound.contains(thread)) return Future.value(true);
    _bindingScopes[thread] = scope;
    return (_queueBindings[thread] ??= Completer<bool>()).future;
  }

  Future<PromptQueueStore>? _openedQueueStore;
  final _enqueueing = <ChatThread>{};
  Future<PromptQueueStore> _protectedQueueStore() async {
    try {
      return await (_openedQueueStore ??= queueStore!());
    } on Object {
      _openedQueueStore = null;
      rethrow;
    }
  }

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

  List<MoaProgress> moaIn(ChatThread thread) {
    final source = transport;
    if (!active ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return const [];
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    if (binding == null ||
        binding.profile != _profile ||
        _moaBindings[thread] != binding) {
      return const [];
    }
    return List.unmodifiable(
      (_moaStates[thread]?.cards ?? const <MoaProgress>[]).where(
        (card) =>
            card.turn is ChatMessage && thread.messages.contains(card.turn),
      ),
    );
  }

  void moaDetailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'moa',
    'action': 'details',
  });

  void _beginMoaTurn(ChatThread thread, ChatMessage reply) {
    if (!reply.isPending ||
        !_threads.contains(thread) ||
        !thread.messages.contains(reply)) {
      return;
    }
    final previous = _moaForeground[thread];
    if (identical(previous, reply)) return;
    if (previous != null) _moaStates[thread]?.finish(previous);
    _moaForeground[thread] = reply;
    _moaUnavailable.remove(thread);
    _moaStates[thread]?.beginTurn(reply);
  }

  void _finishMoaTurn(ChatThread thread, ChatMessage reply) {
    if (!identical(_moaForeground[thread], reply)) return;
    _moaForeground.remove(thread);
    _moaStates[thread]?.finish(reply);
  }

  void _removeMoa(ChatThread thread, {bool keepTurn = false}) {
    _moaStates.remove(thread)?.clear();
    _moaBindings.remove(thread);
    if (!keepTurn) {
      _moaForeground.remove(thread);
      _moaUnavailable.remove(thread);
    }
  }

  void _invalidateMoaReferences(ChatThread thread) {
    _moaUnavailable.add(thread);
    final state = _moaStates[thread];
    state?.invalidateReferences();
    if (state != null) notifyListeners();
  }

  void _clearMoa() {
    for (final state in _moaStates.values) {
      state.clear();
    }
    _moaStates.clear();
    _moaBindings.clear();
    _moaForeground.clear();
    _moaUnavailable.clear();
  }

  void _onMoaOwnership(OwnedSessionChange change, int epoch) {
    if (!_currentActivity(epoch) || change.binding.profile != _profile) return;
    final source = transport;
    if (change.connected &&
        (source is! OwnedSessionTransport ||
            (source as OwnedSessionTransport).ownedSessionFor(
                  change.threadId,
                  profile: _profile,
                ) !=
                change.binding)) {
      return;
    }
    for (final thread
        in _threads.where((thread) => thread.id == change.threadId).toList()) {
      if (change.connected &&
          _moaBindings[thread] != null &&
          _moaBindings[thread] != change.binding) {
        _removeMoa(thread, keepTurn: true);
        _moaUnavailable.add(thread);
        if (!_currentActivity(epoch)) return;
        notifyListeners();
        if (!_currentActivity(epoch)) return;
      }
      if (!change.connected && _moaBindings[thread] == change.binding) {
        _removeMoa(thread, keepTurn: !change.retired);
        if (!change.retired) _moaUnavailable.add(thread);
        if (!_currentActivity(epoch)) return;
        notifyListeners();
      }
    }
  }

  bool _onMoaEvent(
    ChatThread thread,
    ChatMessage? reply,
    ChatEvent event,
    String? profile,
  ) {
    if (event is! MoaUpdated) return false;
    final epoch = _activityEpoch;
    final source = transport;
    final binding = source is OwnedSessionTransport
        ? (source as OwnedSessionTransport).ownedSessionFor(
            thread.id,
            profile: profile,
          )
        : null;
    if (!_currentActivity(epoch) ||
        profile != _profile ||
        !_threads.contains(thread) ||
        reply == null ||
        !reply.isPending ||
        !thread.messages.contains(reply) ||
        !identical(_moaForeground[thread], reply) ||
        binding == null ||
        binding.profile != profile ||
        binding.runtimeId != event.runtimeId ||
        !identical(binding.connection, event.connection)) {
      _moaOutcome('stale', 0);
      return true;
    }
    final state = _moaStates.putIfAbsent(thread, MoaProgressState.new);
    if (_moaBindings[thread] != binding) {
      if (_moaBindings[thread] != null) _moaUnavailable.add(thread);
      _moaBindings[thread] = binding;
      state.adopt(binding);
      if (_moaUnavailable.contains(thread)) state.invalidateReferences();
    }
    final outcome = state.apply(
      event.update,
      attachment: binding,
      turn: reply,
      eventIdentity: event.identity,
    );
    _moaOutcome(outcome.name, state.cards.length);
    if (_currentActivity(epoch) &&
        _moaBindings[thread] == binding &&
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) ==
            binding) {
      notifyListeners();
    }
    return true;
  }

  void _moaOutcome(String outcome, int count) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'moa',
        'outcome': outcome,
        'count': count,
      });
    } on Object {
      /* Telemetry cannot change reference ownership. */
    }
  }

  final _todoPlans = <(String?, String), TodoPlanState>{};
  final _todoBindings = <(String?, String), OwnedSessionBinding>{};
  final _todoLive = <(String?, String), int>{};
  final _todoResumes =
      <(String?, String), (OwnedSessionBinding, Object, int)>{};

  TodoPlanState? todoPlanIn(ChatThread thread) {
    final owner = (_profile, thread.id), source = transport;
    final state = _todoPlans[owner], binding = _todoBindings[owner];
    if (!active ||
        !_threads.contains(thread) ||
        state == null ||
        binding == null ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final actual = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    return actual == binding && state.hasScope(_todoScope(binding))
        ? state
        : null;
  }

  TodoScope _todoScope(OwnedSessionBinding binding) => TodoScope(
    connection: binding.connection,
    runtimeId: binding.runtimeId,
    profile: binding.profile,
  );

  TodoPlanState _adoptTodo(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    final state = _todoPlans.putIfAbsent(owner, () {
      final created = TodoPlanState(events: events, breadcrumbs: breadcrumbs);
      created.addListener(notifyListeners);
      return created;
    });
    if (_todoBindings[owner] != binding) {
      _todoBindings[owner] = binding;
      _todoLive[owner] = 0;
      _todoResumes.remove(owner);
      state.adopt(_todoScope(binding));
    }
    return state;
  }

  void _removeTodo((String?, String) owner) {
    _todoPlans.remove(owner)?.dispose();
    _todoBindings.remove(owner);
    _todoLive.remove(owner);
    _todoResumes.remove(owner);
  }

  void _clearTodo() {
    for (final state in _todoPlans.values) {
      state.dispose();
    }
    _todoPlans.clear();
    _todoBindings.clear();
    _todoLive.clear();
    _todoResumes.clear();
  }

  void _onTodoOwnership(OwnedSessionChange change, int epoch) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_todoBindings[owner] == change.binding) {
        _removeTodo(owner);
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if (source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              change.threadId,
              profile: change.binding.profile,
            ) !=
            change.binding) {
      return;
    }
    final state = _adoptTodo(owner, change.binding);
    if (!_currentActivity(epoch) ||
        _profile != owner.$1 ||
        _todoPlans[owner] != state ||
        _todoBindings[owner] != change.binding ||
        (source as OwnedSessionTransport).ownedSessionFor(
              change.threadId,
              profile: change.binding.profile,
            ) !=
            change.binding) {
      return;
    }
    final token = change.resumeToken;
    if (change.resuming) {
      if (token != null) {
        _todoResumes[owner] = (change.binding, token, _todoLive[owner] ?? 0);
      }
      return;
    }
    final pending = _todoResumes[owner];
    if (pending != null && token != null) {
      if (pending.$1 != change.binding || !identical(pending.$2, token)) return;
      _todoResumes.remove(owner);
      if (pending.$3 != _todoLive[owner]) return;
    }
    state.resumed(_todoScope(change.binding), change.resumeSnapshot);
  }

  TodoPlanState? _syncTodo(ChatThread thread, String? profile) {
    final epoch = _activityEpoch;
    final source = transport;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final owner = (profile, thread.id);
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) {
      _removeTodo(owner);
      return null;
    }
    final state = _adoptTodo(owner, binding);
    if (!_currentActivity(epoch) ||
        _profile != profile ||
        !_threads.contains(thread) ||
        _todoPlans[owner] != state ||
        _todoBindings[owner] != binding ||
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) !=
            binding) {
      return null;
    }
    return state;
  }

  bool _onTodoEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! TodoUpdated) return false;
    final state = _syncTodo(thread, profile);
    final owner = (profile, thread.id),
        binding = _todoBindings[(profile, thread.id)];
    if (state == null ||
        _todoPlans[owner] != state ||
        binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    if (state.snapshot == null ||
        event.snapshot.revision > state.snapshot!.revision) {
      _todoLive[owner] = (_todoLive[owner] ?? 0) + 1;
    }
    state.updated(_todoScope(binding), event.snapshot);
    return true;
  }

  SessionUsageController? usageIn(ChatThread thread) {
    final controller = _usage[thread], binding = _ownedBindings[thread];
    if (!active ||
        controller == null ||
        binding == null ||
        binding.profile != _profile) {
      return null;
    }
    final source = transport;
    final actual = source is OwnedSessionTransport
        ? (source as OwnedSessionTransport).ownedSessionFor(
            thread.id,
            profile: _profile,
          )
        : null;
    if (actual != null && actual != binding) return null;
    return controller.hasScope(
          UsageScope(
            connection: binding.connection,
            sessionId: binding.runtimeId,
            profile: binding.profile,
          ),
        )
        ? controller
        : null;
  }

  final _reactions = <ChatThread, ReactionState>{};

  final _sideResults = <ChatThread, SideResultState>{};
  SideResultState? sideResultsIn(ChatThread thread) {
    final state = _sideResults[thread], binding = _ownedBindings[thread];
    final source = transport;
    if (!active ||
        !_threads.contains(thread) ||
        state == null ||
        binding == null ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final actual = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    return actual == binding && state.hasScope(_sideScope(binding))
        ? state
        : null;
  }

  final _processOutputs = <ChatThread, ProcessOutputState>{};
  ProcessOutputState? processOutputsIn(ChatThread thread) {
    final state = _processOutputs[thread], binding = _ownedBindings[thread];
    final source = transport;
    if (!active ||
        !_threads.contains(thread) ||
        state == null ||
        binding == null ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final actual = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: _profile,
    );
    return actual == binding && state.hasScope(binding) ? state : null;
  }

  final _connectorOperations =
      <(String?, String), ConnectorOperationController>{};
  final _connectorBindings = <(String?, String), OwnedSessionBinding>{};
  ConnectorOperationController? _connectionOperations;
  Object? _connectorConnection;
  StreamSubscription<GatewayConnectionEvent>? _connectorActivitySubscription;
  int _connectorActivityGeneration = 0;

  ConnectorOperationController? connectorOperationsIn(ChatThread thread) {
    final owner = (_profile, thread.id), source = transport;
    final controller = _connectorOperations[owner],
        binding = _connectorBindings[owner];
    return active &&
            _threads.contains(thread) &&
            source is OwnedSessionTransport &&
            binding != null &&
            controller != null &&
            controller.hasScope(binding) &&
            (source as OwnedSessionTransport).ownedSessionFor(
                  thread.id,
                  profile: _profile,
                ) ==
                binding
        ? controller
        : null;
  }

  ConnectorOperationController? get connectionOperations {
    final source = transport,
        connection = _connectorConnection,
        controller = _connectionOperations;
    return active &&
            source is GatewayConnectionTransport &&
            connection != null &&
            controller != null &&
            controller.hasScope(connection) &&
            (source as GatewayConnectionTransport).ownsGatewayConnection(
              connection,
            )
        ? controller
        : null;
  }

  void _removeConnector((String?, String) owner) {
    _connectorBindings.remove(owner);
    _connectorOperations.remove(owner)?.dispose();
  }

  void _clearConnectionOperations() {
    _connectionOperations?.dispose();
    _connectionOperations = null;
    _connectorConnection = null;
  }

  void _clearConnectors() {
    _connectorActivityGeneration++;
    unawaited(_connectorActivitySubscription?.cancel());
    _connectorActivitySubscription = null;
    for (final controller in _connectorOperations.values) {
      controller.dispose();
    }
    _connectorOperations.clear();
    _connectorBindings.clear();
    _clearConnectionOperations();
  }

  bool _currentConnector(
    (String?, String) owner,
    ConnectorOperationController controller,
    OwnedSessionBinding binding,
    int epoch,
  ) {
    final source = transport;
    return _currentActivity(epoch) &&
        _profile == owner.$1 &&
        identical(_connectorOperations[owner], controller) &&
        _connectorBindings[owner] == binding &&
        controller.hasScope(binding) &&
        source is OwnedSessionTransport &&
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) ==
            binding;
  }

  ConnectorOperationController _adoptConnector(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    final existing = _connectorOperations[owner];
    if (existing != null &&
        _connectorBindings[owner] == binding &&
        existing.hasScope(binding)) {
      return existing;
    }
    _removeConnector(owner);
    final source = transport, epoch = _activityEpoch;
    final authorized =
        (binding.profile?.isNotEmpty ?? false) &&
        source is ConnectorOperationTransport;
    late final ConnectorOperationController controller;
    bool current() =>
        _currentConnector(owner, controller, binding, epoch) &&
        _threads.any((thread) => thread.id == owner.$2);
    controller = ConnectorOperationController(
      now: _clock,
      events: events,
      breadcrumbs: breadcrumbs,
      openBrowser: (uri) async {
        if (!authorized || !current()) return false;
        return connectorBrowser?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
    _connectorBindings[owner] = binding;
    _connectorOperations[owner] = controller;
    controller.bind(
      binding,
      profile: binding.profile,
      actionsAllowed: authorized,
      respond: authorized
          ? (params) async {
              final operation = controller.operations
                  .where(
                    (operation) =>
                        operation.opId == params['op_id'] &&
                        operation.owner.type == 'session' &&
                        operation.owner.sessionId == binding.runtimeId,
                  )
                  .firstOrNull;
              bool allowed() =>
                  current() &&
                  operation != null &&
                  controller.pendingResponseIsCurrent(
                    operation,
                    attachment: binding,
                  );
              if (!allowed()) throw const ConnectorResponseCanceled();
              try {
                return await (source as ConnectorOperationTransport)
                    .respondToConnectorOperation(
                      binding,
                      params,
                      authorize: allowed,
                    );
              } on GatewayConnectionClosed {
                if (!allowed()) throw const ConnectorResponseCanceled();
                rethrow;
              }
            }
          : null,
    );
    controller.addListener(notifyListeners);
    return controller;
  }

  void _onConnectorOwnership(OwnedSessionChange change, int epoch) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_connectorBindings[owner] == change.binding) {
        _removeConnector(owner);
        notifyListeners();
      }
      if (identical(_connectorConnection, change.binding.connection)) {
        _clearConnectionOperations();
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if (source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) !=
            change.binding) {
      return;
    }
    final controller = _adoptConnector(owner, change.binding);
    if (!_currentConnector(owner, controller, change.binding, epoch)) return;
    final pending = change.resumeSnapshot?['pending_connection'];
    if (pending is ConnectorOperationSnapshot &&
        pending.owner.type == 'session' &&
        pending.owner.sessionId == change.binding.runtimeId) {
      controller.accept(pending, attachment: change.binding);
    }
  }

  ConnectorOperationController? _syncConnector(
    ChatThread thread,
    String? profile,
  ) {
    final source = transport, epoch = _activityEpoch;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) return null;
    final owner = (profile, thread.id),
        controller = _adoptConnector((profile, thread.id), binding);
    return _currentConnector(owner, controller, binding, epoch)
        ? controller
        : null;
  }

  bool _onConnectorOperation(
    ChatThread thread,
    ChatEvent event,
    String? profile,
  ) {
    if (event is! ConnectorOperationReceived) return false;
    final controller = _syncConnector(thread, profile),
        binding = _connectorBindings[(profile, thread.id)];
    if (controller == null ||
        binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection) ||
        event.operation.owner.type != 'session' ||
        event.operation.owner.sessionId != binding.runtimeId) {
      return true;
    }
    controller.accept(event.operation, attachment: binding);
    return true;
  }

  void _listenConnectionActivity() {
    final source = transport;
    if (!active ||
        source is! GatewayConnectionTransport ||
        _connectorActivitySubscription != null) {
      return;
    }
    final epoch = _activityEpoch, generation = _connectorActivityGeneration;
    bool current() =>
        _currentActivity(epoch) && generation == _connectorActivityGeneration;
    _connectorActivitySubscription = (source as GatewayConnectionTransport)
        .connectionEvents
        .listen(
          (change) {
            if (!current()) return;
            if (!change.connected) {
              if (identical(_connectorConnection, change.connection)) {
                _clearConnectionOperations();
                notifyListeners();
              }
              return;
            }
            final frame = change.event;
            if (frame == null ||
                frame.type != 'connection.update' ||
                frame.sessionId.isNotEmpty) {
              return;
            }
            final operation = ConnectorOperationSnapshot.fromUpdate(
              frame.payload,
            );
            if (operation == null ||
                operation.owner.type != 'account' ||
                !(source as GatewayConnectionTransport).ownsGatewayConnection(
                  change.connection,
                )) {
              return;
            }
            if (!identical(_connectorConnection, change.connection)) {
              _clearConnectionOperations();
              _connectorConnection = change.connection;
              final controller = ConnectorOperationController(
                now: _clock,
                events: events,
                breadcrumbs: breadcrumbs,
              )..bind(change.connection, actionsAllowed: false);
              controller.addListener(notifyListeners);
              _connectionOperations = controller;
            }
            final controller = _connectionOperations;
            if (!current() ||
                controller == null ||
                !controller.hasScope(change.connection) ||
                !(source as GatewayConnectionTransport).ownsGatewayConnection(
                  change.connection,
                )) {
              return;
            }
            controller.accept(operation, attachment: change.connection);
          },
          onError: (Object _) {
            if (current()) {
              _clearConnectionOperations();
              notifyListeners();
            }
          },
          onDone: () {
            if (!current()) return;
            _connectorActivitySubscription = null;
            _clearConnectionOperations();
            notifyListeners();
          },
        );
  }

  void _listenOwnedSessions() {
    _listenConnectionActivity();
    final source = transport;
    if (!active ||
        source is! OwnedSessionTransport ||
        _ownedSubscription != null) {
      return;
    }
    final epoch = _activityEpoch;
    _ownedSubscription = (source as OwnedSessionTransport).ownedSessions.listen(
      (change) {
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onConnectorOwnership(change, epoch);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onBillingOwnership(change);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        _onTodoOwnership(change, epoch);
        _onMoaOwnership(change, epoch);
        if (!_currentActivity(epoch) || change.binding.profile != _profile) {
          return;
        }
        if (!change.connected) {
          for (final entry in _ownedBindings.entries.toList()) {
            if (entry.value != change.binding) continue;
            _reactions.remove(entry.key)?.dispose();
            _sideResults.remove(entry.key)?.dispose();
            _processOutputs.remove(entry.key)?.clear();
            if (change.retired) {
              _ownedBindings.remove(entry.key);
              _usage.remove(entry.key)?.dispose();
              notifyListeners();
            } else {
              _usage[entry.key]?.disconnected();
            }
          }
          return;
        }
        final thread = _threads
            .where((thread) => thread.id == change.threadId)
            .firstOrNull;
        if (thread != null) _syncOwnedSession(thread, _profile);
      },
      onError: (Object _) {
        if (_currentActivity(epoch)) _clearOwnedState();
      },
      onDone: () {
        if (!_currentActivity(epoch)) return;
        _ownedSubscription = null;
        _clearOwnedState();
      },
    );
  }

  void _clearOwnedState() {
    _clearBilling();
    _clearReactions();
    _clearTodo();
    _clearConnectors();
    _clearMoa();
    for (final controller in _usage.values) {
      controller.dispose();
    }
    _usage.clear();
    for (final state in _sideResults.values) {
      state.dispose();
    }
    _sideResults.clear();
    for (final state in _processOutputs.values) {
      state.clear();
    }
    _processOutputs.clear();
    _ownedBindings.clear();
    if (!disposed) notifyListeners();
  }

  OwnedSessionBinding? _syncOwnedSession(ChatThread thread, String? profile) {
    final epoch = _activityEpoch;
    final source = transport;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) return null;
    bool current() =>
        _currentActivity(epoch) &&
        _profile == profile &&
        _threads.contains(thread) &&
        _ownedBindings[thread] == binding &&
        (source as OwnedSessionTransport).ownedSessionFor(
              thread.id,
              profile: profile,
            ) ==
            binding;
    final previous = _ownedBindings[thread];
    final controller = _usage.putIfAbsent(thread, () {
      final created = SessionUsageController(
        telemetry: usageTelemetry,
        breadcrumbs: breadcrumbs,
      );
      created.addListener(notifyListeners);
      return created;
    });
    if (previous != binding) {
      _ownedBindings[thread] = binding;
      if (!current()) return null;
      _sideResults[thread]?.adopt(_sideScope(binding));
      if (!current()) return null;
      _processOutputs[thread]?.adopt(binding);
      controller.bind(
        UsageScope(
          connection: binding.connection,
          sessionId: binding.runtimeId,
          profile: binding.profile,
        ),
        (_, _) {
          if (!active ||
              _profile != profile ||
              !_threads.contains(thread) ||
              (source as OwnedSessionTransport).ownedSessionFor(
                    thread.id,
                    profile: profile,
                  ) !=
                  binding) {
            throw StateError('Usage attachment retired');
          }
          return (source as OwnedSessionTransport).readOwnedSession(
            binding,
            'session.usage',
          );
        },
      );
      if (!current()) return null;
      if (previous != null &&
          !identical(previous.connection, binding.connection) &&
          identical(selectedThread, thread)) {
        unawaited(controller.reconnected());
      }
    }
    if (!current()) return null;
    _sideResults[thread]?.adopt(_sideScope(binding));
    if (!current()) return null;
    _processOutputs[thread]?.adopt(binding);
    if (!current()) return null;
    _syncReactions(thread, binding);
    return current() ? binding : null;
  }

  SideResultScope _sideScope(OwnedSessionBinding binding) => SideResultScope(
    connection: binding.connection,
    sessionId: binding.runtimeId,
    profile: binding.profile,
  );

  bool _onSideResult(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! SideResultReceived) return false;
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final state = _sideResults.putIfAbsent(thread, () {
      final created = SideResultState(events: events, breadcrumbs: breadcrumbs)
        ..adopt(_sideScope(binding));
      created.addListener(notifyListeners);
      return created;
    });
    state.received(_sideScope(binding), event.result);
    return true;
  }

  void processOutputDetailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'process_output',
    'action': 'details',
  });

  bool _onProcessOutput(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! ProcessOutputReceived) return false;
    final binding = _syncOwnedSession(thread, profile);
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final state = _processOutputs.putIfAbsent(
      thread,
      () => ProcessOutputState()..adopt(binding),
    );
    final outcome = state.apply(event.update, attachment: binding);
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'process_output',
        'outcome': outcome.name,
        'count': 1,
      });
    } on Object {
      return true;
    }
    return true;
  }

  bool _onUsageEvent(ChatThread thread, ChatEvent event, String? profile) {
    final tick = event is SessionUsageUpdated;
    if (!tick && event is! ReplyCompleted) return false;
    final binding = _syncOwnedSession(thread, profile);
    final controller = _usage[thread];
    if (controller == null || binding == null) return tick;
    final runtime = tick
        ? event.runtimeId
        : (event as ReplyCompleted).usageRuntimeId;
    final connection = tick
        ? event.connection
        : (event as ReplyCompleted).usageConnection;
    if (runtime != binding.runtimeId ||
        !identical(connection, binding.connection)) {
      return tick;
    }
    final scope = UsageScope(
      connection: binding.connection,
      sessionId: binding.runtimeId,
      profile: binding.profile,
    );
    if (event is SessionUsageUpdated) {
      if (event.finalSnapshot) {
        controller.complete(
          scope,
          event.malformed ? const <String, Object?>{} : event.snapshot,
        );
      } else {
        controller.tick(scope, event.snapshot);
      }
    } else if (event is ReplyCompleted) {
      controller.complete(
        scope,
        event.usageMalformed ? const <String, Object?>{} : event.usage,
      );
    }
    return tick;
  }

  final _warnings = <ChatThread, ChatWarningState>{};
  final _warningGenerations = <ChatThread, int>{};
  int _nextWarningGeneration = 0;

  int _warningGeneration(ChatThread thread) =>
      _warningGenerations.putIfAbsent(thread, () => ++_nextWarningGeneration);

  void _discardWarnings(ChatThread thread) {
    _warnings.remove(thread)?.clear();
    _warningGenerations[thread] = ++_nextWarningGeneration;
  }

  final _sessionStates = <ChatThread, ChatSessionState>{};
  final _sessionActionGenerations = <ChatThread, int>{};
  int _nextSessionActionGeneration = 0;

  int _sessionActionGeneration(ChatThread thread) => _sessionActionGenerations
      .putIfAbsent(thread, () => ++_nextSessionActionGeneration);

  bool _sessionActionCurrent(ChatThread thread, int generation) =>
      _sessionActionGenerations[thread] == generation &&
      _threads.contains(thread);

  void _invalidateSessionActions(ChatThread thread) {
    _sessionActionGenerations[thread] = ++_nextSessionActionGeneration;
    _undoing.remove(thread);
    _turnProblems.remove(thread);
  }

  final _reclaimedQueueReview = <ChatThread>{};

  ChatSessionState? sessionStateIn(ChatThread thread) => _sessionStates[thread];

  void sessionDetailsOpened() => breadcrumbs('chat.visibility_action', {
    'feature': 'session_state',
    'action': 'details',
  });

  void reopenSession(ChatThread thread) {
    if (!active || !_threads.contains(thread)) return;
    breadcrumbs('chat.visibility_action', {
      'feature': 'session_state',
      'action': 'reopen',
    });
    _invalidateSessionActions(thread);
    _sessionStates.remove(thread);
    select(thread.id);
  }

  bool _onSessionEvent(ChatThread thread, ChatEvent event, String? profile) {
    final runtime = switch (event) {
      SessionControlUpdated(:final runtimeId) => runtimeId,
      SessionControlUnavailable(:final runtimeId) => runtimeId,
      SessionWaitUpdated(:final runtimeId) => runtimeId,
      SessionReclaimed(:final runtimeId) => runtimeId,
      SessionResumeProgress(:final runtimeId) => runtimeId,
      _ => null,
    };
    if (runtime == null) return false;
    if (!active || _profile != profile || !_threads.contains(thread)) {
      return true;
    }
    if (event is SessionReclaimed &&
        thread.remote &&
        thread.id != event.storedSessionId) {
      return true;
    }
    final state = _sessionStates.putIfAbsent(thread, ChatSessionState.new);
    if (state.reclaimedReason != null && state.runtimeId == runtime) {
      return true;
    }
    if (state.runtimeId != null && state.runtimeId != runtime) {
      _invalidateSessionActions(thread);
    }
    state.adopt(runtime);
    var outcome = 'applied';
    switch (event) {
      case SessionControlUpdated(:final control):
        state.control = control;
      case SessionControlUnavailable():
        outcome = 'unavailable';
      case SessionWaitUpdated(:final kind, :final text):
        if (text.isEmpty) {
          state.waits.remove(kind);
        } else {
          state.waits[kind] = text;
          if (state.waits.length > 16) {
            state.waits.remove(state.waits.keys.first);
          }
        }
      case SessionResumeProgress(:final progress):
        state.resume = progress;
      case SessionReclaimed(:final reason):
        _invalidateSessionActions(thread);
        state.reclaimedReason = reason;
        _removeMoa(thread);
        _finishQueueBinding(thread, false);
        state.waits.clear();
        _settleTimers.remove(thread)?.cancel();
        if (_queues[thread]?.isNotEmpty ?? false) {
          _reclaimedQueueReview.add(thread);
        }
        _active.remove(thread.id);
        _discardWarnings(thread);
        for (final reply in thread.messages) {
          if (reply.role != ChatRole.assistant) continue;
          _updateReply(thread, reply, () {
            expireInputRequests(reply);
            if (reply.isPending) {
              applyReplyEvent(
                reply,
                ReplyCompleted(reply.content, stopped: true),
              );
            }
          });
        }
        outcome = 'reclaimed';
      default:
        break;
    }
    notifyListeners();
    try {
      events('gateway.visibility_outcome', {
        'feature': 'session_state',
        'outcome': outcome,
      });
    } on Object {
      return true;
    }
    return true;
  }

  List<AgentNotice> noticesIn(ChatThread thread) =>
      List.unmodifiable(_warnings[thread]?.notices ?? const <AgentNotice>[]);

  void dismissNotice(ChatThread thread, AgentNotice notice) {
    _warnings[thread]?.dismiss(notice);
    _warningAction('dismiss');
  }

  void warningDetailsOpened() => _warningAction('details');

  void _warningAction(String action) {
    try {
      breadcrumbs('chat.visibility_action', {
        'feature': 'warnings',
        'action': action,
      });
    } on Object catch (_) {}
  }

  ChatWarningState _warningState(ChatThread thread, String runtimeId) {
    final state = _warnings.putIfAbsent(
      thread,
      () => ChatWarningState(changed: notifyListeners),
    );
    if (state.runtimeId != null && state.runtimeId != runtimeId) {
      _warningGenerations[thread] = ++_nextWarningGeneration;
    }
    state.adopt(runtimeId);
    return state;
  }

  bool _onWarning(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! NoticeShown &&
        event is! NoticeCleared &&
        event is! ToolRiskFlagged &&
        event is! WarningScopeDiscarded) {
      return false;
    }
    if (_profile != profile) return true;
    switch (event) {
      case WarningScopeDiscarded():
        _discardWarnings(thread);
        notifyListeners();
      case NoticeShown(:final notice, :final runtimeId):
        _warningState(thread, runtimeId).show(notice);
      case NoticeCleared(:final key, :final runtimeId):
        _warningState(thread, runtimeId).withdraw(key);
      case ToolRiskFlagged(:final toolId, :final risk, :final runtimeId):
        final state = _warningState(thread, runtimeId);
        final generation = _warningGeneration(thread);
        state.risks[toolId] = risk;
        if (state.risks.length > 128) {
          state.risks.remove(state.risks.keys.first);
        }
        for (final message in thread.messages) {
          if (message.toolCalls.any(
            (call) =>
                call.id == toolId &&
                call.runtimeId == runtimeId &&
                call.warningGeneration == generation,
          )) {
            _attachRisk(thread, message, toolId, runtimeId);
            break;
          }
        }
      default:
        break;
    }
    try {
      events('gateway.visibility_outcome', {
        'feature': 'warnings',
        'outcome': event is WarningScopeDiscarded ? 'discarded' : 'applied',
      });
    } on Object catch (_) {}
    return true;
  }

  void _attachRisk(
    ChatThread thread,
    ChatMessage message,
    String toolId,
    String runtimeId,
  ) {
    final state = _warnings[thread];
    if (state == null || state.runtimeId != runtimeId) return;
    final generation = _warningGeneration(thread);
    final risk = state.risks[toolId];
    if (risk == null) return;
    _updateReply(
      thread,
      message,
      () => message.toolCalls = [
        for (final call in message.toolCalls)
          call.id == toolId &&
                  call.runtimeId == runtimeId &&
                  call.warningGeneration == generation
              ? call.copyWith(outputRisk: risk)
              : call,
      ],
    );
  }

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

  /// The models the profile offers; null while loading or when they could
  /// not be read.
  ModelOptions? _modelOptions;
  ModelOptions? get modelOptions => _modelOptions;

  /// The model picked before there is a thread to hold it.
  ModelChoice? _newChatModel;

  /// The model picked for the selected thread, or for a new one.
  ModelChoice? get modelChoice {
    final selected = selectedThread;
    return selected == null ? _newChatModel : selected.modelChoice;
  }

  void chooseModel(ModelChoice choice) {
    if (!active) return;
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

  Future<void> _loadThreads(
    String? profile, {
    bool Function()? valid,
    bool preserveSelection = false,
  }) async {
    if (!active) return;
    var previousSelection = _selectedId;
    final previousProfile = _profile;
    final originalLocal = preserveSelection
        ? _threads.where((thread) => !thread.remote).toList()
        : const <ChatThread>[];
    final interruptedLocalReplies = {
      for (final thread in originalLocal)
        if (!_sending.containsKey(thread))
          thread: thread.messages.where((message) => message.isPending).toSet(),
    };
    final generation = ++_loadGeneration;
    _loadingThreads = true;
    _threadsFailed = false;
    notifyListeners();
    try {
      if (!active || generation != _loadGeneration) return;
      profile ??= await _activeProfile();
      if (!active || generation != _loadGeneration) return;
      _failedListProfile = profile;
      final first = await repository!.loadThreadPage(profile: profile);
      if (!active || generation != _loadGeneration) return;
      final firstIds = {for (final thread in first.threads) thread.id};
      var launched = await _attention.takeLaunchTarget();
      if (!active || generation != _loadGeneration) return;
      if (launched != null && onLaunchNotification != null) {
        onLaunchNotification!(launched);
        launched = null;
      }
      if (launched != null && launched.isJob) {
        onOpenJob?.call(launched);
        launched = null;
      }
      if (launched != null && launched.prompt != null) {
        onOpenNewChat?.call(launched);
        launched = null;
      }
      if (!active || generation != _loadGeneration) return;
      if (valid?.call() == false) {
        _loadingThreads = false;
        notifyListeners();
        return;
      }
      final recoveredQueues = <({ChatThread source, ChatThread recovered})>[];
      final recoveredSources = <ChatThread>{};
      while (preserveSelection) {
        final candidates = _queues.keys
            .where(
              (thread) =>
                  thread.remote &&
                  !(profile != previousProfile &&
                      (_queues[thread]?.any(
                            (prompt) => prompt.durable != null,
                          ) ??
                          false)) &&
                  !recoveredSources.contains(thread) &&
                  (profile != previousProfile ||
                      !_sending.containsKey(thread) &&
                          !firstIds.contains(thread.id)),
            )
            .toList();
        if (candidates.isEmpty) break;
        recoveredSources.addAll(candidates);
        final recovered = await Future.wait([
          for (final thread in candidates)
            () async {
              final recovered = profile == previousProfile
                  ? await _recoverQueuedThread(thread, profile)
                  : _queuedDraft(thread, newId: true);
              return (source: thread, recovered: recovered);
            }(),
        ]);
        if (!active || generation != _loadGeneration) return;
        recoveredQueues.addAll(recovered);
      }
      if (!active || generation != _loadGeneration) return;
      if (valid?.call() == false) {
        _loadingThreads = false;
        notifyListeners();
        return;
      }
      final local = preserveSelection
          ? _threads.where((thread) => !thread.remote).toList()
          : const <ChatThread>[];
      final live = preserveSelection && profile == previousProfile
          ? _threads
                .where(
                  (thread) => thread.remote && _sending.containsKey(thread),
                )
                .toList()
          : const <ChatThread>[];
      final liveIds = {for (final thread in live) thread.id};
      final currentRecoveries = recoveredQueues
          .where(
            (entry) =>
                _queues.containsKey(entry.source) &&
                (profile != previousProfile ||
                    !_sending.containsKey(entry.source)),
          )
          .toList();
      final retainedQueues = preserveSelection
          ? {
              for (final entry in _queues.entries)
                if (profile == previousProfile ||
                    !entry.value.any((prompt) => prompt.durable != null))
                  entry.key.id: entry.value,
            }
          : <String, List<QueuedPrompt>>{};
      if (preserveSelection) previousSelection = _selectedId;
      for (final (:source, :recovered) in currentRecoveries) {
        if (source.id == recovered.id) continue;
        retainedQueues[recovered.id] = retainedQueues.remove(source.id)!;
        if (previousSelection == source.id) previousSelection = recovered.id;
      }
      final held = _pendingTap;
      final fetchHeld = held != null && _pendingFetch;
      final launch = held ?? launched;
      final heldPrompt = _pendingTapPrompt;
      final requestedOpening = _requestedOpening;
      _pendingTap = null;
      _pendingFetch = false;
      _pendingTapPrompt = null;
      final threads = housekeeping!.begin(
        ThreadPage(
          threads: [
            ...live,
            for (final thread in first.threads)
              if (!liveIds.contains(thread.id)) thread,
            for (final entry in currentRecoveries) entry.recovered,
          ],
          nextOffset: first.nextOffset,
          hasMore: first.hasMore,
        ),
      );
      // Another profile can hold a different session under the same id.
      _stopFollowing();
      _active.clear();
      for (final controller in _chatControllers.values) {
        controller.dispose();
      }
      _chatControllers.clear();
      final switched = profile != _profile;
      if (switched) {
        _modelOptions = null;
        _newChatModel = null;
        search?.clear();
      }
      _carryReplies();
      for (final entry in interruptedLocalReplies.entries) {
        entry.key.messages.removeWhere(
          (message) => message.isPending && entry.value.contains(message),
        );
      }
      _profile = profile;
      breadcrumbs('chat.threads.loaded', {
        'switched': switched,
        'count': threads.length,
      });
      unawaited(_loadModelOptions(profile, generation));
      _threads = [...local, ...threads];
      _unloaded
        ..clear()
        ..addAll(
          threads
              .where((t) => t.remote && !liveIds.contains(t.id))
              .map((t) => t.id),
        );
      _olderRows.clear();
      _loadedQueues.clear();
      _restoredQueues.clear();
      _queueEpoch++;
      _queueRestoring.clear();
      _queueTurnReady.clear();
      _queueSettled.clear();
      _queues
        ..clear()
        ..addAll({
          for (final thread in _threads) thread: ?retainedQueues[thread.id],
        });
      _restoredQueues.addAll(
        _queues.keys.where(
          (thread) => _queues[thread]!.any((prompt) => prompt.durable != null),
        ),
      );
      _suspendedQueues
        ..clear()
        ..addAll(_queues.keys);
      _cancelSettleWaits();
      _bound
        ..clear()
        ..addAll(threads.where((thread) => thread.remote));
      _loadingThreads = false;
      _touched.clear();
      _selectedId =
          _isOnProfile(launch, profile) &&
              threads.any((t) => t.id == launch!.threadId)
          ? launch!.threadId
          : preserveSelection && _threads.any((t) => t.id == previousSelection)
          ? previousSelection
          : null;
      if (preserveSelection &&
          previousSelection != null &&
          _selectedId == null &&
          profile == previousProfile) {
        _opening = _openMissing(
          NotificationTarget(threadId: previousSelection, profile: profile),
        );
      }
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      _reportSurface(SurfaceTrigger.threads);
      if (!active || generation != _loadGeneration) return;
      if (launch != null) {
        // A held tap already put Chat in front when it arrived.
        if (held == null) onShowChat?.call();
        if (!active || generation != _loadGeneration) return;
        if (_selectedId != launch.threadId) {
          if (fetchHeld) {
            _opening = _openMissing(
              launch,
              prompt: heldPrompt,
            ).whenComplete(() => _finishOpening(requestedOpening));
          } else {
            _failOpen();
            _finishOpening(requestedOpening);
          }
        } else if (heldPrompt != null) {
          onDraft?.call(heldPrompt);
          _finishOpening(requestedOpening);
        } else {
          _finishOpening(requestedOpening);
        }
      }
      if (!active || generation != _loadGeneration) return;
      if (_selectedId != null) {
        final selected = _threads.firstWhere((t) => t.id == _selectedId);
        unawaited(
          (selected.remote ? _loadMessages(selected.id) : Future<void>.value())
              .then((_) {
                if (active &&
                    generation == _loadGeneration &&
                    _profile == profile &&
                    _selectedId == selected.id &&
                    _threads.contains(selected)) {
                  _pickUp(selected);
                }
              }),
        );
      }
      unawaited(refreshActive());
    } on Object {
      if (!active || generation != _loadGeneration) return;
      _loadingThreads = false;
      _threadsFailed = true;
      breadcrumbs('chat.threads.failed');
      notifyListeners();
    }
  }

  Future<ChatThread> _recoverQueuedThread(
    ChatThread thread,
    String? profile,
  ) async {
    final generation = _loadGeneration, epoch = _activityEpoch;
    bool current() =>
        _currentActivity(epoch) &&
        generation == _loadGeneration &&
        _profile == profile;
    try {
      final fresh = await repository!.loadThread(thread.id, profile: profile);
      if (fresh != null) {
        if (current()) setThreadListAvailability(thread, available: true);
        return fresh;
      }
    } on Object {
      // An unreadable target cannot vouch for sending into its old session.
    }
    if (_queues[thread]?.any((prompt) => prompt.durable != null) ?? false) {
      if (current()) setThreadListAvailability(thread, available: false);
      return thread;
    }
    return _queuedDraft(thread);
  }

  ChatThread _queuedDraft(ChatThread thread, {bool newId = false}) =>
      ChatThread(
        id: newId ? '${thread.id}-draft-${_sentMessages++}' : thread.id,
        title: thread.title,
        named: thread.named,
        updatedAt: thread.updatedAt,
        modelChoice: thread.modelChoice,
        messages: [
          for (final message in thread.messages)
            if (!message.isPending) message,
        ],
      );

  /// The sticky active profile, or null when the server has none to report:
  /// no repository, or a server without the profiles route (404). Any other
  /// failure throws, so the caller does not list or send unscoped.
  Future<String?> _activeProfile() async {
    try {
      return (await profiles?.loadActive())?.active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _loadModelOptions(String? profile, int generation) async {
    final models = this.models;
    if (models == null) return;
    final options = await models
        .load(profile: profile)
        .then<ModelOptions?>((o) => o, onError: (Object _) => null);
    if (!active || generation != _loadGeneration) return;
    _modelOptions = options;
    notifyListeners();
  }

  /// The first page of a thread's messages that is being read, by thread id.
  final _loadingMessages = <String, Future<void>>{};

  Future<void> _loadMessages(String id) {
    if (!active || !_unloaded.remove(id)) return Future.value();
    final load = _readFirstPage(id);
    _loadingMessages[id] = load;
    return load.whenComplete(() {
      if (identical(_loadingMessages[id], load)) _loadingMessages.remove(id);
    });
  }

  Future<void> _readFirstPage(String id) async {
    final generation = _loadGeneration;
    try {
      final page = await repository!.loadMessagePage(id, profile: _profile);
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      thread.messages.addAll(page.messages);
      _reactionHistory(thread);
      if (page.hasMore) _olderRows[id] = page.rows;
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      if (generation != _loadGeneration) return;
      _unloaded.add(id);
      if (!active) return;
      report('Could not load this chat');
    }
  }

  /// Every message of [thread]: what is loaded, plus the pages the dashboard
  /// holds beyond it. A thread whose messages were never loaded is read
  /// whole; an open one is not read again.
  Future<List<ChatMessage>> _history(
    ChatThread thread, {
    bool Function()? cancelled,
  }) async {
    final epoch = _activityEpoch;
    if (!active) throw StateError("Chat activity suspended");
    final repository = this.repository;
    if (repository == null || !_bound.contains(thread)) return thread.messages;
    await _loadingMessages[thread.id];
    if (!_currentActivity(epoch)) throw StateError("Chat activity suspended");
    final loaded = !_unloaded.contains(thread.id);
    final newest = loaded ? thread.messages : const <ChatMessage>[];
    final held = {for (final m in newest) m.id};
    final pages = [newest];
    final profile = _profile;
    int? offset = loaded ? _olderRows[thread.id] : 0;
    while (offset != null) {
      if (!_currentActivity(epoch) || (cancelled?.call() ?? false)) {
        throw StateError('history cancelled');
      }
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
        offset: offset,
      );
      if (!_currentActivity(epoch)) throw StateError("Chat activity suspended");
      pages.add([
        for (final m in page.messages)
          if (held.add(m.id)) m,
      ]);
      offset = page.hasMore && page.rows > 0 ? offset + page.rows : null;
    }
    return [for (final page in pages.reversed) ...page];
  }

  Future<void> loadOlder(String id) async {
    if (!active) return;
    final offset = _olderRows[id];
    if (offset == null) return;
    final generation = _loadGeneration;
    try {
      final page = await repository!.loadMessagePage(
        id,
        profile: _profile,
        offset: offset,
      );
      if (!active || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      final held = {for (final m in thread.messages) m.id};
      final older = [
        for (final m in page.messages)
          if (!held.contains(m.id)) m,
      ];
      thread.messages.insertAll(0, older);
      _reactionHistory(thread);
      if (page.hasMore && page.rows > 0) {
        _olderRows[id] = offset + page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
      if (!active || generation != _loadGeneration) return;
      if (older.isEmpty) return;
      await controllerFor(thread).insertAllMessages(
        [for (final m in older) ...chatMessageToFlyer(m)],
        index: 0,
        animated: false,
      );
    } on Object {
      if (active && generation == _loadGeneration) {
        report('Could not load earlier messages');
      }
    }
  }

  /// Reads [id] again from the dashboard after it changed elsewhere (another
  /// window): its title and pin, and its messages once they were loaded. A
  /// chat that is gone leaves the list. Nothing is read while a reply streams
  /// into it, which would replace the reply in progress.
  Future<void> refreshThread(String id) async {
    if (!active) return;
    final repository = this.repository;
    final thread = _threads.where((t) => t.id == id).firstOrNull;
    if (repository == null ||
        thread == null ||
        !thread.remote ||
        thread.isReplying) {
      return;
    }
    final generation = _loadGeneration;
    bool stale() =>
        !active || generation != _loadGeneration || thread.isReplying;
    try {
      final fresh = await repository.loadThread(id, profile: _profile);
      if (stale()) return;
      if (fresh == null) {
        housekeeping?.forget(thread);
        return notifyListeners();
      }
      final unchanged = fresh.updatedAt == thread.updatedAt;
      housekeeping?.adopt(thread, fresh);
      notifyListeners();
      if (stale()) return;
      if (unchanged || _unloaded.contains(id)) return;
      final page = await repository.loadMessagePage(id, profile: _profile);
      if (stale()) return;
      final failed = _failedTurn(thread, page.messages);
      thread.messages
        ..clear()
        ..addAll(page.messages)
        ..addAll(failed);
      _reactionHistory(thread);
      if (page.hasMore) {
        _olderRows[id] = page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
      if (stale()) return;
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      // Keeps what it shows; the next refresh or open reads it again.
    }
  }

  /// The turn of [thread] that ended in a failed reply and is still its last,
  /// to show after the [history] a read brought: the prompt, unless the history
  /// already holds it, and the failed reply with its error and Retry. It is
  /// dropped once an assistant message follows the prompt in the history, and
  /// a later send leaves it behind the thread's last message anyway.
  ///
  /// A prompt repeats earlier ones, so it is found by its place among the user
  /// messages of the same text: with n of them before it here, the history
  /// holds it only when it has more than n, and its occurrence is the next.
  List<ChatMessage> _failedTurn(ChatThread thread, List<ChatMessage> history) {
    final messages = thread.messages;
    final reply = messages.lastOrNull;
    if (reply == null ||
        reply.role != ChatRole.assistant ||
        reply.status != MessageStatus.error) {
      return const [];
    }
    final promptAt = messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (promptAt < 0) return [reply];
    final prompt = messages[promptAt];
    bool same(ChatMessage m) =>
        m.role == ChatRole.user && m.content == prompt.content;
    final before = messages.take(promptAt).where(same).length;
    final occurrences = [
      for (var i = 0; i < history.length; i++)
        if (same(history[i])) i,
    ];
    if (occurrences.length <= before) return [prompt, reply];
    final answered = history
        .skip(occurrences[before] + 1)
        .any((m) => m.role == ChatRole.assistant);
    return answered ? const [] : [reply];
  }

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
      _selectedId = selected.id;
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

  Future<void> Function()? _prepareQueueDeletion(ChatThread thread) {
    if (queueStore == null) return null;
    final scopes = <String, QueueScope>{};
    void remember(QueueScope scope) =>
        scopes[jsonEncode(scope.toJson())] = scope;
    final current = queueScope?.call(thread, _profile);
    if (current != null) remember(current);
    for (final prompt in _queues[thread] ?? const <QueuedPrompt>[]) {
      if (prompt.scope case final scope?) remember(scope);
    }
    for (final (scope, _)
        in _hiddenQueueOrder[thread] ?? const <(QueueScope, String)>[]) {
      remember(scope);
    }
    if (scopes.isEmpty) return null;
    return () async {
      final store = await _protectedQueueStore();
      for (final scope in scopes.values) {
        await store.deleteConversation(scope);
      }
    };
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
  /// dropping ones whose turn ended.
  Future<void> refreshActive() async {
    final transport = this.transport;
    if (transport == null || !active) return;
    final generation = _loadGeneration;
    final refresh = ++_activeRefresh;
    final Map<String, String> statuses;
    try {
      statuses = await transport.activeStatuses();
    } on Object {
      return;
    }
    if (!active || generation != _loadGeneration || refresh != _activeRefresh) {
      return;
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
    if (!changed) return;
    _active
      ..clear()
      ..addAll(working);
    notifyListeners();
  }

  /// Loaded messages are keyed `<session>-<row id>`, so a count of the
  /// thread's messages would collide with them.
  String _newMessageId(ChatThread thread) =>
      '${thread.id}-local-${_sentMessages++}';

  Future<List<SlashCommand>> slashCommands() async {
    if (!active) return const [];
    final epoch = _activityEpoch;
    try {
      final commands = await transport?.slashCommands(
        threadId: selectedThread?.remote == true ? selectedThread!.id : null,
        profile: _profile,
      );
      return _currentActivity(epoch) ? commands ?? const [] : const [];
    } on Object {
      if (!_currentActivity(epoch)) return const [];
      rethrow;
    }
  }

  /// Runs a gateway command without putting it through prompt.submit or the
  /// reply queue. Display-only command output stays in this visit's chat.
  Future<bool> runSlashCommand(String command) async {
    if (_sessionStates[selectedThread]?.reclaimedReason != null) {
      report('Reopen this session before running another command.');
      return false;
    }
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return false;
    final bot = selectedThread?.botContext;
    if (bot != null &&
        RegExp(r'^/(?:title|rename)(?:\s|$)').hasMatch(command.trim())) {
      report(
        'Bot Chat keeps its canonical title. Edit the bot name in the roster.',
      );
      return false;
    }
    final compacting =
        bot != null && {'/new', '/reset'}.contains(command.trim());
    if (compacting) command = '/compress';
    if (command == '/new') {
      newThread();
      return true;
    }
    final transport = this.transport;
    if (transport == null) return false;
    final selected = selectedThread;
    if (selected != null && !selected.remote && selected.isReplying) {
      report('Wait for this chat to open before running a command.');
      return false;
    }
    final wasRemote = selected?.remote == true;
    final profile = _profile;
    try {
      final result = await transport.runSlashCommand(
        threadId: wasRemote ? selected!.id : null,
        profile: profile,
        command: command,
      );
      if (!_currentActivity(epoch)) return false;
      if (_profile != profile) return true;
      final thread =
          selected ??
          ChatThread(
            id: result.threadId,
            title: command,
            updatedAt: DateTime.now(),
            remote: true,
            modelChoice: _newChatModel,
          );
      if (selected == null) {
        _threads.insert(0, thread);
        _selectedId ??= thread.id;
      } else if (!selected.remote) {
        _bindThread(selected, result.threadId);
      }
      _bound.add(thread);
      if (compacting && botChats != null) {
        final BotModeChat canonical;
        try {
          canonical = await botChats!.open(bot.bot);
        } on Object {
          if (_currentActivity(epoch)) {
            report('Bot Chat was compacted. Reopen the bot to continue.');
          }
          return true;
        }
        if (!_currentActivity(epoch) || _profile != profile) return true;
        if (canonical.storedId != thread.id) {
          _retargetBoundThread(thread, canonical.storedId);
        }
        thread.botContext = bot.withStoredId(canonical.storedId);
        await _refreshAfterSlash(thread, profile);
      }
      if (result.prefill != null && wasRemote) {
        await _refreshAfterSlash(thread, profile);
      }
      if (!_currentActivity(epoch)) return false;
      void append(ChatRole role, String content) {
        if (content.isEmpty) return;
        final message = ChatMessage(
          id: _newMessageId(thread),
          role: role,
          content: content,
          createdAt: DateTime.now(),
        );
        thread.messages.add(message);
        for (final flyer in chatMessageToFlyer(message)) {
          controllerFor(thread).insertMessage(flyer);
        }
      }

      append(ChatRole.user, command);
      append(ChatRole.assistant, result.output);
      thread.updatedAt = DateTime.now();
      notifyListeners();
      if (!_currentActivity(epoch)) return false;
      if (result.prefill case final draft?) onPrefill?.call(draft);
      if (!_currentActivity(epoch)) return false;
      if (result.prompt case final prompt? when prompt.isNotEmpty) {
        await _submitTo(
          thread,
          prompt,
          const [],
          displayText: result.display ?? command,
        );
      }
      return true;
    } on Object catch (error) {
      if (_currentActivity(epoch)) report('Could not run $command: $error');
      return false;
    }
  }

  Future<void> _refreshAfterSlash(ChatThread thread, String? profile) async {
    final epoch = _activityEpoch;
    final repository = this.repository;
    if (repository == null) return;
    if (!_currentActivity(epoch)) return;
    await _loadingMessages[thread.id];
    if (!_currentActivity(epoch)) return;
    try {
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
      );
      if (!_currentActivity(epoch) ||
          _profile != profile ||
          !_threads.contains(thread)) {
        return;
      }
      thread.messages
        ..clear()
        ..addAll(page.messages);
      _unloaded.remove(thread.id);
      if (page.hasMore) {
        _olderRows[thread.id] = page.rows;
      } else {
        _olderRows.remove(thread.id);
      }
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
      if (!_currentActivity(epoch)) return;
      notifyListeners();
    } on Object {
      if (_currentActivity(epoch)) {
        report('Command ran, but this chat could not be refreshed.');
      }
    }
  }

  /// The last prompt of [thread], with or without text.
  ChatMessage? _lastPrompt(ChatThread thread) => thread.messages.reversed
      .where((m) => m.role == ChatRole.user)
      .firstOrNull;

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? lastPromptText(ChatThread thread) {
    final message = _lastPrompt(thread);
    if (message == null) return null;
    final text = message.submittedText ?? message.content;
    return text.isEmpty ? null : text;
  }

  /// Whether the last prompt of [thread] can be taken back on the server:
  /// edited, or sent again in place of its turn.
  bool canEditLastPrompt(ChatThread thread) {
    if (!active || _sessionStates[thread]?.reclaimedReason != null) {
      return false;
    }
    final prompt = lastPromptText(thread);
    return transport != null &&
        _bound.contains(thread) &&
        !_undoing.containsKey(thread) &&
        !thread.isReplying &&
        !_queues.containsKey(thread) &&
        prompt != null &&
        !prompt.startsWith('/');
  }

  /// Sends the text of the last prompt again. The server drops the turn it
  /// replaces first, so the model does not see that reply again. A command, a
  /// prompt that had files (they are not sent again) and a server that cannot
  /// undo get a new turn instead.
  Future<void> retry(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation)) {
      return;
    }
    final prompt = lastPromptText(thread);
    if (prompt == null || _undoing.containsKey(thread)) return;
    if (prompt.startsWith('/')) {
      unawaited(runSlashCommand(prompt));
      return;
    }
    if (canEditLastPrompt(thread) && _lastPrompt(thread)!.attachments.isEmpty) {
      try {
        await _undoLastTurn(thread, TurnAction.retry);
      } on Object catch (error) {
        if (_currentActivity(epoch) &&
            _sessionActionCurrent(thread, generation)) {
          _failTurnAction(thread, error, 'try again');
        }
        return;
      }
      if (!_currentActivity(epoch) ||
          !_sessionActionCurrent(thread, generation)) {
        return;
      }
    }
    await _submitTo(thread, prompt, const []);
  }

  /// Takes the last prompt of [thread] back on the server and puts its text
  /// in the composer. Its files are not put back.
  Future<void> editLastPrompt(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    final prompt = lastPromptText(thread);
    if (prompt == null || !canEditLastPrompt(thread)) return;
    final bool undone;
    try {
      undone = await _undoLastTurn(thread, TurnAction.edit);
    } on Object catch (error) {
      if (_currentActivity(epoch) &&
          _sessionActionCurrent(thread, generation)) {
        _failTurnAction(thread, error, 'edit the prompt');
      }
      return;
    }
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    if (!undone) {
      report("This Hermes server can't edit prompts. Update Hermes to edit.");
      return;
    }
    onPrefill?.call(prompt);
  }

  /// Says under the last reply why taking back its turn failed. The error
  /// itself is meant for developers, so only its kind goes to the crumb.
  void _failTurnAction(ChatThread thread, Object error, String action) {
    final rejected = error is GatewayRpcException;
    breadcrumbs('chat.undo.failed', {
      'cause': rejected ? 'rejected' : 'unreachable',
    });
    _turnProblems[thread] = rejected
        ? "Hermes couldn't $action."
        : "Couldn't reach Hermes to $action. Check your connection.";
    notifyListeners();
  }

  /// The retry or edit running on the last turn of [thread], or why the last
  /// one failed.
  TurnActionStatus turnActionStatus(ChatThread thread) => TurnActionStatus(
    running: _undoing[thread],
    problem: _turnProblems[thread],
  );

  /// The threads whose last turn is being dropped, and for what, so a second
  /// tap does not drop the turn before it too.
  final _undoing = <ChatThread, TurnAction>{};

  /// Why the last retry or edit of a thread failed, until the next one or the
  /// next prompt.
  final _turnProblems = <ChatThread, String>{};

  /// Drops the last turn of [thread] on the server and then here. False when
  /// the server cannot undo.
  Future<bool> _undoLastTurn(ChatThread thread, TurnAction action) async {
    final epoch = _activityEpoch;
    final generation = _sessionActionGeneration(thread);
    _undoing[thread] = action;
    _turnProblems.remove(thread);
    notifyListeners();
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    final int? removed;
    try {
      removed = await transport!.undoLastTurn(
        thread.id,
        profile: _profile,
        retry: action == TurnAction.retry,
      );
    } finally {
      if (_currentActivity(epoch) &&
          _sessionActionCurrent(thread, generation)) {
        _undoing.remove(thread);
        notifyListeners();
      }
    }
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    if (removed == null) return false;
    final start = thread.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (start < 0) return true;
    thread.messages.removeRange(start, thread.messages.length);
    await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    if (!_currentActivity(epoch) ||
        !_sessionActionCurrent(thread, generation) ||
        _sessionStates[thread]?.reclaimedReason != null) {
      return true;
    }
    notifyListeners();
    return true;
  }

  Future<bool> _restoreQueue(ChatThread thread) {
    if (!active) return Future.value(false);
    if (queueStore == null || !thread.remote) {
      return Future.value(true);
    }
    if (_loadedQueues.contains(thread)) return Future.value(true);
    final held = _queueRestoring[thread];
    if (held != null) return held;
    late final Future<bool> restoring;
    restoring = _readProtectedQueue(thread).whenComplete(() {
      if (identical(_queueRestoring[thread], restoring)) {
        _queueRestoring.remove(thread);
      }
      if (active) notifyListeners();
    });
    _queueRestoring[thread] = restoring;
    return restoring;
  }

  Future<bool> _readProtectedQueue(ChatThread thread) async {
    final profile = _profile;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final generation = _loadGeneration;
    final scope = queueScope?.call(thread, profile);
    if (profile == null ||
        profile.trim().isEmpty ||
        scope == null ||
        !queuesVisible) {
      return false;
    }
    try {
      final store = await _protectedQueueStore();
      final order = _hiddenQueueOrder[thread] ?? const <(QueueScope, String)>[];
      final scopes = <String, QueueScope>{jsonEncode(scope.toJson()): scope};
      for (final (held, _) in order) {
        if (_sameQueueOwner(held, scope)) {
          scopes[jsonEncode(held.toJson())] = held;
        }
      }
      final prompts = <QueuedPrompt>[];
      var corrupt = 0;
      for (final target in scopes.values) {
        final loaded = await store.load(target);
        corrupt += loaded.corruptRecords;
        for (final record in loaded.records) {
          if (_knownQueueAcceptance.contains((
            jsonEncode(target.toJson()),
            record.id,
          ))) {
            continue;
          }
          prompts.add(
            QueuedPrompt(
              record.text,
              const [],
              displayText: record.displayText,
              durable: record,
              scope: target,
            ),
          );
        }
      }
      if (!active ||
          !queuesVisible ||
          epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          generation != _loadGeneration ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(queueScope?.call(thread, profile), scope)) {
        return false;
      }
      if (order.isNotEmpty) {
        int position(QueuedPrompt prompt) => order.indexWhere(
          (item) =>
              item.$2 == prompt.durable?.id &&
              jsonEncode(item.$1.toJson()) ==
                  jsonEncode(prompt.scope!.toJson()),
        );
        prompts.sort((a, b) {
          final left = position(a), right = position(b);
          if (left >= 0 && right >= 0) return left.compareTo(right);
          if (left >= 0) return -1;
          if (right >= 0) return 1;
          return a.durable!.sequence.compareTo(b.durable!.sequence);
        });
      }
      _loadedQueues.add(thread);
      _hiddenQueueOrder.remove(thread);
      _settleTimers.remove(thread)?.cancel();
      if (prompts.isNotEmpty) {
        _queues[thread] = prompts;
        _restoredQueues.add(thread);
      } else if (!_enqueueing.contains(thread) &&
          (_queues[thread]?.isEmpty ?? true)) {
        _restoredQueues.remove(thread);
      }
      if (corrupt > 0) _queueErrors[thread] = 'Some recovered prompts could not be read. Valid entries were kept.';
      try {
        events('chat.queue.recovery', {
          'outcome': corrupt > 0
              ? 'corrupt'
              : prompts.isEmpty
              ? 'empty'
              : 'recovered',
          'count': prompts.length,
        });
      } on Object {
        // Telemetry must not alter the review barrier.
      }
      notifyListeners();
      return true;
    } on Object {
      if (_currentActivity(activityEpoch) &&
          epoch == _queueEpoch &&
          generation == _loadGeneration) {
        _queueErrors[thread] =
            'Protected queue storage is unavailable. Your draft was kept.';
        try {
          events('chat.queue.recovery', {'outcome': 'unavailable', 'count': 0});
        } on Object {
          // Telemetry must not alter the review barrier.
        }
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> _submitAfterQueueRestore(
    ChatThread thread,
    String text,
    List<SharedFile> files,
    String? displayText,
  ) async {
    if (!_queuePreparing.add(thread)) return false;
    final profile = _profile;
    final activityEpoch = _activityEpoch;
    final generation = _loadGeneration;
    final scope = queueScope?.call(thread, profile);
    try {
      if (scope == null ||
          !await _restoreQueue(thread) ||
          !_currentActivity(activityEpoch) ||
          generation != _loadGeneration ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(queueScope?.call(thread, profile), scope)) {
        return false;
      }
      _queuePreparing.remove(thread);
      return await Future.sync(
        () => _submitTo(thread, text, files, displayText: displayText),
      );
    } finally {
      _queuePreparing.remove(thread);
    }
  }

  /// The prompts waiting in [thread] for its reply to end.
  List<QueuedPrompt> queuedIn(ChatThread thread) =>
      List.unmodifiable(_queues[thread] ?? const <QueuedPrompt>[]);

  /// Whether [thread] holds queued prompts that no reply will send, because
  /// the last one was stopped or failed.
  bool queuePaused(ChatThread thread) =>
      !thread.isReplying && (_queues[thread]?.isNotEmpty ?? false);

  FutureOr<void> removeQueued(ChatThread thread, QueuedPrompt prompt) {
    if (!active) return Future<void>.value();
    if (prompt.submitting || _queueDispatching.contains(thread)) {
      return Future<void>.value();
    }
    if (prompt.durable != null) return _removeProtectedQueue(thread, prompt);
    final queue = _queues[thread];
    if (queue == null || !queue.remove(prompt)) return Future<void>.value();
    if (queue.isEmpty) _queues.remove(thread);
    notifyListeners();
    return Future<void>.value();
  }

  Future<void> _removeProtectedQueue(
    ChatThread thread,
    QueuedPrompt prompt,
  ) async {
    if (!_queueRemoving.add(thread)) return;
    try {
      final scope = prompt.scope;
      if (scope == null) throw const QueueStorageException('unavailable');
      await (await _protectedQueueStore()).discard(scope, prompt.durable!.id);
      _queues[thread]?.removeWhere(
        (entry) =>
            entry.durable?.id == prompt.durable!.id &&
            jsonEncode(entry.scope?.toJson()) == jsonEncode(scope.toJson()),
      );
      if (_queues[thread]?.isEmpty ?? false) {
        _queues.remove(thread);
        _restoredQueues.remove(thread);
      }
      breadcrumbs('chat.queue.removed', {
        'count': 1,
        'state': prompt.uncertain ? 'uncertain' : 'unsent',
      });
      _queueRemoving.remove(thread);
      if (!_restoredQueues.contains(thread) &&
          !thread.isReplying &&
          _queueTurnReady.contains(thread) &&
          _holdOf(thread) == _Hold.none) {
        _queueSettled.contains(thread)
            ? _drainQueue(thread)
            : _awaitSettle(thread);
      }
    } on Object {
      _queueErrors[thread] =
          'Could not remove this queued prompt. Its protected record was kept.';
    } finally {
      _queueRemoving.remove(thread);
      if (active) notifyListeners();
    }
  }

  /// Explicitly resumes queued work after review; unsent prompts stay queued.
  void sendQueued(ChatThread thread) {
    if (!active || _queueUnavailable.contains(thread)) return;
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (_reclaimedQueueReview.remove(thread)) {
      breadcrumbs('chat.visibility_action', {
        'feature': 'session_state',
        'action': 'review_queue',
      });
    }
    if (_restoredQueues.contains(thread)) {
      final prompt = _queues[thread]?.firstOrNull;
      if (prompt == null ||
          prompt.uncertain ||
          queueBusy(thread) ||
          thread.isReplying) {
        return;
      }
      breadcrumbs('chat.queue.send_requested', {'count': 1, 'state': 'unsent'});
      queueReviewed(prompt);
      unawaited(_dispatchProtected(thread, prompt));
    } else {
      _drainQueue(thread);
    }
  }

  void _drainQueue(ChatThread thread) {
    if (!active || _queueUnavailable.contains(thread)) return;
    if (_sessionStates[thread]?.reclaimedReason != null ||
        _reclaimedQueueReview.contains(thread)) {
      return;
    }
    _settleTimers.remove(thread)?.cancel();
    final queue = _queues[thread];
    if (thread.isReplying ||
        queue == null ||
        queue.isEmpty ||
        _queueDispatching.contains(thread)) {
      return;
    }
    if (_restoredQueues.contains(thread) || _queueRemoving.contains(thread)) {
      return;
    }
    final first = queue.first;
    if (first.durable != null) {
      if (!first.uncertain) unawaited(_dispatchProtected(thread, first));
      return;
    }
    _suspendedQueues.remove(thread);
    final next = queue.removeAt(0);
    if (queue.isEmpty) _queues.remove(thread);
    if (!_send(
      thread,
      next.text,
      next.files,
      displayText: next.displayText,
      queued: true,
    )) {
      (_queues[thread] ??= []).insert(0, next);
    }
    notifyListeners();
  }

  bool _queueContextCurrent(
    ChatThread thread,
    _ProtectedQueuedSend send,
    String? profile,
    int generation,
  ) =>
      _currentActivity(send.activityEpoch) &&
      _sessionActionCurrent(thread, send.sessionGeneration) &&
      queuesVisible &&
      send.epoch == _queueEpoch &&
      profile == _profile &&
      generation == _loadGeneration &&
      _threads.contains(thread) &&
      _sameQueueOwner(queueScope?.call(thread, profile), send.scope) &&
      send.scope.conversationId == thread.id &&
      _sessionStates[thread]?.reclaimedReason == null;
  QueuedPrompt? _entryFor(ChatThread thread, _ProtectedQueuedSend send) =>
      _queues[thread]
          ?.where(
            (prompt) =>
                prompt.durable?.id == send.id &&
                jsonEncode(prompt.scope?.toJson()) ==
                    jsonEncode(send.scope.toJson()),
          )
          .firstOrNull;
  void _replaceQueueState(
    ChatThread thread,
    _ProtectedQueuedSend send,
    QueueRecordState state, {
    bool submitting = false,
  }) {
    final prompt = _entryFor(thread, send);
    final queue = _queues[thread];
    if (prompt == null || queue == null) return;
    queue[queue.indexOf(prompt)] = QueuedPrompt(
      prompt.text,
      prompt.files,
      displayText: prompt.displayText,
      durable: prompt.durable!.withState(state),
      scope: prompt.scope,
      submitting: submitting,
    );
    if (active) notifyListeners();
  }

  Future<void> _restoreNotSubmitted(
    ChatThread thread,
    _ProtectedQueuedSend send,
  ) async {
    send.provenNotSubmitted = true;
    try {
      await send.store.restoreUnsentAfterPreSubmitFailure(
        send.scope,
        send.id,
        claim: send.claim,
      );
      send.restored = true;
      _replaceQueueState(thread, send, QueueRecordState.queued);
    } on Object {
      _replaceQueueState(thread, send, QueueRecordState.submissionStarted);
      _restoredQueues.add(thread);
      _queueErrors[thread] = 'Protected queue state could not be updated. Inspect the conversation before sending again.';
    }
  }

  void _acceptedQueue(ChatThread thread, _ProtectedQueuedSend send) {
    send.accepted = true;
    _knownQueueAcceptance.add((jsonEncode(send.scope.toJson()), send.id));
    final prompt = _entryFor(thread, send);
    if (prompt != null) _queues[thread]?.remove(prompt);
    if (_queues[thread]?.isEmpty ?? false) {
      _queues.remove(thread);
      _restoredQueues.remove(thread);
    }
    if (active) notifyListeners();
    unawaited(() async {
      try {
        await send.store.setState(
          send.scope,
          send.id,
          QueueRecordState.accepted,
        );
      } on Object {
        if (active) {
          report(
            'Hermes accepted this prompt, but local cleanup could not finish. Do not send it again.',
          );
        }
      }
    }());
  }

  Future<void> _dispatchProtected(
    ChatThread thread,
    QueuedPrompt prompt,
  ) async {
    if (!_queueDispatching.add(thread)) return;
    final scope = prompt.scope;
    final profile = _profile;
    final generation = _loadGeneration;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final sessionGeneration = _sessionActionGeneration(thread);
    try {
      if (scope == null ||
          prompt.uncertain ||
          !queueAvailable(thread) ||
          transport is! QueueSubmissionTransport) {
        throw const QueueStorageException('unavailable');
      }
      final store = await _protectedQueueStore();
      final send = _ProtectedQueuedSend(
        prompt,
        scope,
        store,
        epoch,
        activityEpoch,
        sessionGeneration,
      );
      final attachments = <ChatAttachment>[];
      final outgoing = <OutgoingAttachment>[];
      for (final file in prompt.durable!.attachments) {
        final bytes = Uint8List.fromList(
          await store.readAttachment(scope, send.id, file.blobId),
        );
        final kind = file.isImage ? AttachmentKind.image : AttachmentKind.file;
        attachments.add(
          ChatAttachment(
            name: file.name,
            kind: kind,
            size: file.size,
            bytes: bytes,
          ),
        );
        outgoing.add(
          OutgoingAttachment(
            name: file.name,
            kind: kind,
            mimeType: file.mimeType,
            read: () async => bytes,
          ),
        );
      }
      if (!queueAvailable(thread) ||
          !_queueContextCurrent(thread, send, profile, generation) ||
          _entryFor(thread, send) == null) {
        return;
      }
      _queueErrors.remove(thread);
      _replaceQueueState(
        thread,
        send,
        QueueRecordState.queued,
        submitting: true,
      );
      _send(
        thread,
        prompt.text,
        const [],
        displayText: prompt.displayText,
        queued: true,
        readyAttachments: attachments,
        readyOutgoing: outgoing,
        protectedSend: send,
      );
    } on Object {
      _queueErrors[thread] =
          'Could not send this queued prompt. Its protected record was kept.';
      if (active) notifyListeners();
    } finally {
      _queueDispatching.remove(thread);
      if (active) notifyListeners();
    }
  }

  /// After a reply ended normally, holds the queued prompts of [thread] until
  /// the session reports it settled. Two seconds without that report (an older
  /// Hermes, or a missed frame) send them anyway.
  void _awaitSettle(ChatThread thread) {
    if (!active || _suspendedQueues.contains(thread)) return;
    if (_restoredQueues.contains(thread) ||
        thread.isReplying ||
        (_queues[thread]?.isEmpty ?? true)) {
      return;
    }
    if (_settleTimers.containsKey(thread)) return;
    _settleTimers[thread] = Timer(
      const Duration(seconds: 2),
      () => _settle(thread),
    );
  }

  /// Ends the settle wait of [thread], if one is running, and sends its
  /// queue. A thread whose queue is paused by a stop or a failure has no wait,
  /// so a late report does not send it.
  void _settle(ChatThread thread) {
    final timer = _settleTimers.remove(thread);
    if (timer == null) return;
    timer.cancel();
    _drainQueue(thread);
  }

  void _cancelSettleWaits() {
    for (final timer in _settleTimers.values) {
      timer.cancel();
    }
    _settleTimers.clear();
    _refetch.clear();
  }

  /// Sends [typed] and [files] in the selected thread, or in a new one, and
  /// streams the reply into it. While the thread replies, or holds a paused
  /// queue, the prompt joins its queue instead. Returns false when it was
  /// neither sent nor queued, after telling the user why.
  FutureOr<bool> submit(String typed, List<SharedFile> files) =>
      active ? _submitTo(selectedThread, typed, files) : false;

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

  Future<bool> _enqueueProtected(
    ChatThread thread,
    String text,
    List<SharedFile> files,
    String? displayText,
  ) async {
    if (!_enqueueing.add(thread)) return false;
    final profile = _profile;
    final epoch = _queueEpoch;
    final activityEpoch = _activityEpoch;
    final initialScope = queueScope?.call(thread, profile);
    final wasReplying = thread.isReplying;
    try {
      if (profile == null ||
          profile.trim().isEmpty ||
          initialScope == null ||
          !await _waitForQueueBinding(thread, initialScope)) {
        throw const QueueStorageException('identity_unavailable');
      }
      final sessionGeneration = _sessionActionGeneration(thread);
      final scope = queueScope?.call(thread, profile);
      if (!active ||
          epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          !_sessionActionCurrent(thread, sessionGeneration) ||
          _sessionStates[thread]?.reclaimedReason != null ||
          profile != _profile ||
          !_threads.contains(thread) ||
          !_sameQueueOwner(scope, initialScope)) {
        throw const QueueStorageException('identity_unavailable');
      }
      if (scope == null || !await _restoreQueue(thread)) {
        throw const QueueStorageException('identity_unavailable');
      }
      final record = await (await _protectedQueueStore()).commit(
        scope,
        text,
        displayText: displayText,
        files: [
          for (final file in files)
            QueueAttachmentInput(
              path: file.path,
              name: file.name,
              mimeType: file.mimeType,
              isImage: file.isImage,
            ),
        ],
      );
      if (epoch != _queueEpoch ||
          !_currentActivity(activityEpoch) ||
          !_sessionActionCurrent(thread, sessionGeneration) ||
          _sessionStates[thread]?.reclaimedReason != null ||
          !_sameQueueOwner(queueScope?.call(thread, profile), initialScope)) {
        try {
          await (await _protectedQueueStore()).discard(scope, record.id);
        } on Object {
          // Revoked scopes remain protected until scoped cleanup succeeds.
        }
        throw const QueueStorageException('identity_unavailable');
      }
      _enqueueing.remove(thread);
      if (active && profile == _profile && _threads.contains(thread)) {
        (_queues[thread] ??= []).add(
          QueuedPrompt(
            text,
            files,
            displayText: displayText,
            durable: record,
            scope: scope,
          ),
        );
        if (_restoredQueues.contains(thread) ||
            thread.isReplying ||
            _settleTimers.containsKey(thread)) {
          notifyListeners();
        } else if (wasReplying) {
          if (_queueTurnReady.contains(thread) &&
              _holdOf(thread) == _Hold.none) {
            _queueSettled.contains(thread)
                ? _drainQueue(thread)
                : _awaitSettle(thread);
          }
          notifyListeners();
        } else {
          _drainQueue(thread);
        }
      }
      return true;
    } on Object {
      if (active) {
        report('Could not queue this prompt. Your draft was kept.');
      }
      return false;
    } finally {
      _enqueueing.remove(thread);
      if (_queues[thread]?.isEmpty ?? true) _restoredQueues.remove(thread);
    }
  }

  bool _send(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
    bool queued = false,
    List<ChatAttachment>? readyAttachments,
    List<OutgoingAttachment>? readyOutgoing,
    _ProtectedQueuedSend? protectedSend,
  }) {
    if (protectedSend != null &&
        (selected == null || !_bound.contains(selected))) {
      return false;
    }
    if (_sessionStates[selected]?.reclaimedReason != null) return false;
    if (!active) return false;
    final epoch = _activityEpoch;
    final sizes = readyAttachments == null ? _sizesOrExplain(files) : <int>[];
    if (sizes == null) return false;
    final attachments = <ChatAttachment>[...?readyAttachments];
    final outgoing = <OutgoingAttachment>[...?readyOutgoing];
    for (final (i, file) in files.indexed) {
      final kind = file.isImage ? AttachmentKind.image : AttachmentKind.file;
      attachments.add(
        ChatAttachment(
          name: file.name,
          kind: kind,
          path: file.path,
          size: sizes[i],
        ),
      );
      outgoing.add(
        OutgoingAttachment(
          name: file.name,
          kind: kind,
          mimeType: file.mimeType,
          read: File(file.path).readAsBytes,
        ),
      );
    }

    final label = typed.isEmpty
        ? (readyAttachments?.firstOrNull?.name ?? files.first.name)
        : displayText ?? typed;
    final thread =
        selected ??
        ChatThread(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: label,
          updatedAt: DateTime.now(),
          modelChoice: _newChatModel,
        );
    if (selected == null) {
      _threads.insert(0, thread);
      _selectedId = thread.id;
    }
    // A chat that has a name keeps it, even when its messages are not loaded
    // or a retry or an edit emptied them; only a chat with none gets a title
    // made from the prompt, which is not a name.
    if (protectedSend == null && thread.messages.isEmpty && !thread.named) {
      thread
        ..title = label.length > 48 ? '${label.substring(0, 48)}…' : label
        ..named = false;
    }

    final threadId = _bound.contains(thread) ? thread.id : null;
    final userMessage = ChatMessage(
      id: _newMessageId(thread),
      role: ChatRole.user,
      content: displayText ?? typed,
      submittedText: displayText == null ? null : typed,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    if (protectedSend == null) {
      thread.messages.add(userMessage);
      for (final flyer in chatMessageToFlyer(userMessage)) {
        controllerFor(thread).insertMessage(flyer);
      }
    }
    // A reply of its own: no stop asked before it is about it, and the answer
    // to one is no longer about this thread's current reply.
    _holds.remove(thread);
    _interrupts.remove(thread);
    _generations.update(thread, (n) => n + 1, ifAbsent: () => 1);
    final placeholder = _addPlaceholder(thread);
    thread.updatedAt = DateTime.now();
    notifyListeners();
    if (!_currentActivity(epoch)) return false;
    final transport = this.transport;
    if (transport == null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!_currentActivity(epoch)) return;
        _updateReply(thread, placeholder, () {
          placeholder.status = MessageStatus.sent;
          placeholder.content = buildMockReply(label);
        });
        _drainQueue(thread);
      });
    } else {
      _streamReply(
        transport,
        thread,
        placeholder,
        typed,
        outgoing,
        threadId,
        queued: queued,
        submittedUser: userMessage,
        protectedSend: protectedSend,
        deferredUser: protectedSend == null ? null : userMessage,
      );
      if (!_currentActivity(epoch)) return false;
      unawaited(_attention.askForPermission());
    }
    return true;
  }

  /// Appends the assistant message a reply that is about to stream fills in.
  ChatMessage _addPlaceholder(ChatThread thread) {
    _queueTurnReady.remove(thread);
    _queueSettled.remove(thread);
    // A new turn starts: a completion that comes now is its, not the settled
    // reply's before it.
    _settledReply(thread)?.settledWithoutCompletion = false;
    // The queue waited for the session to settle after the turn before. This
    // one decides when it may go on.
    _settleTimers.remove(thread)?.cancel();
    return _insertReply(thread);
  }

  /// Adds a thinking assistant message to [thread], at the end or, with
  /// [before], in front of that message.
  ChatMessage _insertReply(ChatThread thread, {ChatMessage? before}) {
    final reply = ChatMessage(
      id: _newMessageId(thread),
      role: ChatRole.assistant,
      content: '',
      createdAt: before?.createdAt ?? DateTime.now(),
      status: MessageStatus.thinking,
    );
    final at = before == null ? -1 : thread.messages.indexOf(before);
    if (at < 0) {
      thread.messages.add(reply);
    } else {
      thread.messages.insert(at, reply);
    }
    final chat = controllerFor(thread);
    final slot = at < 0
        ? -1
        : chat.messages.indexWhere(
            (m) => m.id == chatMessageToFlyer(before!).firstOrNull?.id,
          );
    for (final (i, flyer) in chatMessageToFlyer(reply).indexed) {
      chat.insertMessage(flyer, index: slot < 0 ? null : slot + i);
    }
    return reply;
  }

  /// The size of each of [files], or null after telling the user which one
  /// cannot be sent. The composer keeps its text and attachments then.
  List<int>? _sizesOrExplain(List<SharedFile> files) {
    final sizes = <int>[];
    for (final file in files) {
      final int size;
      try {
        size = File(file.path).lengthSync();
      } on FileSystemException {
        report(attachmentFailedMessage(file.name, kAttachmentUnreadable));
        return null;
      }
      if (size > kMaxAttachmentBytes) {
        report(attachmentTooLargeMessage(file.name));
        return null;
      }
      sizes.add(size);
    }
    return sizes;
  }

  void _streamReply(
    ChatTransport transport,
    ChatThread thread,
    ChatMessage reply,
    String text,
    List<OutgoingAttachment> attachments,
    String? threadId, {
    bool queued = false,
    required ChatMessage submittedUser,
    _ProtectedQueuedSend? protectedSend,
    ChatMessage? deferredUser,
  }) {
    _beginMoaTurn(thread, reply);
    final epoch = _activityEpoch;
    final queueGeneration = _loadGeneration;
    late final StreamSubscription<ChatEvent> subscription;
    final profile = _profile;
    // A new turn: what a run announced of an earlier one says nothing of it.
    unawaited(runningReplies?.takeAnnounced(profile, thread.id));
    _rememberedSince.remove((profile, thread.id));
    var failed = false;
    var stopped = false;
    var folded = false;
    var settled = false;
    final own = _OwnTurn();
    String outcome(Object? error) {
      if (error != null || reply.isPending && !folded) return 'failed';
      if (folded) return 'folded';
      if (stopped) return 'stopped';
      return failed || reply.status == MessageStatus.error
          ? 'failed'
          : 'completed';
    }

    void end([Object? error]) {
      if (!_currentActivity(epoch)) return;
      _finishMoaTurn(thread, reply);
      if (!_bound.contains(thread)) _finishQueueBinding(thread, false);
      if (protectedSend != null && !protectedSend.accepted) {
        if (!protectedSend.restored && protectedSend.started) {
          _replaceQueueState(
            thread,
            protectedSend,
            QueueRecordState.submissionStarted,
          );
          _restoredQueues.add(thread);
        } else if (!protectedSend.provenNotSubmitted) {
          _replaceQueueState(thread, protectedSend, QueueRecordState.queued);
        }
      }
      _replies.remove(subscription);
      if (error != null || (!folded && reply.isPending)) {
        _discardWarnings(thread);
      }
      _sending.update(thread, (n) => n - 1);
      if (_sending[thread] == 0) _sending.remove(thread);
      breadcrumbs('chat.reply.ended', {'outcome': outcome(error)});
      _closeOwnTurn(
        thread,
        own,
        profile,
        failed: error != null,
        announceFailure: !reply.isPending,
      );
      if (!_currentActivity(epoch)) return;
      if (folded) {
        // The prompt went into the turn already running, whose events follow
        // on the thread's follow-ups.
        if (error == null) {
          _followUps(transport, thread, profile);
          if (!_currentActivity(epoch)) return;
          // A stop of the running turn in flight decides when the queue goes
          // on: its answer, or the end of that turn.
          if (_holdOf(thread) == _Hold.none) _awaitSettle(thread);
          unawaited(refreshActive());
        } else {
          _turnEnded(thread, halted: true);
          // No notification: the prompt's reply was folded away, so none is
          // pending to announce.
          _announce(
            thread,
            const ReplyCompleted('', failed: true),
            profile,
            notify: false,
          );
          notifyListeners();
        }
      } else if (reply.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, reply, () => failReply(reply, error));
        if (!_currentActivity(epoch)) return;
        _announce(thread, const ReplyCompleted('', failed: true), profile);
        // A send that gave up asks for the thread to be read again: what
        // Hermes ran meanwhile is in its history. The read keeps this failed
        // turn after it (see [refreshThread]).
        _refetchIfIdle(thread);
      } else if (error == null) {
        // The watch is parked whatever ended the reply, so the follow-ups
        // listen to it. Only a reply that ended well drains the queue; after a
        // failure or a stop it stays paused for the user.
        final halted = failed || stopped || reply.status == MessageStatus.error;
        final drain = _turnEnded(
          thread,
          halted: halted,
          idleOnly: reply.settledWithoutCompletion,
        );
        _followUps(transport, thread, profile);
        if (!_currentActivity(epoch)) return;
        if (drain) {
          if (settled) {
            _drainQueue(thread);
          } else {
            _awaitSettle(thread);
          }
        }
        _refetchIfIdle(thread);
        unawaited(refreshActive());
        if (!drain) notifyListeners();
      } else {
        // The queue is left paused; the screen shows it.
        _turnEnded(thread, halted: true);
        notifyListeners();
      }
    }

    _sending.update(thread, (n) => n + 1, ifAbsent: () => 1);
    liveActivities?.begin(thread, profile: profile);
    _announcedTurns.add(thread);
    _watchSource?.begin(
      thread,
      title: _watchTitle(thread),
      threadId: _watchThreadId(thread, profile),
    );
    if (!_currentActivity(epoch)) return;
    breadcrumbs('chat.reply.started', {
      'queued': queued,
      'attachments': attachments.length,
    });
    final Stream<ChatEvent> stream;
    if (protectedSend == null) {
      stream = transport.send(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: thread.modelChoice,
        queued: queued,
      );
    } else {
      stream = (transport as QueueSubmissionTransport).sendQueued(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: thread.modelChoice,
        queueDispatchAllowed: () =>
            queueAvailable(thread) &&
            _queueContextCurrent(
              thread,
              protectedSend,
              profile,
              queueGeneration,
            ) &&
            _entryFor(thread, protectedSend) != null,
        beforeSubmit: () async {
          if (!queueAvailable(thread) ||
              !_queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              ) ||
              _entryFor(thread, protectedSend) == null) {
            throw QueueSubmissionNotStarted(
              StateError('Queue scope unavailable'),
            );
          }
          await protectedSend.store.beginSubmission(
            protectedSend.scope,
            protectedSend.id,
            protectedSend.claim,
          );
          protectedSend.started = true;
          _replaceQueueState(
            thread,
            protectedSend,
            QueueRecordState.submissionStarted,
            submitting: true,
          );
          if (!queueAvailable(thread) ||
              !_queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            throw QueueSubmissionNotStarted(
              StateError('Queue scope unavailable'),
            );
          }
        },
        onNotSubmitted: () => _restoreNotSubmitted(thread, protectedSend),
      );
    }
    subscription = stream.listen(
      (event) {
        if (!_currentActivity(epoch)) return;
        if (event is PromptAcknowledged) {
          if (protectedSend == null ||
              _queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            _assignPromptReceipt(
              thread,
              submittedUser,
              event,
              profile,
              inserted: protectedSend == null,
            );
          }
          return;
        }
        if (event is PromptAccepted &&
            protectedSend != null &&
            PromptAccepted.allowedStatuses.contains(event.status)) {
          if (deferredUser != null &&
              _queueContextCurrent(
                thread,
                protectedSend,
                profile,
                queueGeneration,
              )) {
            final index = thread.messages.indexOf(reply);
            thread.messages.insert(
              index < 0 ? thread.messages.length : index,
              deferredUser,
            );
            _reactionHistory(thread);
            if (!_queueContextCurrent(
              thread,
              protectedSend,
              profile,
              queueGeneration,
            )) {
              _acceptedQueue(thread, protectedSend);
              return;
            }
            final controller = controllerFor(thread);
            final flyerIndex = controller.messages.indexWhere(
              (item) => item.id == chatMessageToFlyer(reply).firstOrNull?.id,
            );
            for (final flyer in chatMessageToFlyer(deferredUser)) {
              controller.insertMessage(
                flyer,
                index: flyerIndex < 0 ? null : flyerIndex,
              );
            }
          }
          _acceptedQueue(thread, protectedSend);
          return;
        }
        if (event is ReplyCompleted) {
          failed = event.failed;
          stopped = event.stopped;
        }
        if (event is PromptFolded) folded = true;
        if (event is SessionInfo && event.running == false) settled = true;
        if (event is UnsolicitedEvent) {
          _onOwnTurnEvent(thread, reply, own, event.event, profile);
          return;
        }
        _onReplyEvent(thread, reply, event, profile);
      },
      onError: end,
      onDone: end,
      cancelOnError: true,
    );
    _replies.add(subscription);
  }

  /// The prompt [reply] answers: the user message before it, which the turn
  /// Hermes ran ahead of it goes in front of. The server stores it there too.
  ChatMessage _promptOf(ChatThread thread, ChatMessage reply) {
    final at = thread.messages.indexOf(reply);
    final user = thread.messages
        .take(at < 0 ? thread.messages.length : at)
        .toList()
        .lastIndexWhere((m) => m.role == ChatRole.user);
    return user < 0 ? reply : thread.messages[user];
  }

  /// An event of the turn Hermes ran on its own ahead of the prompt that
  /// [reply] answers. It streams into a reply of its own, in front of the
  /// prompt, while [reply] keeps waiting for its turn; the turn's end closes
  /// it. The turn belongs to the send: its end does not settle the queue or
  /// touch a stop in flight.
  void _onOwnTurnEvent(
    ChatThread thread,
    ChatMessage reply,
    _OwnTurn own,
    ChatEvent event,
    String? profile,
  ) {
    if (_onMoaEvent(thread, own.open, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    // The transport takes an idle report for the turn's end only once the turn
    // has begun; so does this. An approval alone does not begin it.
    if (beginsTurn(event)) own.began = true;
    final asks =
        event is ApprovalRequested ||
        event is ClarifyRequested ||
        event is VaultRequested ||
        event is UnsupportedRequested;
    if (own.open == null &&
        (opensTurn(event) ||
            asks ||
            // A snapshot of a turn already running, and a failure before any
            // frame of it, are the turn's too.
            (event is ReplyRebuilt || event is ReplyErrored) &&
                own.last == null)) {
      own.open = own.last = _insertReply(
        thread,
        before: _promptOf(thread, reply),
      );
    }
    final open = own.open;
    if (open == null) {
      // Nothing of the turn is on screen to carry it.
      final last = own.last;
      switch (event) {
        case ReplyCompleted() when last?.settledWithoutCompletion ?? false:
          // The turn settled on an idle report; its completion comes late.
          _onReplyEvent(
            thread,
            last!,
            event,
            profile,
            announce: event.failed,
            settles: false,
          );
          last.settledWithoutCompletion = false;
        case InputRequestsCancelled() || InputRequestExpired():
          if (last != null) {
            _onReplyEvent(thread, last, event, profile, announce: false);
          }
        case ReplyErrored(:final message):
          // The turn failed with no reply to show it; the hold of the send in
          // flight is not its to end.
          if (message.isNotEmpty) report(message);
        case SessionInfo(:final storedSessionId?) when storedSessionId != '':
          _onSessionInfo(
            thread,
            SessionInfo(storedSessionId: storedSessionId),
            settle: false,
          );
        case ThreadTitled(:final title):
          _titled(thread, title);
          notifyListeners();
        case ThreadNeedsRefetch():
          _refetch.add(thread);
          _invalidateMoaReferences(thread);
        default:
          break;
      }
      return;
    }
    final idle = event is SessionInfo && event.running == false;
    if (idle && !own.began) {
      // Hermes may still wait on what the turn asked: only a re-keyed id goes
      // on.
      if (event.storedSessionId case final stored? when stored != '') {
        _onSessionInfo(
          thread,
          SessionInfo(storedSessionId: stored),
          settle: false,
        );
      }
      return;
    }
    _onReplyEvent(thread, open, event, profile, settles: false, ownTurn: true);
    if (event is ReplyCompleted || idle) own.open = null;
  }

  /// Ends the reply of the turn Hermes ran on its own when the send is over:
  /// settled when the send ended well, failed when it gave up. A failure is
  /// announced here only when the prompt's reply, which announces its own, is
  /// no longer pending to do so.
  void _closeOwnTurn(
    ChatThread thread,
    _OwnTurn own,
    String? profile, {
    required bool failed,
    required bool announceFailure,
  }) {
    final epoch = _activityEpoch;
    final open = own.open;
    own.open = null;
    if (open != null) _finishMoaTurn(thread, open);
    if (open == null || !open.isPending) return;
    _updateReply(
      thread,
      open,
      () => failed
          ? failReply(open, null)
          : applyReplyEvent(open, const SessionInfo(running: false)),
    );
    if (!_currentActivity(epoch)) return;
    if (failed && announceFailure) {
      _announce(thread, const ReplyCompleted('', failed: true), profile);
    }
  }

  /// [thread]'s turn can no longer be followed, so nothing would end what the
  /// Lock Screen and the watch show of it.
  void _abandon(ChatThread thread) {
    liveActivities?.abandon(thread);
    _watchSource?.abandon(thread);
  }

  void _stopFollowing() {
    unawaited(_ownedSubscription?.cancel());
    _ownedSubscription = null;
    _clearBilling();
    _clearReactions();
    _clearTodo();
    _clearConnectors();
    _clearMoa();
    for (final controller in _usage.values) {
      controller.dispose();
    }
    _usage.clear();
    for (final state in _sideResults.values) {
      state.dispose();
    }
    _sideResults.clear();
    for (final state in _processOutputs.values) {
      state.clear();
    }
    _processOutputs.clear();
    _ownedBindings.clear();
    _sessionActionGenerations.clear();
    _sessionStates.clear();
    _reclaimedQueueReview.clear();
    for (final state in _warnings.values) {
      state.clear();
    }
    _warnings.clear();
    _warningGenerations.clear();
    // A turn nobody listens to any more can no longer say it ended.
    for (final thread in _threads) {
      if (_followingIds.contains(thread.id) && !_sending.containsKey(thread)) {
        _abandon(thread);
      }
    }
    for (final subscription in _following) {
      subscription.cancel();
    }
    _following.clear();
    _followingIds.clear();
  }

  /// A turn another client submitted carries no user message on the wire: the
  /// gateway streams only what the agent produced, and the prompt lives in the
  /// stored history alone. When such a turn ends here, the thread is read
  /// again so the prompt the other side sent appears in the transcript.
  void _refetchForeignTurn(ChatThread thread) {
    if (_sending.containsKey(thread)) return;
    _refetch.add(thread);
    _refetchIfIdle(thread);
  }

  /// Hermes can chain turns on its own once a reply ended (a goal that goes
  /// on, a queued prompt); each one gets a reply of its own.
  void _followUps(ChatTransport transport, ChatThread thread, String? profile) {
    _listenOwnedSessions();
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (!active || _profile != profile || !_threads.contains(thread)) return;
    final epoch = _activityEpoch;
    final threadId = thread.id;
    if (!_followingIds.add(threadId)) return;
    ChatMessage? reply;
    late final StreamSubscription<ChatEvent> subscription;
    void end([Object? error]) {
      if (!_currentActivity(epoch)) return;
      _following.remove(subscription);
      _followingIds.remove(thread.id);
      if (error != null || !_sending.containsKey(thread)) {
        _discardWarnings(thread);
      }
      if (!disposed) notifyListeners();
      final pending = reply;
      if (pending != null) _finishMoaTurn(thread, pending);
      if (pending != null && pending.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, pending, () => failReply(pending, error));
        if (!_currentActivity(epoch)) return;
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      }
    }

    subscription = transport
        .followUps(threadId, profile: profile)
        .listen(
          (event) {
            if (!_currentActivity(epoch)) return;
            if (reply == null && opensTurn(event)) {
              // A stop in flight may be aimed at the turn this opens a reply
              // for (a folded prompt's), so the hold stays.
              reply = _addPlaceholder(thread);
            }
            final current = reply;
            if (current == null) {
              _onIdleEvent(thread, event, profile);
              return;
            }
            _onReplyEvent(thread, current, event, profile);
            if (!_currentActivity(epoch)) return;
            if (event is ReplyCompleted) {
              reply = null;
              final drain = _turnEnded(
                thread,
                halted: event.failed || event.stopped,
              );
              if (drain) _awaitSettle(thread);
              _refetchForeignTurn(thread);
              unawaited(refreshActive());
            } else if (event is SessionInfo && event.running == false) {
              // The session reports the turn over without a completion. It is
              // closed all the same, so the next chained turn gets a reply of
              // its own, and the queue goes on now that the session settled.
              reply = null;
              final drain = _turnEnded(
                thread,
                halted: current.status == MessageStatus.error,
                idleOnly: true,
              );
              if (drain) _drainQueue(thread);
              _refetchForeignTurn(thread);
              unawaited(refreshActive());
            }
          },
          onError: end,
          onDone: end,
          cancelOnError: true,
        );
    _following.add(subscription);
  }

  /// An event on the follow-ups while no reply is open. It is about the
  /// thread, or a completion for the reply a turn ended without.
  void _onIdleEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (_onMoaEvent(thread, null, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    switch (event) {
      case SessionInfo(:final running):
        // The turn a stop in flight was aimed at ended with no reply open.
        if (running == false) _turnEnded(thread, idleOnly: true);
        _onSessionInfo(thread, event);
      case ThreadTitled(:final title):
        _titled(thread, title);
        notifyListeners();
      case ReviewSummarized():
        _onReviewSummary(thread, event);
      case SubagentUpdated():
        final owner = _subagentOwner(thread, event);
        if (owner == null) return;
        _updateReply(thread, owner, () => applyReplyEvent(owner, event));
      case ThreadNeedsRefetch():
        _refetch.add(thread);
        _refetchIfIdle(thread);
        _invalidateMoaReferences(thread);
      case ReplyErrored(:final message):
        // A failure with no reply open to show it, from a turn that never
        // began. It pauses the queue like any failure, and says so.
        _settleTimers.remove(thread)?.cancel();
        _turnEnded(thread, halted: true);
        if (message.isNotEmpty) report(message);
      case ReplyCompleted():
        final settled = _settledReply(thread);
        if (settled == null) return;
        // The settle announced this reply already; a failure is news.
        _onReplyEvent(thread, settled, event, profile, announce: event.failed);
        settled.settledWithoutCompletion = false;
      default:
        break;
    }
  }

  /// Puts what the background review saved under the reply it read: the
  /// latest one that has finished. The review runs after its turn, so a reply
  /// still being written ([open]) is the next turn's.
  void _onReviewSummary(
    ChatThread thread,
    ReviewSummarized event, {
    ChatMessage? open,
  }) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.assistant) continue;
      if (identical(message, open) || message.isPending) continue;
      _updateReply(thread, message, () => applyReplyEvent(message, event));
      return;
    }
  }

  /// The reply that spawned the subagent [event] names. A child delegated
  /// in the background outlives that reply, so its later frames arrive on
  /// the follow-ups, between turns or during another one.
  ChatMessage? _subagentOwner(ChatThread thread, SubagentUpdated event) {
    for (final message in thread.messages.reversed) {
      if (message.subagents.any((s) => s.id == event.subagent.id)) {
        return message;
      }
    }
    return null;
  }

  /// The reply a turn ended without its completion, which a completion
  /// arriving later belongs to. Only the thread's last assistant message can
  /// be it: once another turn started, a completion is not its.
  ChatMessage? _settledReply(ChatThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.assistant) continue;
      return message.settledWithoutCompletion ? message : null;
    }
    return null;
  }

  /// Follows the session's stored id when compression rotates it, and
  /// settles the queue when the session reports it is no longer running.
  void _onSessionInfo(
    ChatThread thread,
    SessionInfo info, {
    bool settle = true,
  }) {
    final stored = info.storedSessionId;
    if (stored != null && stored.isNotEmpty && stored != thread.id) {
      if (_bound.contains(thread)) {
        _retargetBoundThread(thread, stored);
      } else {
        _bindThread(thread, stored);
      }
    }
    if (info.running == false) _queueSettled.add(thread);
    if (info.running == true) _queueSettled.remove(thread);
    if (settle && info.running == false) _settle(thread);
  }

  /// Takes [reply] out of the transcript, for a prompt the server folded into
  /// the turn already running: no reply of its own was shown for it.
  void _removeReply(ChatThread thread, ChatMessage reply) {
    final before = chatMessageToFlyer(reply);
    thread.messages.remove(reply);
    notifyListeners();
    syncMessage(controllerFor(thread), before, const []);
  }

  /// Reads the thread again once it asked for that and no reply is pending.
  void _refetchIfIdle(ChatThread thread) {
    if (thread.isReplying || !_refetch.remove(thread)) return;
    unawaited(refreshThread(thread.id));
  }

  void _onReplyEvent(
    ChatThread thread,
    ChatMessage reply,
    ChatEvent event,
    String? profile, {
    bool announce = true,
    bool settles = true,
    bool ownTurn = false,
  }) {
    final epoch = _activityEpoch;
    if (!_currentActivity(epoch)) return;
    if (opensTurn(event)) _beginMoaTurn(thread, reply);
    if (_onMoaEvent(thread, reply, event, profile)) return;
    if (_onConnectorOperation(thread, event, profile) ||
        _onBillingEvent(thread, event, profile) ||
        _onReactionEvent(thread, event, profile) ||
        _onTodoEvent(thread, event, profile) ||
        _onSideResult(thread, event, profile) ||
        _onProcessOutput(thread, event, profile) ||
        _onUsageEvent(thread, event, profile) ||
        _onSessionEvent(thread, event, profile) ||
        _onWarning(thread, event, profile)) {
      return;
    }
    if (event is ReplyCompleted ||
        event is ReplyErrored ||
        event is PromptFolded ||
        event is SessionInfo && event.running == false) {
      _finishMoaTurn(thread, reply);
    }
    var announced = event;
    switch (event) {
      case ThreadBound(:final threadId):
        _bindThread(thread, threadId);
        _syncTodo(thread, profile);
        _syncOwnedSession(thread, profile);
        _syncConnector(thread, profile);
        if (!_currentActivity(epoch)) return;
        final source = transport;
        final binding = source is OwnedSessionTransport
            ? (source as OwnedSessionTransport).ownedSessionFor(
                thread.id,
                profile: profile,
              )
            : null;
        if (binding != null && (profile?.isNotEmpty ?? false)) {
          _adoptBilling((profile, thread.id), binding);
        }
      case ThreadTitled(:final title):
        _titled(thread, title);
        notifyListeners();
      case ReplyStarted() ||
          UnsolicitedEvent() ||
          PromptAcknowledged() ||
          PromptAccepted():
      case ConnectorOperationReceived() ||
          BillingVerificationReceived() ||
          MessageReactionsUpdated() ||
          SessionAcknowledgementReported() ||
          SideResultReceived() ||
          MoaUpdated() ||
          ProcessOutputReceived() ||
          SessionUsageUpdated() ||
          ToolRiskFlagged() ||
          NoticeShown() ||
          NoticeCleared() ||
          TodoUpdated() ||
          SessionControlUpdated() ||
          SessionControlUnavailable() ||
          SessionWaitUpdated() ||
          SessionReclaimed() ||
          SessionResumeProgress() ||
          WarningScopeDiscarded():
        break;
      case PromptFolded():
        _removeReply(thread, reply);
      case SessionInfo():
        final wasPending = reply.isPending;
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
        if (!_currentActivity(epoch)) return;
        _onSessionInfo(thread, event, settle: settles);
        if (wasPending && !reply.isPending) {
          // The turn ended without a completion, which the notifications wait
          // for: tell them how it ended.
          announced = ReplyCompleted(
            reply.content,
            failed: reply.status == MessageStatus.error,
            stopped: switch (_holdOf(thread)) {
              _Hold.stopping || _Hold.paused => true,
              _ => false,
            },
          );
        }
      case ThreadNeedsRefetch():
        _refetch.add(thread);
        _invalidateMoaReferences(thread);
      case ReviewSummarized():
        _onReviewSummary(thread, event, open: reply);
      case SubagentUpdated():
        final owner = _subagentOwner(thread, event) ?? reply;
        _updateReply(thread, owner, () => applyReplyEvent(owner, event));
      case ReplyErrored() ||
          ReplyStatus() ||
          InputRequestsCancelled() ||
          ReplyRebuilt():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
      case ReplyDelta() ||
          ReplyCheckpoint() ||
          ReasoningUpdated() ||
          ToolPreparing() ||
          ToolStarted() ||
          ToolFinished() ||
          ReplyCompleted() ||
          ApprovalRequested() ||
          ClarifyRequested() ||
          VaultRequested() ||
          UnsupportedRequested() ||
          InputRequestExpired():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
        if (event case ToolStarted(:final id, :final runtimeId)) {
          _warningState(thread, runtimeId);
          final generation = _warningGeneration(thread);
          final index = reply.toolCalls.lastIndexWhere(
            (call) => call.id == id && call.runtimeId == runtimeId,
          );
          if (index >= 0) {
            _updateReply(
              thread,
              reply,
              () => reply.toolCalls = [...reply.toolCalls]
                ..[index] = reply.toolCalls[index].copyWith(
                  warningGeneration: generation,
                ),
            );
          }
          _attachRisk(thread, reply, id, runtimeId);
        }
    }
    if (!_currentActivity(epoch)) return;
    _refetchIfIdle(thread);
    _announce(thread, announced, profile, notify: announce, ownTurn: ownTurn);
  }

  /// Moves the chat's Live Activity and the watch's status along for
  /// [event], and posts the notification it deserves unless [notify] is
  /// false. [profile] is the one the turn was sent under: the thread on
  /// screen only counts when the chat is still on that profile.
  void _announce(
    ChatThread thread,
    ChatEvent event,
    String? profile, {
    bool notify = true,
    bool ownTurn = false,
  }) {
    if (!active) return;
    final epoch = _activityEpoch;
    // The turn Hermes ran ahead of the prompt ends before the prompt's own
    // turn does, so its completion says nothing about the chat.
    if (!(ownTurn && event is ReplyCompleted)) {
      if (event is ReplyCompleted) _replyEnded(thread, profile);
      _announcedTurns.add(thread);
      liveActivities?.onEvent(thread, event);
      _watchSource?.onEvent(
        thread,
        event,
        title: _watchTitle(thread),
        threadId: _watchThreadId(thread, profile),
      );
    }
    if (!notify) return;
    void announce() {
      if (!_currentActivity(epoch)) return;
      _attention.announce(
        thread,
        event,
        selectedThreadId: profile == _profile ? _selectedId : null,
        profile: profile,
      );
    }

    final store = runningReplies;
    if (store == null || event is! ReplyCompleted) return announce();
    // A background run may have told the user of this very ending already;
    // the replay on return, or a reconnect during its wake, would tell again.
    store
        .takeAnnounced(profile, thread.id)
        .then(
          (was) => was ? null : announce(),
          onError: (Object _) => announce(),
        )
        .ignore();
  }

  void _carryReplies() {
    for (final thread in _threads) {
      if (thread.remote && thread.isReplying) {
        _carried.add((_profile, thread.id));
      }
    }
  }

  /// The app is leaving the front: remembers the chats whose reply still runs,
  /// in this profile and in the ones left since, which a background run
  /// announces once they finish. What an earlier run announced is forgotten:
  /// it described the last time the app was away.
  void rememberRunningReplies() {
    if (!active) return;
    final store = runningReplies;
    if (store == null) return;
    final now = _clock();
    _pauses++;
    _replayEnds?.cancel();
    _carried.removeWhere((key) => _expired(key, now));
    final running = {
      for (final thread in _threads)
        if (thread.remote && thread.isReplying) (_profile, thread.id),
      ..._carried,
    };
    _rememberedSince.removeWhere((key, _) => !running.contains(key));
    for (final key in running) {
      _rememberedSince.putIfAbsent(key, () => now);
    }
    _replyListWritten = true;
    unawaited(store.clearAnnounced());
    unawaited(
      store.replace([
        for (final (profile, id) in running)
          RunningReply(
            profile: profile,
            threadId: id,
            since: _rememberedSince[(profile, id)]!,
          ),
      ]),
    );
  }

  bool _expired((String?, String) key, DateTime now) {
    final since = _rememberedSince[key];
    return since != null && now.difference(since) > kRunningReplyLifetime;
  }

  /// The app is in front: the replies are shown here, so nothing is left for
  /// a background run to announce. A reply that a run finished or whose
  /// session no longer runs has ended, and is not carried on. What a run
  /// announced stays on record only for the replay of its ending, which
  /// [replayGrace] allows for.
  void forgetRunningReplies() {
    if (!active) return;
    final store = runningReplies;
    if (store == null) return;
    final written = _replyListWritten;
    _replyListWritten = false;
    if (written) {
      _replayEnds?.cancel();
      _replayEnds = Timer(replayGrace, () {
        if (active) unawaited(store.clearAnnounced());
      });
    }
    unawaited(
      _resumeRunningReplies(store, written, _pauses).catchError((Object _) {}),
    );
  }

  Future<void> _resumeRunningReplies(
    RunningReplies store,
    bool written,
    int pauses,
  ) async {
    // Each await below can outlast a pause, whose list and carried replies
    // are newer than anything this return learns: it stops at the first one.
    if (written && _carried.isNotEmpty) {
      final left = {
        for (final reply in await store.read()) (reply.profile, reply.threadId),
      };
      if (!active || pauses != _pauses) return;
      _carried.retainAll(left);
      if (!await _dropEnded(pauses)) return;
    }
    if (!active || pauses != _pauses) return;
    await store.clear();
  }

  /// Takes off [_carried] the replies whose session reports a turn that has
  /// ended; false when a pause came meanwhile. A server that cannot say, or
  /// does not list a session, decides nothing: the expiry does.
  Future<bool> _dropEnded(int pauses) async {
    final transport = this.transport;
    if (!active) return false;
    if (transport == null) return true;
    for (final profile in {for (final (profile, _) in _carried) profile}) {
      final statuses = await transport.activeStatuses(profile: profile);
      if (!active || pauses != _pauses) return false;
      _carried.removeWhere((key) {
        if (key.$1 != profile) return false;
        final status = statuses[key.$2];
        if (status == null || _runningStatuses.contains(status)) return false;
        _rememberedSince.remove(key);
        return true;
      });
    }
    return active && pauses == _pauses;
  }

  void _replyEnded(ChatThread thread, String? profile) {
    _carried.remove((profile, thread.id));
    _rememberedSince.remove((profile, thread.id));
    final store = runningReplies;
    if (store == null || !_replyListWritten) return;
    unawaited(
      store.forget([
        RunningReply(
          profile: profile,
          threadId: thread.id,
          since: DateTime.now(),
        ),
      ]),
    );
  }

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

  /// The title the watch face may show: a name, never one made from the
  /// prompt, a file name or the first message.
  String? _watchTitle(ChatThread thread) => thread.named ? thread.title : null;

  /// The id the watch uses for [thread], once the dashboard stores it.
  String? _watchThreadId(ChatThread thread, String? profile) =>
      thread.remote ? boundThreadId(profile, thread.id) : null;

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

  void _updateReply(
    ChatThread thread,
    ChatMessage reply,
    void Function() edit,
  ) {
    if (!active) return;
    final epoch = _activityEpoch;
    final before = chatMessageToFlyer(reply);
    final wasPending = reply.isPending;
    final openBefore = _openRequestIds(reply);
    edit();
    notifyListeners();
    if (!_currentActivity(epoch)) return;
    syncMessage(controllerFor(thread), before, chatMessageToFlyer(reply));
    if (onSurfaceChange == null) return;
    final trigger = wasPending && !reply.isPending
        ? SurfaceTrigger.reply
        : _openRequestIds(reply) != openBefore
        ? SurfaceTrigger.request
        : null;
    if (trigger == null) return;
    _touched[thread] = DateTime.now();
    _reportSurface(trigger);
  }

  String _openRequestIds(ChatMessage reply) => onSurfaceChange == null
      ? ''
      : [
          for (final request in reply.inputRequests)
            if (request.status == InputRequestStatus.pending) request.requestId,
        ].join(',');

  /// When a reply last ended or a request last changed in a chat, which the
  /// list the server gave us does not know yet.
  final _touched = <ChatThread, DateTime>{};

  /// When each open request was first seen; Hermes sends no creation time.
  final _requestSeen = <String, DateTime>{};

  void _reportSurface(SurfaceTrigger trigger) {
    if (active) onSurfaceChange?.call(trigger, _surfaceHints());
  }

  ChatHints _surfaceHints() {
    final now = DateTime.now();
    final threads = <ThreadHint>[];
    final requests = <RequestHint>[];
    final seen = <String, DateTime>{};
    for (final thread in _threads) {
      if (!thread.remote || thread.isCanonicalBotChat) continue;
      final touched = _touched[thread];
      final snippet = thread.messages.lastOrNull?.content;
      // A title made from the prompt would put its words on widgets.
      final title = thread.named ? thread.title : kUnnamedChatLabel;
      threads.add(
        ThreadHint(
          id: thread.id,
          title: title,
          updatedAt: touched != null && touched.isAfter(thread.updatedAt)
              ? touched
              : thread.updatedAt,
          snippet: snippet,
        ),
      );
      for (final message in thread.messages) {
        for (final request in message.inputRequests) {
          if (request.status != InputRequestStatus.pending) continue;
          final first = _requestSeen[request.requestId] ?? now;
          seen[request.requestId] = first;
          requests.add(
            RequestHint(
              threadId: thread.id,
              threadTitle: title,
              kind: switch (request) {
                ApprovalRequest() => PendingKind.approval,
                ClarifyRequest() => PendingKind.question,
                _ => PendingKind.input,
              },
              requestId: request.requestId,
              seenAt: first,
            ),
          );
        }
      }
    }
    _requestSeen
      ..clear()
      ..addAll(seen);
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ChatHints(
      profile: _profile,
      threads: threads.take(kMaxRecentChats).toList(),
      requests: requests,
    );
  }

  ChatMessage? _replyAwaiting(ChatThread thread, String requestId) {
    for (final message in thread.messages.reversed) {
      if (message.inputRequests.any((r) => r.requestId == requestId)) {
        return message;
      }
    }
    return null;
  }

  Future<bool?> _answerWhileActive(Future<bool> Function() call) async {
    if (!active) return null;
    final epoch = _activityEpoch;
    try {
      final result = await call();
      return _currentActivity(epoch) ? result : null;
    } on Object {
      if (!_currentActivity(epoch)) return null;
      rethrow;
    }
  }

  Future<void> answerApproval(
    ChatThread thread,
    String requestId,
    String choice,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final accepted = await _answerWhileActive(
      () => transport.answerApproval(requestId, choice),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordApproval(reply, requestId, choice)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

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

  _Hold _holdOf(ChatThread thread) => _holds[thread] ?? _Hold.none;

  void _setHold(ChatThread thread, _Hold hold) {
    if (hold == _Hold.none) {
      _holds.remove(thread);
    } else {
      _holds[thread] = hold;
    }
  }

  bool _interruptInFlight(ChatThread thread) => (_interrupts[thread] ?? 0) > 0;

  /// Settles the hold of [thread] when its turn ends, and tells whether the
  /// queue may go on. A stopped or failed turn ([halted]) pauses it, and while
  /// an interrupt is still in flight the pause outlasts the turn, so that
  /// interrupt's answer cannot release it. [idleOnly]: the turn ended on an
  /// idle report, not a completion, so a stop asked for may still be what ended
  /// it and its answer decides.
  bool _turnEnded(
    ChatThread thread, {
    bool halted = false,
    bool idleOnly = false,
  }) {
    final ready = _finishTurnHold(thread, halted: halted, idleOnly: idleOnly);
    ready ? _queueTurnReady.add(thread) : _queueTurnReady.remove(thread);
    return ready;
  }

  bool _finishTurnHold(
    ChatThread thread, {
    bool halted = false,
    bool idleOnly = false,
  }) {
    if (_suspendedQueues.contains(thread)) return false;
    final afterwards = _interruptInFlight(thread) ? _Hold.paused : _Hold.none;
    if (halted) {
      _setHold(thread, afterwards);
      return false;
    }
    switch (_holdOf(thread)) {
      case _Hold.none:
        return true;
      case _Hold.paused || _Hold.stopping:
        _setHold(thread, afterwards);
        return false;
      case _Hold.asked || _Hold.askedEnded:
        if (idleOnly) {
          _setHold(thread, _Hold.askedEnded);
          return false;
        }
        // A completion that is not a stop answers the question: the turn
        // finished by itself.
        _setHold(thread, _Hold.none);
        return true;
    }
  }

  /// Ends one interrupt of [thread]. True while others are still in flight.
  bool _endInterrupt(ChatThread thread) {
    final left = (_interrupts[thread] ?? 1) - 1;
    if (left > 0) {
      _interrupts[thread] = left;
    } else {
      _interrupts.remove(thread);
    }
    return left > 0;
  }

  Future<void> stopReply(ChatThread thread) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    if (!active) return;
    final epoch = _activityEpoch;
    _finishQueueBinding(thread, false);
    final pending = [
      for (final reply in thread.messages)
        if (reply.isPending) reply,
    ];
    final generation = _generations[thread] ?? 0;
    _interrupts.update(thread, (n) => n + 1, ifAbsent: () => 1);
    if (thread.isReplying && _holdOf(thread) == _Hold.none) {
      _setHold(thread, _Hold.asked);
    }
    try {
      final stopped = await transport?.stopReply(thread.id, profile: _profile);
      if (!_currentActivity(epoch)) return;
      if ((_generations[thread] ?? 0) != generation) return;
      final others = _endInterrupt(thread);
      final hold = _holdOf(thread);
      if (stopped == true) {
        // The turn is going to end stopped. If it ended already, this answer
        // only releases what its end left.
        _setHold(thread, switch (hold) {
          _Hold.asked => _Hold.stopping,
          _Hold.askedEnded ||
          _Hold.paused => others ? _Hold.paused : _Hold.none,
          _ => hold,
        });
        return;
      }
      if (stopped != false) {
        _setHold(thread, others ? hold : _Hold.none);
        return;
      }
      final stale = [
        for (final reply in pending)
          if (reply.isPending && thread.messages.contains(reply)) reply,
      ];
      if (stale.isNotEmpty) {
        // The server has no turn left to interrupt. A completion was missed by
        // this listener, so release the stale pending reply and composer.
        _setHold(
          thread,
          others || hold == _Hold.stopping || hold == _Hold.paused
              ? _Hold.paused
              : _Hold.none,
        );
        for (final reply in stale) {
          _updateReply(
            thread,
            reply,
            () =>
                applyReplyEvent(reply, const ReplyCompleted('', stopped: true)),
          );
        }
        liveActivities?.onEvent(
          thread,
          const ReplyCompleted('', stopped: true),
        );
        _watchSource?.drop(thread);
        return;
      }
      // Nothing was running: the turn ended on its own. Only the stop that
      // held the queue lets it go on, and only when no other is in flight.
      if (others) return;
      switch (hold) {
        case _Hold.asked || _Hold.askedEnded:
          _setHold(thread, _Hold.none);
          _drainQueue(thread);
        case _Hold.paused:
          _setHold(thread, _Hold.none);
        default:
          break;
      }
    } on Object {
      if (!_currentActivity(epoch)) return;
      // The stop of an earlier reply failing is of no use to say.
      if ((_generations[thread] ?? 0) != generation) return;
      final others = _endInterrupt(thread);
      if (!others) {
        // The interrupt did not get through, so it decides nothing: the queue
        // goes on with the turn's own end.
        switch (_holdOf(thread)) {
          case _Hold.asked:
            _setHold(thread, _Hold.none);
            _awaitSettle(thread);
          case _Hold.askedEnded:
            _setHold(thread, _Hold.none);
            _drainQueue(thread);
          case _Hold.paused:
            _setHold(thread, _Hold.none);
          default:
            break;
        }
      }
      report(_couldNotStop);
    }
  }

  Future<void> skipUnsupported(
    ChatThread thread,
    String requestId,
    UnsupportedKind kind,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final accepted = await _answerWhileActive(
      () => transport.skipUnsupported(requestId, kind),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordSkipped(reply, requestId)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> answerVaultRequest(
    ChatThread thread,
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final declined = identifier.isEmpty && password.isEmpty && code.isEmpty;
    final accepted = await _answerWhileActive(
      () => transport.answerVault(
        requestId,
        kind,
        identifier: identifier,
        password: password,
        code: code,
      ),
    );
    if (accepted == null || _sessionStates[thread]?.reclaimedReason != null) {
      return;
    }
    _updateReply(
      thread,
      reply,
      () => accepted
          ? declined
                ? recordVaultDeclined(reply, requestId)
                : recordVaultAnswered(reply, requestId, identifier: identifier)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> answerClarify(
    ChatThread thread,
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    if (_sessionStates[thread]?.reclaimedReason != null) return;
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (!active || transport == null || reply == null) return;
    final request = reply.inputRequests.firstWhere(
      (r) => r.requestId == requestId,
    );
    if (request is! ClarifyRequest) return;

    final epoch = _activityEpoch;
    bool? accepted = true;
    if (answers.isEmpty) {
      accepted = await _answerWhileActive(
        () => transport.answerClarify(requestId, const []),
      );
    } else {
      for (final q in request.questions) {
        if (!_currentActivity(epoch) ||
            _sessionStates[thread]?.reclaimedReason != null) {
          return;
        }
        accepted = await _answerWhileActive(
          () => transport.answerClarify(
            requestId,
            answers[q.qid] ?? const [],
            questionId: request.batch ? q.qid : null,
            multiSelect: q.multiSelect,
          ),
        );
        if (accepted != true) break;
      }
    }
    if (accepted == null || !_currentActivity(epoch)) return;
    _updateReply(
      thread,
      reply,
      () => accepted!
          ? recordClarifyAnswers(reply, requestId, answers)
          : expireInputRequests(reply, requestId: requestId),
    );
  }
}

/// Why a thread's queue is held while an interrupt is in flight.
enum _Hold {
  none,

  /// The user asked to stop; the answer or the turn's end decides.
  asked,

  /// The turn ended on an idle report while a stop was still unanswered.
  askedEnded,

  /// The server confirmed the interrupt: the turn's end pauses the queue.
  stopping,

  /// The turn ended stopped or failed while an interrupt was in flight.
  paused,
}

/// The reply a send opened for the turn Hermes ran on its own ahead of the
/// prompt. [last] stays after the turn ended, so a withdrawal of its requests
/// still finds it.
class _OwnTurn {
  ChatMessage? open;
  ChatMessage? last;

  /// Whether a frame that begins a turn has come: before that, an idle report
  /// is not the turn's end.
  var began = false;
}

class _ProtectedQueuedSend {
  _ProtectedQueuedSend(
    this.prompt,
    this.scope,
    this.store,
    this.epoch,
    this.activityEpoch,
    this.sessionGeneration,
  ) : claim = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
  final QueuedPrompt prompt;
  final QueueScope scope;
  final PromptQueueStore store;
  final int epoch;
  final int activityEpoch;
  final int sessionGeneration;
  final String claim;
  String get id => prompt.durable!.id;
  bool started = false;
  bool accepted = false;
  bool provenNotSubmitted = false;
  bool restored = false;
}
