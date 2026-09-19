import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../screens/home_screen.dart';
import '../share/share_controller.dart';
import '../share/shared_item.dart';
import 'chat_models.dart';
import 'mock_chat_data.dart';
import 'widgets/chat_composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thread_sidebar.dart';
import 'widgets/welcome_view.dart';

/// The chat screen — Hermes's main destination once connected and signed
/// in. A design preview of the assistant-ui-style thread UI: a persistent
/// thread rail beside a centered message column, backed by mock data until
/// the dashboard's session API is wired in (see `mock_chat_data.dart`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const double _wideBreakpoint = 900;

  late List<ChatThread> _threads;
  String? _selectedId;
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  final List<SharedFile> _attachments = [];
  late final ShareController _share;

  @override
  void initState() {
    super.initState();
    _threads = buildMockThreads();
    _selectedId = _threads.isNotEmpty ? _threads.first.id : null;
    _share = context.read<ShareController>()..addListener(_onShared);
    _absorbShared();
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
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatThread? get _selectedThread {
    for (final thread in _threads) {
      if (thread.id == _selectedId) return thread;
    }
    return null;
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
  }

  void _closeDrawerIfNarrow() {
    if (MediaQuery.sizeOf(context).width < _wideBreakpoint) {
      Navigator.of(context).maybePop();
    }
  }

  void _send([String? text]) {
    final typed = (text ?? _composerController.text).trim();
    final attached = _attachments.isEmpty
        ? ''
        : 'Attached: ${_attachments.map((f) => f.name).join(', ')}';
    final content = [typed, attached].where((s) => s.isNotEmpty).join('\n\n');
    if (content.isEmpty) return;

    final thread =
        _selectedThread ??
        ChatThread(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: content,
          updatedAt: DateTime.now(),
        );
    if (_selectedThread == null) {
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

    setState(() {
      thread.messages.add(userMessage);
      thread.messages.add(placeholder);
      thread.updatedAt = DateTime.now();
      _composerController.clear();
      _attachments.clear();
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        placeholder.status = MessageStatus.sent;
        placeholder.content = buildMockReply(content);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final sidebar = ThreadSidebar(
          threads: _threads,
          selectedId: _selectedId,
          onSelect: _selectThread,
          onNewThread: _newThread,
        );

        return Scaffold(
          drawer: isWide ? null : Drawer(width: 280, child: sidebar),
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(_selectedThread?.title ?? 'Hermes'),
                  actions: [const _ConnectionInfoButton()],
                ),
          body: Row(
            children: [
              if (isWide) SizedBox(width: 280, child: sidebar),
              if (isWide) const VerticalDivider(width: 1),
              Expanded(
                child: _ThreadView(
                  thread: _selectedThread,
                  scrollController: _scrollController,
                  composerController: _composerController,
                  composerFocus: _composerFocus,
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
    required this.scrollController,
    required this.composerController,
    required this.composerFocus,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onSend,
    required this.showTopBar,
  });

  final ChatThread? thread;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final FocusNode composerFocus;
  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final void Function([String?]) onSend;
  final bool showTopBar;

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<AuthController>().identity;
    final hasMessages = thread != null && thread!.messages.isNotEmpty;

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
          child: hasMessages
              ? ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  itemCount: thread!.messages.length,
                  itemBuilder: (context, index) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: MessageBubble(message: thread!.messages[index]),
                      ),
                    );
                  },
                )
              : WelcomeView(
                  greetingName: identity?.displayName,
                  onPick: (prompt) => onSend(prompt),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListenableBuilder(
                listenable: composerController,
                builder: (context, _) => ChatComposer(
                  controller: composerController,
                  focusNode: composerFocus,
                  canSend:
                      composerController.text.trim().isNotEmpty ||
                      attachments.isNotEmpty,
                  attachments: attachments,
                  onRemoveAttachment: onRemoveAttachment,
                  onSend: onSend,
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
