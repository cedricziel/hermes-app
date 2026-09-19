import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/profiles_screen.dart';
import '../screens/home_screen.dart';
import '../share/share_controller.dart';
import '../share/shared_item.dart';
import 'chat_message_kinds.dart';
import 'chat_message_mapper.dart';
import 'chat_models.dart';
import 'chat_theme.dart';
import 'hermes_chat_repository.dart';
import 'mock_chat_data.dart';
import 'widgets/chat_builders.dart';
import 'widgets/chat_composer_builder.dart';
import 'widgets/thread_sidebar.dart';

/// The chat screen — Hermes's main destination once connected and signed
/// in: an assistant-ui-style thread UI with a persistent thread rail beside a
/// centered message column.
///
/// Threads and messages are read from the dashboard through [repository]
/// (defaulting to the signed-in [AuthController.api]). Sending is still a
/// canned reply, since the dashboard has no route for it yet. Without any
/// repository the screen shows mock data (see `mock_chat_data.dart`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.repository, this.profiles});

  final HermesChatRepository? repository;
  final HermesProfilesRepository? profiles;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const double _wideBreakpoint = 900;

  late List<ChatThread> _threads;
  HermesChatRepository? _repository;
  HermesProfilesRepository? _profiles;
  bool _loadingThreads = false;
  bool _threadsFailed = false;
  final _unloaded = <String>{};
  String? _selectedId;
  final _composerController = TextEditingController();
  final _emptyController = InMemoryChatController();
  final _chatControllers = <String, InMemoryChatController>{};
  final List<SharedFile> _attachments = [];
  late final ShareController _share;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthController>().api;
    _repository =
        widget.repository ??
        (api == null ? null : HermesChatRepository(api.raw));
    _profiles =
        widget.profiles ??
        (api == null ? null : HermesProfilesRepository(api.raw));
    if (_repository == null) {
      _threads = buildMockThreads();
      _selectedId = _threads.isNotEmpty ? _threads.first.id : null;
    } else {
      _threads = [];
      _loadThreads();
    }
    _share = context.read<ShareController>()..addListener(_onShared);
    _absorbShared();
  }

  Future<void> _loadThreads() async {
    setState(() {
      _loadingThreads = true;
      _threadsFailed = false;
    });
    try {
      final threads = await _repository!.loadThreads();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _unloaded
          ..clear()
          ..addAll(threads.map((t) => t.id));
        _loadingThreads = false;
        _selectedId = threads.isNotEmpty ? threads.first.id : null;
      });
      if (_selectedId != null) _loadMessages(_selectedId!);
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingThreads = false;
        _threadsFailed = true;
      });
    }
  }

  Future<void> _loadMessages(String id) async {
    if (!_unloaded.remove(id)) return;
    try {
      final messages = await _repository!.loadMessages(id);
      if (!mounted) return;
      final thread = _threads.where((t) => t.id == id).firstOrNull;
      if (thread == null) return;
      setState(() => thread.messages.addAll(messages));
      await _controllerFor(thread).setMessages(chatThreadToFlyer(thread));
    } on Object {
      _unloaded.add(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load this chat')));
    }
  }

  void _onShared() => setState(_absorbShared);

  void _absorbShared() {
    final items = _share.take();
    if (items.isEmpty) return;

    final shared = items.whereType<SharedText>().map((i) => i.text).join('\n');
    if (shared.isNotEmpty) {
      final draft = _composerController.text;
      final text = draft.isEmpty ? shared : '$draft\n$shared';
      _composerController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _attachments.addAll(items.whereType<SharedFile>());
  }

  @override
  void dispose() {
    _share.removeListener(_onShared);
    _composerController.dispose();
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

  void _selectThread(String id) {
    setState(() => _selectedId = id);
    _closeDrawerIfNarrow();
    if (_repository != null) _loadMessages(id);
  }

  void _openProfiles() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilesScreen(repository: _profiles)),
    );
  }

  void _closeDrawerIfNarrow() {
    if (MediaQuery.sizeOf(context).width < _wideBreakpoint) {
      Navigator.of(context).maybePop();
    }
  }

  /// The package composer reports attachments-only sends as an empty [text].
  void _send(String text) {
    final typed = text.trim();
    final attached = _attachments.isEmpty
        ? ''
        : 'Attached: ${_attachments.map((f) => f.name).join(', ')}';
    final content = [typed, attached].where((s) => s.isNotEmpty).join('\n\n');
    if (content.isEmpty) return;

    final selected = _selectedThread;
    final thread =
        selected ??
        ChatThread(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: content,
          updatedAt: DateTime.now(),
        );
    if (selected == null) {
      _threads.insert(0, thread);
      _selectedId = thread.id;
    }
    if (thread.messages.isEmpty) {
      thread.title = content.length > 48
          ? '${content.substring(0, 48)}…'
          : content;
    }

    final userMessage = ChatMessage(
      id: '${thread.id}-${thread.messages.length}',
      role: ChatRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
    final placeholder = ChatMessage(
      id: '${thread.id}-${thread.messages.length + 1}',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.thinking,
    );

    final chatController = _controllerFor(thread);
    for (final message in [userMessage, placeholder]) {
      thread.messages.add(message);
      for (final flyer in chatMessageToFlyer(message)) {
        chatController.insertMessage(flyer);
      }
    }
    setState(() {
      thread.updatedAt = DateTime.now();
      _composerController.clear();
      _attachments.clear();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      // The reply takes the placeholder's slot, not the end of the list, so
      // overlapping sends keep each reply beside its prompt.
      final pending = chatMessageToFlyer(placeholder);
      final slot = chatController.messages.indexWhere(
        (m) => m.id == pending.first.id,
      );
      for (final flyer in pending) {
        chatController.removeMessage(flyer);
      }
      setState(() {
        placeholder.status = MessageStatus.sent;
        placeholder.content = buildMockReply(content);
      });
      final reply = chatMessageToFlyer(placeholder);
      for (final (i, flyer) in reply.indexed) {
        chatController.insertMessage(flyer, index: slot < 0 ? null : slot + i);
      }
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
        final sidebar = ThreadSidebar(
          threads: _threads,
          selectedId: _selectedId,
          onSelect: _selectThread,
          onNewThread: _newThread,
          onOpenProfiles: _profiles == null ? null : _openProfiles,
        );

        return Scaffold(
          drawer: isWide ? null : Drawer(width: 280, child: sidebar),
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(selected?.title ?? 'Hermes'),
                  actions: [const _ConnectionInfoButton()],
                ),
          body: Row(
            children: [
              if (isWide) SizedBox(width: 280, child: sidebar),
              if (isWide) const VerticalDivider(width: 1),
              Expanded(
                child: _ThreadView(
                  thread: selected,
                  chatController: _controllerFor(selected),
                  composerController: _composerController,
                  attachments: _attachments,
                  onRemoveAttachment: (file) =>
                      setState(() => _attachments.remove(file)),
                  onSend: _send,
                  showTopBar: isWide,
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
    required this.onRemoveAttachment,
    required this.onSend,
    required this.showTopBar,
  });

  final ChatThread? thread;
  final InMemoryChatController chatController;
  final TextEditingController composerController;
  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final ValueChanged<String> onSend;
  final bool showTopBar;

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<AuthController>().identity;
    final builders =
        buildChatBuilders(
          onPickPrompt: onSend,
          greetingName: identity?.displayName,
        ).copyWith(
          composerBuilder: buildChatComposer(
            controller: composerController,
            attachments: attachments,
            onRemoveAttachment: onRemoveAttachment,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox.expand(
                child: FlyerMaterialScope(
                  child: SelectionArea(
                    child: Chat(
                      key: ValueKey(thread?.id),
                      chatController: chatController,
                      currentUserId: kUserAuthorId,
                      resolveUser: (id) async => User(id: id),
                      onMessageSend: onSend,
                      theme: buildChatTheme(Theme.of(context)),
                      builders: builders,
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
