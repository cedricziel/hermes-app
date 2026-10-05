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
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../share/shared_item.dart';
import 'chat_controller_sync.dart';
import 'chat_message_mapper.dart';
import 'chat_models.dart';
import 'chat_reply.dart';
import 'chat_transport.dart';
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
    required this.report,
    this.onShowChat,
    this.onOpenJob,
    this.onOpened,
    this.onPrefill,
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

  ThreadHousekeeping? housekeeping;

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
  Future<void> loadThreads([String? profile]) async {
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
      if (profile != _profile) {
        _modelOptions = null;
        _newChatModel = null;
        search?.clear();
      }
      _profile = profile;
      unawaited(_loadModelOptions(profile, generation));
      _threads = threads;
      _unloaded
        ..clear()
        ..addAll(threads.map((t) => t.id));
      _olderRows.clear();
      _queues.clear();
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
            report(_couldNotOpenChat);
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
      report(_couldNotOpenChat);
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
    if (repository == null) return report(_couldNotOpenChat);
    try {
      if (profile != _profile) await loadThreads(profile);
      if (disposed || generation != _openGeneration) return;
      // A failed switch leaves the old profile's threads on screen.
      if (profile != _profile) return report(_couldNotOpenChat);
      if (!_threads.any((t) => t.id == target.threadId)) {
        final thread = await repository.loadThread(
          target.threadId,
          profile: profile,
        );
        if (disposed || generation != _openGeneration) return;
        if (thread == null) return report(_couldNotOpenChat);
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
        notifyListeners();
      }
      select(target.threadId);
      onOpened?.call();
    } on Object {
      if (!disposed) report(_couldNotOpenChat);
    }
  }

  Future<void> openBot(BotChatContext context) async {
    final generation = ++_openGeneration;
    onShowChat?.call();
    final repository = this.repository;
    if (repository == null) return report(_couldNotOpenChat);
    final profile = context.bot.name;
    try {
      if (_loadingThreads || _profile != profile) await loadThreads(profile);
      if (disposed || generation != _openGeneration) return;
      if (_profile != profile) return report(_couldNotOpenChat);
      var thread = _threads.where((t) => t.id == context.storedId).firstOrNull;
      if (thread == null) {
        thread = await repository.loadThread(
          context.storedId,
          profile: profile,
        );
        if (disposed || generation != _openGeneration) return;
        if (thread == null) return report(_couldNotOpenChat);
        _threads.insert(0, thread);
        _bound.add(thread);
        _unloaded.add(thread.id);
      }
      thread.botContext = context;
      thread.title = BotModeChatRepository.title;
      select(thread.id);
      onOpened?.call();
    } on Object {
      if (!disposed && generation == _openGeneration) report(_couldNotOpenChat);
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

  void newThread() {
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
    _openGeneration++;
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
        final canonical = await botChats!.open(bot.bot);
        if (disposed || _profile != profile) return true;
        if (canonical.storedId != thread.id) {
          _bindThread(thread, canonical.storedId);
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

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? lastPromptText(ChatThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.user) continue;
      final text = message.submittedText ?? message.content;
      return text.isEmpty ? null : text;
    }
    return null;
  }

  /// Sends the text of the last prompt again as a new turn. Its files are not
  /// sent again.
  void retry(ChatThread thread) {
    final prompt = lastPromptText(thread);
    if (prompt == null) return;
    if (prompt.startsWith('/')) {
      unawaited(runSlashCommand(prompt));
    } else {
      submit(prompt, const []);
    }
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
    final queue = _queues[thread];
    if (thread.isReplying || queue == null || queue.isEmpty) return;
    final next = queue.removeAt(0);
    if (queue.isEmpty) _queues.remove(thread);
    if (!_send(thread, next.text, next.files, displayText: next.displayText)) {
      (_queues[thread] ??= []).insert(0, next);
    }
    notifyListeners();
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
    selected.isReplying ? notifyListeners() : sendQueued(selected);
    return true;
  }

  bool _send(
    ChatThread? selected,
    String typed,
    List<SharedFile> files, {
    String? displayText,
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
      _streamReply(transport, thread, placeholder, typed, outgoing, threadId);
      unawaited(_attention.askForPermission());
    }
    return true;
  }

  /// Appends the assistant message a reply that is about to stream fills in.
  ChatMessage _addPlaceholder(ChatThread thread) {
    final placeholder = ChatMessage(
      id: _newMessageId(thread),
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.thinking,
    );
    thread.messages.add(placeholder);
    for (final flyer in chatMessageToFlyer(placeholder)) {
      controllerFor(thread).insertMessage(flyer);
    }
    return placeholder;
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
    String? threadId,
  ) {
    late final StreamSubscription<ChatEvent> subscription;
    final profile = _profile;
    var failed = false;
    var stopped = false;
    void end([Object? error]) {
      _replies.remove(subscription);
      if (reply.isPending) {
        _updateReply(thread, reply, () => failReply(reply, error));
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      } else if (error == null && !failed) {
        _followUps(transport, thread, profile);
        if (!stopped) sendQueued(thread);
        unawaited(refreshActive());
      } else {
        // The queue is left paused; the screen shows it.
        notifyListeners();
      }
    }

    subscription = transport
        .send(
          threadId: threadId,
          profile: profile,
          text: text,
          attachments: attachments,
          model: thread.modelChoice,
        )
        .listen(
          (event) {
            if (event is ReplyCompleted) {
              failed = event.failed;
              stopped = event.stopped;
            }
            _onReplyEvent(thread, reply, event, profile);
          },
          onError: end,
          onDone: end,
          cancelOnError: true,
        );
    _replies.add(subscription);
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
    if (!_followingIds.add(thread.id)) return;
    ChatMessage? reply;
    late final StreamSubscription<ChatEvent> subscription;
    void end([Object? error]) {
      _following.remove(subscription);
      _followingIds.remove(thread.id);
      final pending = reply;
      if (pending != null && pending.isPending) {
        _updateReply(thread, pending, () => failReply(pending, error));
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      }
    }

    subscription = transport
        .followUps(thread.id, profile: profile)
        .listen(
          (event) {
            if (event is ReplyStarted && reply == null) {
              reply = _addPlaceholder(thread);
            }
            final current = reply;
            if (current == null) {
              if (event is ThreadTitled) {
                if (!thread.isCanonicalBotChat) thread.title = event.title;
                notifyListeners();
              }
              return;
            }
            _onReplyEvent(thread, current, event, profile);
            if (event is ReplyCompleted) {
              reply = null;
              if (!event.failed && !event.stopped) sendQueued(thread);
              unawaited(refreshActive());
            }
          },
          onError: end,
          onDone: end,
          cancelOnError: true,
        );
    _following.add(subscription);
  }

  void _onReplyEvent(
    ChatThread thread,
    ChatMessage reply,
    ChatEvent event,
    String? profile,
  ) {
    switch (event) {
      case ThreadBound(:final threadId):
        _bindThread(thread, threadId);
      case ThreadTitled(:final title):
        if (!thread.isCanonicalBotChat) thread.title = title;
        notifyListeners();
      case ReplyStarted():
        break;
      case ReplyDelta() ||
          ReplyCheckpoint() ||
          ReasoningUpdated() ||
          ToolPreparing() ||
          ToolStarted() ||
          ToolFinished() ||
          SubagentUpdated() ||
          ReplyCompleted() ||
          ApprovalRequested() ||
          ClarifyRequested() ||
          VaultRequested() ||
          UnsupportedRequested() ||
          InputRequestExpired():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
    }
    _announce(thread, event, profile);
  }

  /// [profile] is the one the turn was sent under: the thread on screen only
  /// counts when the chat is still on that profile.
  void _announce(ChatThread thread, ChatEvent event, String? profile) =>
      _attention.announce(
        thread,
        event,
        selectedThreadId: profile == _profile ? _selectedId : null,
        profile: profile,
      );

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

  Future<void> stopReply(ChatThread thread) async {
    final pending = [
      for (final reply in thread.messages)
        if (reply.isPending) reply,
    ];
    try {
      final stopped = await transport?.stopReply(thread.id, profile: _profile);
      if (disposed || stopped != false) return;
      // The server has no turn left to interrupt. A completion was missed by
      // this listener, so release the stale pending reply and composer.
      for (final reply in pending.where((reply) => reply.isPending)) {
        _updateReply(
          thread,
          reply,
          () => applyReplyEvent(reply, const ReplyCompleted('', stopped: true)),
        );
      }
    } on Object {
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
