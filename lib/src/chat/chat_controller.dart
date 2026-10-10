import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;
import 'package:shared_preferences/shared_preferences.dart';

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
import '../telemetry/breadcrumbs.dart';
import 'chat_controller_sync.dart';
import 'chat_message_mapper.dart';
import 'chat_models.dart';
import 'chat_reply.dart';
import 'chat_transport.dart';
import 'gateway/gateway_rpc_client.dart' show GatewayRpcException;
import 'hermes_chat_repository.dart';
import 'mock_chat_data.dart';
import 'queued_prompt.dart';
import 'slash_command.dart';
import 'thread_housekeeping.dart';
import 'thread_search.dart';

const _couldNotOpenChat = 'Could not open that chat.';
const _couldNotStop = 'Could not stop the reply. Try again.';

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
    this.botChats,
    required this._attention,
    this.liveActivities,
    required this.report,
    this.onShowChat,
    this.onOpenJob,
    this.onOpened,
    this.onPrefill,
    this.breadcrumbs = Breadcrumbs.none,
  }) {
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
        history: _history,
      );
      search = ThreadSearch(
        (query) => repository.searchThreads(query, profile: _profile),
        searchAll: profiles == null ? null : _searchAllProfiles,
        recentStore: SharedPreferencesAsync(),
      );
    }
  }

  final HermesChatRepository? repository;
  final HermesProfilesRepository? profiles;
  final HermesModelsRepository? models;
  final ChatTransport? transport;
  final BotModeChatRepository? botChats;
  int _openGeneration = 0;
  final AttentionNotifier _attention;

  /// Shows replies sent here as Live Activities; null where there are none.
  final LiveActivities? liveActivities;

  /// Tells the user something went wrong.
  final ValueChanged<String> report;

  /// Asks the host to bring the chat to the front.
  final VoidCallback? onShowChat;

  /// Called for a notification about a scheduled task.
  final void Function(NotificationTarget target)? onOpenJob;

  /// Called after a chat asked for from outside was selected.
  final VoidCallback? onOpened;

  /// Restores a draft returned by a command such as `/undo`.
  final ValueChanged<String>? onPrefill;

  /// Notes what the user did, for a crash report. It is never given text,
  /// titles, profile names or ids.
  final Breadcrumbs breadcrumbs;

  ThreadHousekeeping? housekeeping;

  /// Whether the last chat asked for from outside could not be opened.
  bool get openFailed => _openFailed;
  bool _openFailed = false;

  void _failOpen() {
    _openFailed = true;
    breadcrumbs('chat.open.failed');
    report(_couldNotOpenChat);
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
  final _queues = <ChatThread, List<QueuedPrompt>>{};

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

  ChatThread? get selectedThread {
    for (final thread in _threads) {
      if (thread.id == _selectedId) return thread;
    }
    return null;
  }

  /// Whether [id] has older messages on the server than those loaded.
  bool hasOlder(String id) => _olderRows.containsKey(id);

  /// Lists the threads of [profile], or of the sticky active profile when
  /// none is given. The dashboard does not scope sessions to that profile by
  /// itself, so it is passed on every read.
  Future<void> loadThreads([String? profile]) => _loadThreads(profile);

  Future<void> _loadThreads(String? profile, {bool Function()? valid}) async {
    final generation = ++_loadGeneration;
    _loadingThreads = true;
    _threadsFailed = false;
    notifyListeners();
    try {
      profile ??= await _activeProfile();
      final first = await repository!.loadThreadPage(profile: profile);
      var launched = await _attention.takeLaunchTarget();
      if (launched != null && launched.isJob) {
        onOpenJob?.call(launched);
        launched = null;
      }
      if (disposed || generation != _loadGeneration) return;
      if (valid?.call() == false) {
        _loadingThreads = false;
        notifyListeners();
        return;
      }
      final held = _pendingTap;
      final fetchHeld = held != null && _pendingFetch;
      final launch = held ?? launched;
      _pendingTap = null;
      _pendingFetch = false;
      final threads = housekeeping!.begin(first);
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
      _profile = profile;
      breadcrumbs('chat.threads.loaded', {
        'switched': switched,
        'count': threads.length,
      });
      unawaited(_loadModelOptions(profile, generation));
      _threads = threads;
      _unloaded
        ..clear()
        ..addAll(threads.map((t) => t.id));
      _olderRows.clear();
      _queues.clear();
      _cancelSettleWaits();
      _bound
        ..clear()
        ..addAll(threads);
      _loadingThreads = false;
      _selectedId =
          _isOnProfile(launch, profile) &&
              threads.any((t) => t.id == launch!.threadId)
          ? launch!.threadId
          : null;
      notifyListeners();
      if (launch != null) {
        // A held tap already put Chat in front when it arrived.
        if (held == null) onShowChat?.call();
        if (_selectedId != launch.threadId) {
          if (fetchHeld) {
            unawaited(_openMissing(launch));
          } else {
            _failOpen();
          }
        }
      }
      if (_selectedId != null) {
        final selected = _threads.firstWhere((t) => t.id == _selectedId);
        unawaited(
          _loadMessages(selected.id).then((_) {
            if (!disposed &&
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
      if (disposed || generation != _loadGeneration) return;
      _loadingThreads = false;
      _threadsFailed = true;
      breadcrumbs('chat.threads.failed');
      notifyListeners();
    }
  }

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
    if (disposed || generation != _loadGeneration) return;
    _modelOptions = options;
    notifyListeners();
  }

  /// The first page of a thread's messages that is being read, by thread id.
  final _loadingMessages = <String, Future<void>>{};

  Future<void> _loadMessages(String id) {
    if (!_unloaded.remove(id)) return Future.value();
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
      if (disposed || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      thread.messages.addAll(page.messages);
      if (page.hasMore) _olderRows[id] = page.rows;
      notifyListeners();
      await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      if (generation != _loadGeneration) return;
      _unloaded.add(id);
      if (disposed) return;
      report('Could not load this chat');
    }
  }

  /// Every message of [thread]: what is loaded, plus the pages the dashboard
  /// holds beyond it. A thread whose messages were never loaded is read
  /// whole; an open one is not read again.
  Future<List<ChatMessage>> _history(ChatThread thread) async {
    final repository = this.repository;
    if (repository == null || !_bound.contains(thread)) return thread.messages;
    await _loadingMessages[thread.id];
    final loaded = !_unloaded.contains(thread.id);
    final newest = loaded ? thread.messages : const <ChatMessage>[];
    final held = {for (final m in newest) m.id};
    final pages = [newest];
    final profile = _profile;
    int? offset = loaded ? _olderRows[thread.id] : 0;
    while (offset != null) {
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
        offset: offset,
      );
      pages.add([
        for (final m in page.messages)
          if (held.add(m.id)) m,
      ]);
      offset = page.hasMore && page.rows > 0 ? offset + page.rows : null;
    }
    return [for (final page in pages.reversed) ...page];
  }

  Future<void> loadOlder(String id) async {
    final offset = _olderRows[id];
    if (offset == null) return;
    final generation = _loadGeneration;
    try {
      final page = await repository!.loadMessagePage(
        id,
        profile: _profile,
        offset: offset,
      );
      if (disposed || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      final held = {for (final m in thread.messages) m.id};
      final older = [
        for (final m in page.messages)
          if (!held.contains(m.id)) m,
      ];
      thread.messages.insertAll(0, older);
      if (page.hasMore && page.rows > 0) {
        _olderRows[id] = offset + page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
      if (older.isEmpty) return;
      await controllerFor(thread).insertAllMessages(
        [for (final m in older) ...chatMessageToFlyer(m)],
        index: 0,
        animated: false,
      );
    } on Object {
      if (!disposed && generation == _loadGeneration) {
        report('Could not load earlier messages');
      }
    }
  }

  /// Reads [id] again from the dashboard after it changed elsewhere (another
  /// window): its title and pin, and its messages once they were loaded. A
  /// chat that is gone leaves the list. Nothing is read while a reply streams
  /// into it, which would replace the reply in progress.
  Future<void> refreshThread(String id) async {
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
        disposed || generation != _loadGeneration || thread.isReplying;
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
      if (unchanged || _unloaded.contains(id)) return;
      final page = await repository.loadMessagePage(id, profile: _profile);
      if (stale()) return;
      final failed = _failedTurn(thread, page.messages);
      thread.messages
        ..clear()
        ..addAll(page.messages)
        ..addAll(failed);
      if (page.hasMore) {
        _olderRows[id] = page.rows;
      } else {
        _olderRows.remove(id);
      }
      notifyListeners();
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
  /// threads do not hold is fetched, on its own profile.
  void open(NotificationTarget target, {required bool fetchMissing}) {
    final generation = ++_openGeneration;
    breadcrumbs('chat.open.requested', {'fetch_missing': fetchMissing});
    onShowChat?.call();
    if (_loadingThreads) {
      _pendingTap = target;
      _pendingFetch = fetchMissing;
    } else if (_isOnProfile(target, _profile) &&
        _threads.any((t) => t.id == target.threadId)) {
      select(target.threadId);
      onOpened?.call();
    } else if (fetchMissing) {
      unawaited(_openMissing(target, generation: generation));
    } else {
      _failOpen();
    }
  }

  /// Opens a chat the loaded threads do not hold: one on another profile, or
  /// older than the first page of sessions.
  Future<void> _openMissing(
    NotificationTarget target, {
    int? generation,
  }) async {
    generation ??= _openGeneration;
    final repository = this.repository;
    final profile = target.profile ?? _profile;
    if (repository == null) return _failOpen();
    try {
      if (profile != _profile) await loadThreads(profile);
      if (disposed || generation != _openGeneration) return;
      // A failed switch leaves the old profile's threads on screen.
      if (profile != _profile) return _failOpen();
      if (!_threads.any((t) => t.id == target.threadId)) {
        final thread = await repository.loadThread(
          target.threadId,
          profile: profile,
        );
        if (disposed || generation != _openGeneration) return;
        if (thread == null) return _failOpen();
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
        notifyListeners();
      }
      select(target.threadId);
      onOpened?.call();
    } on Object {
      if (!disposed) _failOpen();
    }
  }

  Future<bool> restoreHandoff(
    NotificationTarget target,
    bool Function() valid,
  ) async {
    final repository = this.repository;
    final profile = target.profile;
    if (repository == null || profile == null || !valid()) return false;
    final generation = ++_openGeneration;
    bool current() => !disposed && generation == _openGeneration && valid();
    final active = _profile == profile
        ? _threads.where((t) => t.id == target.threadId).firstOrNull
        : null;
    if (active?.isReplying == true) {
      _selectedId = active!.id;
      notifyListeners();
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
    final existing = _threads.where((t) => t.id == target.threadId).firstOrNull;
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
    _pickUp(selected);
    onOpened?.call();
    return true;
  }

  Future<void> openBot(BotChatContext context) async {
    final generation = ++_openGeneration;
    onShowChat?.call();
    final repository = this.repository;
    if (repository == null) return _failOpen();
    final profile = context.bot.name;
    try {
      if (_loadingThreads || _profile != profile) await loadThreads(profile);
      if (disposed || generation != _openGeneration) return;
      if (_profile != profile) return _failOpen();
      var thread = _threads.where((t) => t.id == context.storedId).firstOrNull;
      if (thread == null) {
        thread = await repository.loadThread(
          context.storedId,
          profile: profile,
        );
        if (disposed || generation != _openGeneration) return;
        if (thread == null) return _failOpen();
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
      }
      thread.botContext = context;
      thread.title = BotModeChatRepository.title;
      select(thread.id);
      onOpened?.call();
    } on Object {
      if (!disposed && generation == _openGeneration) _failOpen();
    }
  }

  /// The chats of every profile that match [query], newest first. Each
  /// profile is asked at once; one that fails is left out, and the search
  /// fails only when all of them do.
  Future<List<ThreadSearchHit>> _searchAllProfiles(String query) async {
    final repository = this.repository!;
    final answers = await Future.wait([
      for (final profile in await profiles!.list())
        repository
            .searchThreads(query, profile: profile.name)
            .then<List<ThreadSearchHit>?>(
              (h) => h,
              onError: (Object _) => null,
            ),
    ]);
    if (answers.isNotEmpty && answers.every((a) => a == null)) {
      throw StateError('No profile could be searched');
    }
    return [for (final hits in answers) ...?hits]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Opens a chat the search found, on the profile it was found in.
  void openSearchHit(ThreadSearchHit hit) {
    search?.remember(search!.query);
    open(
      NotificationTarget(threadId: hit.id, profile: hit.profile ?? _profile),
      fetchMissing: true,
    );
  }

  /// Moves on to the first remaining thread when the open one is archived or
  /// deleted.
  void _threadRemoved(ChatThread thread) {
    _queues.remove(thread);
    _settleTimers.remove(thread)?.cancel();
    _refetch.remove(thread);
    liveActivities?.endChat(thread.id, _profile);
    if (_selectedId != thread.id) return;
    _selectedId = _threads.firstOrNull?.id;
    if (_selectedId != null) _loadMessages(_selectedId!);
  }

  /// Asks the transport to drop a connection the OS killed during sleep, and
  /// re-checks which sessions are mid-turn afterwards.
  void checkConnection() => transport?.checkConnection().then(
    (_) => unawaited(refreshActive()),
    onError: (Object _) {},
  );

  @override
  void dispose() {
    for (final reply in _replies) {
      reply.cancel();
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
    if (_selectedId == null) return;
    breadcrumbs('chat.thread.closed');
    _openGeneration++;
    _selectedId = null;
    notifyListeners();
  }

  void newThread() {
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
    breadcrumbs('chat.thread.selected', {
      'remote': _threads.any((t) => t.id == id && t.remote),
    });
    _openGeneration++;
    _openFailed = false;
    _selectedId = id;
    notifyListeners();
    final load = repository != null ? _loadMessages(id) : Future<void>.value();
    final thread = _threads.where((t) => t.id == id).firstOrNull;
    if (thread != null) {
      final profile = _profile;
      unawaited(
        load.then((_) {
          if (!disposed &&
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
    final transport = this.transport;
    if (transport == null || !thread.remote) return;
    if (thread.isReplying) return;
    _followUps(transport, thread, _profile);
  }

  final _followingIds = <String>{};

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
    if (transport == null || disposed) return;
    final generation = _loadGeneration;
    final refresh = ++_activeRefresh;
    final active = await transport.activeStatuses();
    if (disposed ||
        generation != _loadGeneration ||
        refresh != _activeRefresh) {
      return;
    }
    final working = <String>{
      for (final thread in _threads)
        if (active[thread.id] == 'working' || active[thread.id] == 'waiting')
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

  Future<List<SlashCommand>> slashCommands() =>
      transport?.slashCommands(
        threadId: selectedThread?.remote == true ? selectedThread!.id : null,
        profile: _profile,
      ) ??
      Future.value(const []);

  /// Runs a gateway command without putting it through prompt.submit or the
  /// reply queue. Display-only command output stays in this visit's chat.
  Future<bool> runSlashCommand(String command) async {
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
      if (disposed) return false;
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
          if (!disposed) {
            report('Bot Chat was compacted. Reopen the bot to continue.');
          }
          return true;
        }
        if (disposed || _profile != profile) return true;
        if (canonical.storedId != thread.id) {
          _retargetBoundThread(thread, canonical.storedId);
        }
        thread.botContext = bot.withStoredId(canonical.storedId);
        await _refreshAfterSlash(thread, profile);
      }
      if (result.prefill != null && wasRemote) {
        await _refreshAfterSlash(thread, profile);
      }
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
      if (result.prefill case final draft?) onPrefill?.call(draft);
      if (result.prompt case final prompt? when prompt.isNotEmpty) {
        _submitTo(
          thread,
          prompt,
          const [],
          displayText: result.display ?? command,
        );
      }
      return true;
    } on Object catch (error) {
      if (!disposed) report('Could not run $command: $error');
      return false;
    }
  }

  Future<void> _refreshAfterSlash(ChatThread thread, String? profile) async {
    final repository = this.repository;
    if (repository == null) return;
    await _loadingMessages[thread.id];
    try {
      final page = await repository.loadMessagePage(
        thread.id,
        profile: profile,
      );
      if (disposed || _profile != profile || !_threads.contains(thread)) return;
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
      notifyListeners();
    } on Object {
      if (!disposed) {
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
    final prompt = lastPromptText(thread);
    return transport != null &&
        _bound.contains(thread) &&
        !_undoing.contains(thread) &&
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
    final prompt = lastPromptText(thread);
    if (prompt == null || _undoing.contains(thread)) return;
    if (prompt.startsWith('/')) {
      unawaited(runSlashCommand(prompt));
      return;
    }
    if (canEditLastPrompt(thread) && _lastPrompt(thread)!.attachments.isEmpty) {
      try {
        await _undoLastTurn(thread, retry: true);
      } on Object catch (error) {
        if (!disposed) report(_undoFailure(error, 'try again'));
        return;
      }
      if (disposed) return;
    }
    _submitTo(thread, prompt, const []);
  }

  /// Takes the last prompt of [thread] back on the server and puts its text
  /// in the composer. Its files are not put back.
  Future<void> editLastPrompt(ChatThread thread) async {
    final prompt = lastPromptText(thread);
    if (prompt == null || !canEditLastPrompt(thread)) return;
    final bool undone;
    try {
      undone = await _undoLastTurn(thread);
    } on Object catch (error) {
      if (!disposed) report(_undoFailure(error, 'edit the prompt'));
      return;
    }
    if (disposed) return;
    if (!undone) {
      report("This Hermes server can't edit prompts. Update Hermes to edit.");
      return;
    }
    onPrefill?.call(prompt);
  }

  /// What to tell the user when taking back the last turn failed. The error
  /// itself is meant for developers, so only its kind goes to the crumb.
  String _undoFailure(Object error, String action) {
    final rejected = error is GatewayRpcException;
    breadcrumbs('chat.undo.failed', {
      'cause': rejected ? 'rejected' : 'unreachable',
    });
    return rejected
        ? "Hermes couldn't $action."
        : "Couldn't reach Hermes to $action. Check your connection.";
  }

  /// The threads whose last turn is being dropped, so a second tap does not
  /// drop the turn before it too.
  final _undoing = <ChatThread>{};

  /// Drops the last turn of [thread] on the server and then here. False when
  /// the server cannot undo.
  Future<bool> _undoLastTurn(ChatThread thread, {bool retry = false}) async {
    _undoing.add(thread);
    notifyListeners();
    final int? removed;
    try {
      removed = await transport!.undoLastTurn(
        thread.id,
        profile: _profile,
        retry: retry,
      );
    } finally {
      _undoing.remove(thread);
      if (!disposed) notifyListeners();
    }
    if (removed == null) return false;
    if (disposed) return true;
    final start = thread.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (start < 0) return true;
    thread.messages.removeRange(start, thread.messages.length);
    await controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    notifyListeners();
    return true;
  }

  /// The prompts waiting in [thread] for its reply to end.
  List<QueuedPrompt> queuedIn(ChatThread thread) =>
      List.unmodifiable(_queues[thread] ?? const <QueuedPrompt>[]);

  /// Whether [thread] holds queued prompts that no reply will send, because
  /// the last one was stopped or failed.
  bool queuePaused(ChatThread thread) =>
      !thread.isReplying && (_queues[thread]?.isNotEmpty ?? false);

  void removeQueued(ChatThread thread, QueuedPrompt prompt) {
    final queue = _queues[thread];
    if (queue == null || !queue.remove(prompt)) return;
    if (queue.isEmpty) _queues.remove(thread);
    notifyListeners();
  }

  /// Sends the first queued prompt of [thread] when no reply is pending
  /// there. One that cannot be sent stays first in the queue.
  void sendQueued(ChatThread thread) {
    _settleTimers.remove(thread)?.cancel();
    final queue = _queues[thread];
    if (thread.isReplying || queue == null || queue.isEmpty) return;
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

  /// After a reply ended normally, holds the queued prompts of [thread] until
  /// the session reports it settled. Two seconds without that report (an older
  /// Hermes, or a missed frame) send them anyway.
  void _awaitSettle(ChatThread thread) {
    if (thread.isReplying || (_queues[thread]?.isEmpty ?? true)) return;
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
    sendQueued(thread);
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
  bool submit(String typed, List<SharedFile> files) {
    return _submitTo(selectedThread, typed, files);
  }

  bool _submitTo(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
  }) {
    if (selected == null ||
        !selected.isReplying && !_queues.containsKey(selected)) {
      return _send(selected, typed, files, displayText: displayText);
    }
    if (_sizesOrExplain(files) == null) return false;
    (_queues[selected] ??= []).add(
      QueuedPrompt(typed, files, displayText: displayText),
    );
    (selected.isReplying || _settleTimers.containsKey(selected))
        ? notifyListeners()
        : sendQueued(selected);
    return true;
  }

  bool _send(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
    bool queued = false,
  }) {
    final sizes = _sizesOrExplain(files);
    if (sizes == null) return false;
    final attachments = <ChatAttachment>[];
    final outgoing = <OutgoingAttachment>[];
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

    final label = typed.isEmpty ? files.first.name : displayText ?? typed;
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
    if (thread.messages.isEmpty) {
      thread.title = label.length > 48 ? '${label.substring(0, 48)}…' : label;
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
    thread.messages.add(userMessage);
    for (final flyer in chatMessageToFlyer(userMessage)) {
      controllerFor(thread).insertMessage(flyer);
    }
    // A reply of its own: no stop asked before it is about it, and the answer
    // to one is no longer about this thread's current reply.
    _holds.remove(thread);
    _interrupts.remove(thread);
    _generations.update(thread, (n) => n + 1, ifAbsent: () => 1);
    final placeholder = _addPlaceholder(thread);
    thread.updatedAt = DateTime.now();
    notifyListeners();
    final transport = this.transport;
    if (transport == null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (disposed) return;
        _updateReply(thread, placeholder, () {
          placeholder.status = MessageStatus.sent;
          placeholder.content = buildMockReply(label);
        });
        sendQueued(thread);
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
      );
      unawaited(_attention.askForPermission());
    }
    return true;
  }

  /// Appends the assistant message a reply that is about to stream fills in.
  ChatMessage _addPlaceholder(ChatThread thread) {
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
  }) {
    late final StreamSubscription<ChatEvent> subscription;
    final profile = _profile;
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
      _replies.remove(subscription);
      breadcrumbs('chat.reply.ended', {'outcome': outcome(error)});
      _closeOwnTurn(
        thread,
        own,
        profile,
        failed: error != null,
        announceFailure: !reply.isPending,
      );
      if (folded) {
        // The prompt went into the turn already running, whose events follow
        // on the thread's follow-ups.
        if (error == null) {
          _followUps(transport, thread, profile);
          // A stop of the running turn in flight decides when the queue goes
          // on: its answer, or the end of that turn.
          if (_holdOf(thread) == _Hold.none) _awaitSettle(thread);
          unawaited(refreshActive());
        } else {
          _turnEnded(thread, halted: true);
          notifyListeners();
        }
      } else if (reply.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, reply, () => failReply(reply, error));
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
        if (drain) {
          if (settled) {
            sendQueued(thread);
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

    liveActivities?.begin(thread, profile: profile);
    breadcrumbs('chat.reply.started', {
      'queued': queued,
      'attachments': attachments.length,
    });
    subscription = transport
        .send(
          threadId: threadId,
          profile: profile,
          text: text,
          attachments: attachments,
          model: thread.modelChoice,
          queued: queued,
        )
        .listen(
          (event) {
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
          if (!thread.isCanonicalBotChat) thread.title = title;
          notifyListeners();
        case ThreadNeedsRefetch():
          _refetch.add(thread);
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
    _onReplyEvent(thread, open, event, profile, settles: false);
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
    final open = own.open;
    own.open = null;
    if (open == null || !open.isPending) return;
    _updateReply(
      thread,
      open,
      () => failed
          ? failReply(open, null)
          : applyReplyEvent(open, const SessionInfo(running: false)),
    );
    if (failed && announceFailure) {
      _announce(thread, const ReplyCompleted('', failed: true), profile);
    }
  }

  void _stopFollowing() {
    for (final subscription in _following) {
      subscription.cancel();
    }
    _following.clear();
    _followingIds.clear();
  }

  /// Hermes can chain turns on its own once a reply ended (a goal that goes
  /// on, a queued prompt); each one gets a reply of its own.
  void _followUps(ChatTransport transport, ChatThread thread, String? profile) {
    if (_profile != profile || !_threads.contains(thread)) return;
    final threadId = thread.id;
    if (!_followingIds.add(threadId)) return;
    ChatMessage? reply;
    late final StreamSubscription<ChatEvent> subscription;
    void end([Object? error]) {
      _following.remove(subscription);
      _followingIds.remove(thread.id);
      final pending = reply;
      if (pending != null && pending.isPending) {
        _turnEnded(thread, halted: true);
        _updateReply(thread, pending, () => failReply(pending, error));
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      }
    }

    subscription = transport
        .followUps(threadId, profile: profile)
        .listen(
          (event) {
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
            if (event is ReplyCompleted) {
              reply = null;
              final drain = _turnEnded(
                thread,
                halted: event.failed || event.stopped,
              );
              if (drain) _awaitSettle(thread);
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
              if (drain) sendQueued(thread);
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
    switch (event) {
      case SessionInfo(:final running):
        // The turn a stop in flight was aimed at ended with no reply open.
        if (running == false) _turnEnded(thread, idleOnly: true);
        _onSessionInfo(thread, event);
      case ThreadTitled(:final title):
        if (!thread.isCanonicalBotChat) thread.title = title;
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
  }) {
    var announced = event;
    switch (event) {
      case ThreadBound(:final threadId):
        _bindThread(thread, threadId);
      case ThreadTitled(:final title):
        if (!thread.isCanonicalBotChat) thread.title = title;
        notifyListeners();
      case ReplyStarted() || UnsolicitedEvent():
        break;
      case PromptFolded():
        _removeReply(thread, reply);
      case SessionInfo():
        final wasPending = reply.isPending;
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
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
    }
    _refetchIfIdle(thread);
    _announce(thread, announced, profile, notify: announce);
  }

  /// [profile] is the one the turn was sent under: the thread on screen only
  /// counts when the chat is still on that profile.
  /// Moves the chat's Live Activity along for [event], and posts the
  /// notification it deserves unless [notify] is false.
  void _announce(
    ChatThread thread,
    ChatEvent event,
    String? profile, {
    bool notify = true,
  }) {
    liveActivities?.onEvent(thread, event);
    if (!notify) return;
    _attention.announce(
      thread,
      event,
      selectedThreadId: profile == _profile ? _selectedId : null,
      profile: profile,
    );
  }

  /// Gives a thread created here the id the dashboard stored it under, so it
  /// stays one row and later sends continue that session.
  void _bindThread(ChatThread thread, String id) {
    if (_bound.contains(thread)) return;
    final controller = _chatControllers.remove(thread.id);
    if (_selectedId == thread.id) _selectedId = id;
    thread.id = id;
    thread.remote = true;
    _bound.add(thread);
    notifyListeners();
    if (controller != null) _chatControllers[id] = controller;
  }

  void _retargetBoundThread(ChatThread thread, String id) {
    if (thread.id == id) return;
    final previousId = thread.id;
    final controller = _chatControllers.remove(previousId);
    if (_selectedId == previousId) _selectedId = id;
    _unloaded.remove(previousId);
    _olderRows.remove(previousId);
    if (_followingIds.remove(previousId)) _followingIds.add(id);
    if (_active.remove(previousId)) _active.add(id);
    thread.id = id;
    if (controller != null) _chatControllers[id] = controller;
    notifyListeners();
  }

  void _updateReply(
    ChatThread thread,
    ChatMessage reply,
    void Function() edit,
  ) {
    final before = chatMessageToFlyer(reply);
    edit();
    notifyListeners();
    syncMessage(controllerFor(thread), before, chatMessageToFlyer(reply));
  }

  ChatMessage? _replyAwaiting(ChatThread thread, String requestId) {
    for (final message in thread.messages.reversed) {
      if (message.inputRequests.any((r) => r.requestId == requestId)) {
        return message;
      }
    }
    return null;
  }

  Future<void> answerApproval(
    ChatThread thread,
    String requestId,
    String choice,
  ) async {
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final accepted = await transport.answerApproval(requestId, choice);
    if (disposed) return;
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
      if (disposed) return;
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
        return;
      }
      // Nothing was running: the turn ended on its own. Only the stop that
      // held the queue lets it go on, and only when no other is in flight.
      if (others) return;
      switch (hold) {
        case _Hold.asked || _Hold.askedEnded:
          _setHold(thread, _Hold.none);
          sendQueued(thread);
        case _Hold.paused:
          _setHold(thread, _Hold.none);
        default:
          break;
      }
    } on Object {
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
            sendQueued(thread);
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
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final accepted = await transport.skipUnsupported(requestId, kind);
    if (disposed) return;
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
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final declined = identifier.isEmpty && password.isEmpty && code.isEmpty;
    final accepted = await transport.answerVault(
      requestId,
      kind,
      identifier: identifier,
      password: password,
      code: code,
    );
    if (disposed) return;
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
    final transport = this.transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final request = reply.inputRequests.firstWhere(
      (r) => r.requestId == requestId,
    );
    if (request is! ClarifyRequest) return;

    var accepted = true;
    if (answers.isEmpty) {
      accepted = await transport.answerClarify(requestId, const []);
    } else {
      for (final q in request.questions) {
        accepted = await transport.answerClarify(
          requestId,
          answers[q.qid] ?? const [],
          questionId: request.batch ? q.qid : null,
          multiSelect: q.multiSelect,
        );
        if (!accepted) break;
      }
    }
    if (disposed) return;
    _updateReply(
      thread,
      reply,
      () => accepted
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
