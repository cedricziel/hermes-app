import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;

import '../core/safe_notifier.dart';
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
import 'thread_housekeeping.dart';

const _couldNotOpenChat = 'Could not open that chat.';
const _couldNotStop = 'Could not stop the reply. Try again.';
const _stillReplying =
    'Hermes is still replying. Wait for it to finish, or answer its request.';

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
    this.transport,
    required this._attention,
    required this.report,
    this.onShowChat,
    this.onOpenJob,
    this.onOpened,
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
      );
    }
  }

  final HermesChatRepository? repository;
  final HermesProfilesRepository? profiles;
  final ChatTransport? transport;
  final AttentionNotifier _attention;

  /// Tells the user something went wrong.
  final ValueChanged<String> report;

  /// Asks the host to bring the chat to the front.
  final VoidCallback? onShowChat;

  /// Called for a notification about a scheduled task.
  final void Function(NotificationTarget target)? onOpenJob;

  /// Called after a chat asked for from outside was selected.
  final VoidCallback? onOpened;

  ThreadHousekeeping? housekeeping;

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
      for (final controller in _chatControllers.values) {
        controller.dispose();
      }
      _chatControllers.clear();
      _profile = profile;
      _threads = threads;
      _unloaded
        ..clear()
        ..addAll(threads.map((t) => t.id));
      _olderRows.clear();
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
      if (_selectedId != null) unawaited(_loadMessages(_selectedId!));
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

  Future<void> _loadMessages(String id) async {
    if (!_unloaded.remove(id)) return;
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
    onShowChat?.call();
    if (_loadingThreads) {
      _pendingTap = target;
      _pendingFetch = fetchMissing;
    } else if (_isOnProfile(target, _profile) &&
        _threads.any((t) => t.id == target.threadId)) {
      select(target.threadId);
      onOpened?.call();
    } else if (fetchMissing) {
      _openMissing(target);
    } else {
      report(_couldNotOpenChat);
    }
  }

  /// Opens a chat the loaded threads do not hold: one on another profile, or
  /// older than the first page of sessions.
  Future<void> _openMissing(NotificationTarget target) async {
    final repository = this.repository;
    final profile = target.profile ?? _profile;
    if (repository == null) return report(_couldNotOpenChat);
    try {
      if (profile != _profile) await loadThreads(profile);
      if (disposed) return;
      // A failed switch leaves the old profile's threads on screen.
      if (profile != _profile) return report(_couldNotOpenChat);
      if (!_threads.any((t) => t.id == target.threadId)) {
        final thread = await repository.loadThread(
          target.threadId,
          profile: profile,
        );
        if (disposed) return;
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

  /// Moves on to the first remaining thread when the open one is archived or
  /// deleted.
  void _threadRemoved(ChatThread thread) {
    if (_selectedId != thread.id) return;
    _selectedId = _threads.firstOrNull?.id;
    if (_selectedId != null) _loadMessages(_selectedId!);
  }

  /// Asks the transport to drop a connection the OS killed during sleep.
  void checkConnection() =>
      transport?.checkConnection().then((_) {}, onError: (Object _) {});

  @override
  void dispose() {
    for (final reply in _replies) {
      reply.cancel();
    }
    _stopFollowing();
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
    final thread = ChatThread(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAt: DateTime.now(),
    );
    _threads.insert(0, thread);
    _selectedId = thread.id;
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
    if (repository != null) _loadMessages(id);
  }

  /// Loaded messages are keyed `<session>-<row id>`, so a count of the
  /// thread's messages would collide with them.
  String _newMessageId(ChatThread thread) =>
      '${thread.id}-local-${_sentMessages++}';

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? lastPromptText(ChatThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.user) continue;
      return message.content.isEmpty ? null : message.content;
    }
    return null;
  }

  /// Sends the text of the last prompt again as a new turn. Its files are not
  /// sent again.
  void retry(ChatThread thread) {
    final prompt = lastPromptText(thread);
    if (prompt != null) submit(prompt, const []);
  }

  /// Sends [typed] and [files] in the selected thread, or in a new one, and
  /// streams the reply into it. Returns false when nothing was sent, after
  /// telling the user why.
  bool submit(String typed, List<SharedFile> files) {
    final selected = selectedThread;
    if (selected != null && selected.isReplying) {
      report(_stillReplying);
      return false;
    }
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

    final label = typed.isEmpty ? files.first.name : typed;
    final thread =
        selected ??
        ChatThread(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: label,
          updatedAt: DateTime.now(),
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
      content: typed,
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
    void end([Object? error]) {
      _replies.remove(subscription);
      if (reply.isPending) {
        _updateReply(thread, reply, () => failReply(reply, error));
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      } else if (error == null && !failed) {
        _followUps(transport, thread, profile);
      }
    }

    subscription = transport
        .send(
          threadId: threadId,
          profile: profile,
          text: text,
          attachments: attachments,
        )
        .listen(
          (event) {
            if (event is ReplyCompleted && event.failed) failed = true;
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
  }

  /// Hermes can chain turns on its own once a reply ended (a goal that goes
  /// on, a queued prompt); each one gets a reply of its own.
  void _followUps(ChatTransport transport, ChatThread thread, String? profile) {
    ChatMessage? reply;
    late final StreamSubscription<ChatEvent> subscription;
    void end([Object? error]) {
      _following.remove(subscription);
      final pending = reply;
      if (pending != null && pending.isPending) {
        _updateReply(thread, pending, () => failReply(pending, error));
        _announce(thread, const ReplyCompleted('', failed: true), profile);
      }
    }

    subscription = transport
        .followUps(thread.id)
        .listen(
          (event) {
            if (event is ReplyStarted) reply = _addPlaceholder(thread);
            final current = reply;
            if (current == null) {
              if (event is ThreadTitled) {
                thread.title = event.title;
                notifyListeners();
              }
              return;
            }
            _onReplyEvent(thread, current, event, profile);
            if (event is ReplyCompleted) reply = null;
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
        thread.title = title;
        notifyListeners();
      case ReplyStarted():
        break;
      case ReplyDelta() ||
          ReplyCheckpoint() ||
          ReasoningUpdated() ||
          ToolStarted() ||
          ToolFinished() ||
          ReplyCompleted() ||
          ApprovalRequested() ||
          ClarifyRequested() ||
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
    try {
      await transport?.stopReply(thread.id);
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
