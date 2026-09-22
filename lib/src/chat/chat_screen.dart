import 'dart:async';
import 'dart:io';

import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../bots/bots_screen.dart';
import '../bots/hermes_bots_repository.dart';
import '../mcp/hermes_mcp_repository.dart';
import '../mcp/mcp_servers_screen.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../plugins/hermes_plugin_manager_repository.dart';
import '../plugins/plugins_screen.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/profiles_screen.dart';
import '../screens/home_screen.dart';
import '../share/share_controller.dart';
import '../share/shared_item.dart';
import '../skills/hermes_skills_repository.dart';
import '../skills/skills_screen.dart';
import 'attachments/attachment_source.dart';
import 'attachments/attachment_surface.dart';
import 'attachments/plugin_attachment_source.dart';
import 'chat_controller_sync.dart';
import 'chat_message_kinds.dart';
import 'chat_message_mapper.dart';
import 'chat_models.dart';
import 'chat_open_requests.dart';
import 'chat_reply.dart';
import 'chat_theme.dart';
import 'chat_transport.dart';
import 'gateway/gateway_connection.dart';
import 'gateway/hermes_gateway_transport.dart';
import 'hermes_chat_repository.dart';
import 'mock_chat_data.dart';
import 'thread_housekeeping.dart';
import 'widgets/chat_builders.dart';
import 'widgets/chat_composer_builder.dart';
import 'widgets/thread_sidebar.dart';

const _couldNotOpenChat = 'Could not open that chat.';
const _couldNotStop = 'Could not stop the reply. Try again.';
const _stillReplying =
    'Hermes is still replying. Wait for it to finish, or answer its request.';

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
    this.bots,
    this.skills,
    this.plugins,
    this.mcp,
    this.onShowChat,
    this.attachmentSource,
    this.openRequests,
    this.onOpenJob,
    this.navigation,
  });

  final HermesChatRepository? repository;
  final ChatTransport? transport;
  final HermesProfilesRepository? profiles;
  final HermesBotsRepository? bots;
  final HermesSkillsRepository? skills;
  final HermesPluginManagerRepository? plugins;
  final HermesMcpRepository? mcp;

  /// Asks the host to bring the chat to the front, for a notification tap or
  /// shared content that arrives while something else is shown.
  final VoidCallback? onShowChat;

  /// Where the attach control, drops and paste get their files; the platform's
  /// plugins unless a test supplies its own.
  final AttachmentSource? attachmentSource;

  /// Where another destination asks the chat to open a session.
  final ChatOpenRequests? openRequests;

  /// Called for a tapped notification that is about a scheduled task, which
  /// the chat cannot show.
  final void Function(NotificationTarget target)? onOpenJob;

  /// The shell's destinations. A wide layout shows them at the top of the
  /// thread sidebar; a narrow one has its own bottom bar.
  final Widget? navigation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const double _wideBreakpoint = 900;

  late List<ChatThread> _threads;
  HermesChatRepository? _repository;
  HermesProfilesRepository? _profiles;
  HermesBotsRepository? _bots;
  HermesSkillsRepository? _skills;
  HermesPluginManagerRepository? _plugins;
  HermesMcpRepository? _mcp;
  ChatTransport? _transport;
  HermesGatewayTransport? _ownedTransport;
  ThreadHousekeeping? _housekeeping;
  bool _loadingThreads = false;
  bool _threadsFailed = false;

  /// The profile whose sessions are listed; null leaves it to the dashboard.
  String? _profile;
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
  final _composerController = TextEditingController();
  final _emptyController = InMemoryChatController();
  final _chatControllers = <String, InMemoryChatController>{};
  final List<SharedFile> _attachments = [];
  late final AttachmentSource _attachmentSource;
  late final ShareController _share;
  late final AttentionNotifier _attention;
  NotificationTarget? _pendingTap;

  /// Whether the held tap came from another destination, which may fetch a
  /// session the loaded threads do not hold, unlike a notification tap.
  bool _pendingFetch = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The reply of the open thread that can be asked again: its last message,
  /// once that is a finished reply.
  final _latestReplyId = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.openRequests?.addListener(_onOpenRequest);
    _attention = AttentionNotifier(
      service: _maybeRead<NotificationService>(),
      settings: _maybeRead<NotificationSettings>(),
      onOpen: _openFromNotification,
    );
    final api = context.read<AuthController>().api;
    _repository =
        widget.repository ??
        (api == null ? null : HermesChatRepository(api.raw));
    _profiles =
        widget.profiles ??
        (api == null ? null : HermesProfilesRepository(api.raw));
    _bots = widget.bots ?? (api == null ? null : HermesBotsRepository(api.raw));
    _skills =
        widget.skills ?? (api == null ? null : HermesSkillsRepository(api.raw));
    _plugins =
        widget.plugins ??
        (api == null ? null : HermesPluginManagerRepository(api.raw));
    _mcp = widget.mcp ?? (api == null ? null : HermesMcpRepository(api.raw));
    _transport = widget.transport;
    if (_transport == null && api != null) {
      final auth = context.read<AuthController>();
      final telemetry = _maybeRead<MessagingConnectionTracer>();
      _transport = _ownedTransport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: auth.baseUrl!,
          authRequired: auth.status?.authRequired ?? true,
          api: api,
          telemetry: telemetry,
        ),
        telemetry: telemetry,
      );
    }
    if (_repository == null) {
      _threads = buildMockThreads();
      _selectedId = _threads.isNotEmpty ? _threads.first.id : null;
    } else {
      _threads = [];
      _housekeeping = ThreadHousekeeping(
        repository: _repository!,
        threads: () => _threads,
        profile: () => _profile,
        changed: () {
          if (mounted) setState(() {});
        },
        report: _showMessage,
        removed: _threadRemoved,
      );
      _loadThreads();
    }
    _attachmentSource = widget.attachmentSource ?? PluginAttachmentSource();
    _share = context.read<ShareController>()..addListener(_onShared);
    _absorbShared();
  }

  /// Lists the threads of [profile], or of the sticky active profile when
  /// none is given. The dashboard does not scope sessions to that profile by
  /// itself, so it is passed on every read.
  Future<void> _loadThreads([String? profile]) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loadingThreads = true;
      _threadsFailed = false;
    });
    try {
      profile ??= await _activeProfile();
      final first = await _repository!.loadThreadPage(profile: profile);
      var launched = await _attention.takeLaunchTarget();
      if (launched != null && launched.isJob) {
        widget.onOpenJob?.call(launched);
        launched = null;
      }
      if (!mounted || generation != _loadGeneration) return;
      final held = _pendingTap;
      final fetchHeld = held != null && _pendingFetch;
      final launch = held ?? launched;
      _pendingTap = null;
      _pendingFetch = false;
      final threads = _housekeeping!.begin(first);
      // Another profile can hold a different session under the same id.
      _stopFollowing();
      for (final controller in _chatControllers.values) {
        controller.dispose();
      }
      _chatControllers.clear();
      setState(() {
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
      });
      if (launch != null) {
        // A held tap already put Chat in front when it arrived.
        if (held == null) widget.onShowChat?.call();
        if (_selectedId != launch.threadId) {
          if (fetchHeld) {
            _openMissing(launch);
          } else {
            _showMessage(_couldNotOpenChat);
          }
        }
      }
      if (_selectedId != null) _loadMessages(_selectedId!);
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingThreads = false;
        _threadsFailed = true;
      });
    }
  }

  /// The sticky active profile, or null when the server has none to report:
  /// no repository, or a server without the profiles route (404). Any other
  /// failure throws, so the caller does not list or send unscoped.
  Future<String?> _activeProfile() async {
    try {
      return (await _profiles?.loadActive())?.active;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _loadMessages(String id) async {
    if (!_unloaded.remove(id)) return;
    final generation = _loadGeneration;
    try {
      final page = await _repository!.loadMessagePage(id, profile: _profile);
      if (!mounted || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      setState(() {
        thread.messages.addAll(page.messages);
        if (page.hasMore) _olderRows[id] = page.rows;
      });
      await _controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      if (generation != _loadGeneration) return;
      _unloaded.add(id);
      if (!mounted) return;
      _showMessage('Could not load this chat');
    }
  }

  Future<void> _loadOlder(String id) async {
    final offset = _olderRows[id];
    if (offset == null) return;
    final generation = _loadGeneration;
    try {
      final page = await _repository!.loadMessagePage(
        id,
        profile: _profile,
        offset: offset,
      );
      if (!mounted || generation != _loadGeneration) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      final held = {for (final m in thread.messages) m.id};
      final older = [
        for (final m in page.messages)
          if (!held.contains(m.id)) m,
      ];
      setState(() {
        thread.messages.insertAll(0, older);
        if (page.hasMore && page.rows > 0) {
          _olderRows[id] = offset + page.rows;
        } else {
          _olderRows.remove(id);
        }
      });
      if (older.isEmpty) return;
      await _controllerFor(thread).insertAllMessages(
        [for (final m in older) ...chatMessageToFlyer(m)],
        index: 0,
        animated: false,
      );
    } on Object {
      if (mounted && generation == _loadGeneration) {
        _showMessage('Could not load earlier messages');
      }
    }
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Whether [target] names a chat on [profile]. A thread id is only unique
  /// within a profile, so one posted under another profile is not ours. A
  /// notification from an earlier build carries no profile; it still matches
  /// on its thread id alone.
  static bool _isOnProfile(NotificationTarget? target, String? profile) =>
      target != null && (target.profile == null || target.profile == profile);

  void _openFromNotification(NotificationTarget target) {
    if (target.isJob) return widget.onOpenJob?.call(target);
    _open(target, fetchMissing: false);
  }

  /// Another destination asked for a session. Unlike a notification tap, it
  /// is fetched when the loaded threads do not hold it, on its own profile.
  void _onOpenRequest() {
    final target = widget.openRequests?.take();
    if (target != null) _open(target, fetchMissing: true);
  }

  void _open(NotificationTarget target, {required bool fetchMissing}) {
    widget.onShowChat?.call();
    if (_loadingThreads) {
      _pendingTap = target;
      _pendingFetch = fetchMissing;
    } else if (_isOnProfile(target, _profile) &&
        _threads.any((t) => t.id == target.threadId)) {
      _selectThread(target.threadId, closeDrawer: false);
      _scaffoldKey.currentState?.closeDrawer();
    } else if (fetchMissing) {
      _openMissing(target);
    } else {
      _showMessage(_couldNotOpenChat);
    }
  }

  /// Opens a chat the loaded threads do not hold: one on another profile, or
  /// older than the first page of sessions.
  Future<void> _openMissing(NotificationTarget target) async {
    final repository = _repository;
    final profile = target.profile ?? _profile;
    if (repository == null) return _showMessage(_couldNotOpenChat);
    try {
      if (profile != _profile) await _loadThreads(profile);
      if (!mounted) return;
      // A failed switch leaves the old profile's threads on screen.
      if (profile != _profile) return _showMessage(_couldNotOpenChat);
      if (!_threads.any((t) => t.id == target.threadId)) {
        final thread = await repository.loadThread(
          target.threadId,
          profile: profile,
        );
        if (!mounted) return;
        if (thread == null) return _showMessage(_couldNotOpenChat);
        setState(() {
          _threads.insert(0, thread);
          _bound.add(thread);
          _unloaded.add(thread.id);
        });
      }
      _selectThread(target.threadId, closeDrawer: false);
      _scaffoldKey.currentState?.closeDrawer();
    } on Object {
      if (mounted) _showMessage(_couldNotOpenChat);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Moves on to the first remaining thread when the open one is archived or
  /// deleted.
  void _threadRemoved(ChatThread thread) {
    if (_selectedId != thread.id) return;
    _selectedId = _threads.firstOrNull?.id;
    if (_selectedId != null) _loadMessages(_selectedId!);
  }

  void _onShared() {
    if (!_share.hasPending) return;
    widget.onShowChat?.call();
    setState(_absorbShared);
  }

  void _absorbShared() {
    final items = _share.take();
    if (items.isEmpty) return;

    final shared = items.whereType<SharedText>().map((i) => i.text).join('\n');
    if (shared.isNotEmpty) _appendToComposer(shared);
    _attachments.addAll(items.whereType<SharedFile>());
  }

  /// Adds [text] under whatever the user has already typed, sending nothing.
  void _appendToComposer(String text) {
    final draft = _composerController.text;
    final combined = draft.isEmpty ? text : '$draft\n$text';
    _composerController.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  void _addAttachments(List<SharedFile> files) {
    final added = files.where((f) => !_attachments.contains(f)).toList();
    if (added.isEmpty) return;
    setState(() => _attachments.addAll(added));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _transport?.checkConnection().then((_) {}, onError: (Object _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.openRequests?.removeListener(_onOpenRequest);
    _share.removeListener(_onShared);
    _attention.dispose();
    for (final reply in _replies) {
      reply.cancel();
    }
    _stopFollowing();
    _ownedTransport?.close();
    _composerController.dispose();
    _latestReplyId.dispose();
    _emptyController.dispose();
    for (final controller in _chatControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ChatThread? get _selectedThread {
    for (final thread in _threads) {
      if (thread.id == _selectedId) return thread;
    }
    return null;
  }

  InMemoryChatController _controllerFor(ChatThread? thread) {
    if (thread == null) return _emptyController;
    return _chatControllers.putIfAbsent(
      thread.id,
      () => InMemoryChatController(messages: chatThreadToFlyer(thread)),
    );
  }

  void _newThread() {
    final thread = ChatThread(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'New chat',
      updatedAt: DateTime.now(),
    );
    setState(() {
      _threads.insert(0, thread);
      _selectedId = thread.id;
    });
    _closeDrawerIfNarrow();
  }

  void _selectThread(String id, {bool closeDrawer = true}) {
    setState(() => _selectedId = id);
    if (closeDrawer) _closeDrawerIfNarrow();
    if (_repository != null) _loadMessages(id);
  }

  void _openProfiles() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          repository: _profiles,
          chatProfile: _profile,
          onSwitched: _repository == null ? null : _loadThreads,
        ),
      ),
    );
  }

  void _openBots() {
    _closeDrawerIfNarrow();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => BotsScreen(repository: _bots)));
  }

  /// Skills asks for a message to be drafted when the user wants the agent to
  /// delete a skill; it is put in the composer for the user to send.
  Future<void> _openSkills() async {
    _closeDrawerIfNarrow();
    final draft = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            SkillsScreen(repository: _skills, chatProfile: _profile),
      ),
    );
    if (draft == null || !mounted) return;
    widget.onShowChat?.call();
    setState(() => _appendToComposer(draft));
  }

  void _openPlugins() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PluginsScreen(repository: _plugins)),
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

  void _closeDrawerIfNarrow() {
    if (MediaQuery.sizeOf(context).width < _wideBreakpoint) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  /// Loaded messages are keyed `<session>-<row id>`, so a count of the
  /// thread's messages would collide with them.
  String _newMessageId(ChatThread thread) =>
      '${thread.id}-local-${_sentMessages++}';

  /// The package composer reports attachments-only sends as an empty [text].
  void _send(String text) {
    final typed = text.trim();
    final files = List.of(_attachments);
    if (typed.isEmpty && files.isEmpty) return;
    _submit(typed, files, fromComposer: true);
  }

  /// The text of the last prompt of [thread], or null when it had none (it
  /// was only files) or there is no prompt.
  String? _lastPromptText(ChatThread thread) {
    for (final message in thread.messages.reversed) {
      if (message.role != ChatRole.user) continue;
      return message.content.isEmpty ? null : message.content;
    }
    return null;
  }

  /// Sends the text of the last prompt again as a new turn. Its files are not
  /// sent again.
  void _retry(ChatThread thread) {
    final prompt = _lastPromptText(thread);
    if (prompt != null) _submit(prompt, const [], fromComposer: false);
  }

  void _submit(
    String typed,
    List<SharedFile> files, {
    required bool fromComposer,
  }) {
    final selected = _selectedThread;
    if (selected != null && selected.isReplying) {
      _showMessage(_stillReplying);
      return;
    }
    final sizes = _sizesOrExplain(files);
    if (sizes == null) return;
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
      _controllerFor(thread).insertMessage(flyer);
    }
    final placeholder = _addPlaceholder(thread);
    setState(() {
      thread.updatedAt = DateTime.now();
      if (fromComposer) {
        _composerController.clear();
        _attachments.clear();
      }
    });
    final transport = _transport;
    if (transport == null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _updateReply(thread, placeholder, () {
          placeholder.status = MessageStatus.sent;
          placeholder.content = buildMockReply(label);
        });
      });
    } else {
      _streamReply(transport, thread, placeholder, typed, outgoing, threadId);
      unawaited(_attention.askForPermission());
    }
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
      _controllerFor(thread).insertMessage(flyer);
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
        _showMessage(attachmentFailedMessage(file.name, kAttachmentUnreadable));
        return null;
      }
      if (size > kMaxAttachmentBytes) {
        _showMessage(attachmentTooLargeMessage(file.name));
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
                setState(() => thread.title = event.title);
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
        setState(() => thread.title = title);
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
    setState(() {
      if (_selectedId == thread.id) _selectedId = id;
      thread.id = id;
      thread.remote = true;
      _bound.add(thread);
    });
    if (controller != null) _chatControllers[id] = controller;
  }

  void _updateReply(
    ChatThread thread,
    ChatMessage reply,
    void Function() edit,
  ) {
    final before = chatMessageToFlyer(reply);
    setState(edit);
    syncMessage(_controllerFor(thread), before, chatMessageToFlyer(reply));
  }

  ChatMessage? _replyAwaiting(ChatThread thread, String requestId) {
    for (final message in thread.messages.reversed) {
      if (message.inputRequests.any((r) => r.requestId == requestId)) {
        return message;
      }
    }
    return null;
  }

  Future<void> _answerApproval(
    ChatThread thread,
    String requestId,
    String choice,
  ) async {
    final transport = _transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final accepted = await transport.answerApproval(requestId, choice);
    if (!mounted) return;
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordApproval(reply, requestId, choice)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> _stopReply(ChatThread thread) async {
    try {
      await _transport?.stopReply(thread.id);
    } on Object {
      _showMessage(_couldNotStop);
    }
  }

  Future<void> _skipUnsupported(
    ChatThread thread,
    String requestId,
    UnsupportedKind kind,
  ) async {
    final transport = _transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final accepted = await transport.skipUnsupported(requestId, kind);
    if (!mounted) return;
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordSkipped(reply, requestId)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> _answerClarify(
    ChatThread thread,
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final transport = _transport;
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
    if (!mounted) return;
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordClarifyAnswers(reply, requestId, answers)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  /// The notifier changes after the frame: the action bars listening to it
  /// are built in this one.
  void _followLatestReply(ChatThread? thread) {
    final last = thread?.messages.lastOrNull;
    final id =
        last != null && last.role == ChatRole.assistant && !last.isPending
        ? last.id
        : null;
    if (_latestReplyId.value == id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _latestReplyId.value = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingThreads) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_threadsFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your chats'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadThreads, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final selected = _selectedThread;
        _followLatestReply(selected);
        ThreadSidebar buildSidebar({Widget? navigation}) => ThreadSidebar(
          navigation: navigation,
          threads: _threads,
          selectedId: _selectedId,
          onSelect: _selectThread,
          onNewThread: _newThread,
          housekeeping: _housekeeping,
          onOpenProfiles: _profiles == null ? null : _openProfiles,
          onOpenBots: _bots == null ? null : _openBots,
          onOpenSkills: _skills == null ? null : _openSkills,
          onOpenPlugins: _plugins == null ? null : _openPlugins,
          onOpenMcp: _mcp == null ? null : _openMcp,
        );

        return Scaffold(
          key: _scaffoldKey,
          drawer: isWide ? null : Drawer(width: 280, child: buildSidebar()),
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(selected?.title ?? 'Hermes'),
                  actions: [const _ConnectionInfoButton()],
                ),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 280,
                  child: buildSidebar(navigation: widget.navigation),
                ),
              if (isWide) const VerticalDivider(width: 1),
              Expanded(
                child: _ThreadView(
                  thread: selected,
                  chatController: _controllerFor(selected),
                  composerController: _composerController,
                  attachments: _attachments,
                  attachmentSource: _attachmentSource,
                  onAddAttachments: _addAttachments,
                  onRemoveAttachment: (file) =>
                      setState(() => _attachments.remove(file)),
                  onSend: _send,
                  latestReplyId: _latestReplyId,
                  onRetry: selected == null || _lastPromptText(selected) == null
                      ? null
                      : () => _retry(selected),
                  showTopBar: isWide,
                  onLoadOlder:
                      selected == null || !_olderRows.containsKey(selected.id)
                      ? null
                      : () => _loadOlder(selected.id),
                  onAnswerApproval: selected == null
                      ? null
                      : (id, choice) => _answerApproval(selected, id, choice),
                  onAnswerClarify: selected == null
                      ? null
                      : (id, answers) => _answerClarify(selected, id, answers),
                  onSkipUnsupported: selected == null
                      ? null
                      : (id, kind) => _skipUnsupported(selected, id, kind),
                  onStop: selected == null || _transport == null
                      ? null
                      : () => _stopReply(selected),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.thread,
    required this.chatController,
    required this.composerController,
    required this.attachments,
    required this.attachmentSource,
    required this.onAddAttachments,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.latestReplyId,
    required this.showTopBar,
    this.onRetry,
    this.onLoadOlder,
    this.onAnswerApproval,
    this.onAnswerClarify,
    this.onSkipUnsupported,
    this.onStop,
  });

  final ChatThread? thread;
  final InMemoryChatController chatController;
  final TextEditingController composerController;
  final List<SharedFile> attachments;
  final AttachmentSource attachmentSource;
  final ValueChanged<List<SharedFile>> onAddAttachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final ValueChanged<String> onSend;
  final ValueListenable<String?> latestReplyId;
  final VoidCallback? onRetry;
  final bool showTopBar;
  final Future<void> Function()? onLoadOlder;
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onAnswerClarify;
  final Future<void> Function(String requestId, UnsupportedKind kind)?
  onSkipUnsupported;
  final Future<void> Function()? onStop;

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<AuthController>().identity;
    final builders =
        buildChatBuilders(
          onPickPrompt: onSend,
          greetingName: identity?.displayName,
          latestReplyId: latestReplyId,
          onRetry: onRetry,
          onLoadOlder: onLoadOlder,
          onAnswerApproval: onAnswerApproval,
          onAnswerClarify: onAnswerClarify,
          onSkipUnsupported: onSkipUnsupported,
        ).copyWith(
          composerBuilder: buildChatComposer(
            controller: composerController,
            attachments: attachments,
            onRemoveAttachment: onRemoveAttachment,
            onStop: thread?.isReplying == true ? onStop : null,
          ),
        );

    return Column(
      children: [
        if (showTopBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    thread?.title ?? 'Hermes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const _ConnectionInfoButton(),
              ],
            ),
          ),
        if (showTopBar) const Divider(height: 1),
        Expanded(
          child: AttachmentSurface(
            source: attachmentSource,
            onAdd: onAddAttachments,
            builder: (context, openAttachMenu) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SizedBox.expand(
                  child: FlyerMaterialScope(
                    child: SelectionArea(
                      child: Chat(
                        // The controller too: after a profile switch the same
                        // id names another thread.
                        key: ValueKey((thread?.id, chatController)),
                        chatController: chatController,
                        currentUserId: kUserAuthorId,
                        resolveUser: (id) async => User(id: id),
                        onMessageSend: onSend,
                        onAttachmentTap: openAttachMenu,
                        theme: buildChatTheme(Theme.of(context)),
                        builders: builders,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionInfoButton extends StatelessWidget {
  const _ConnectionInfoButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Connection details',
      icon: const Icon(Icons.info_outline),
      onPressed: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HomeScreen()));
      },
    );
  }
}
