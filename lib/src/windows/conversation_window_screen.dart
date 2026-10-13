import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/attachments/attachment_source.dart';
import '../chat/attachments/plugin_attachment_source.dart';
import '../chat/chat_controller.dart';
import '../chat/queue_storage/queue_broker.dart';
import '../chat/queue_storage/queue_record.dart';
import '../chat/chat_models.dart';
import '../chat/chat_thread_bindings.dart';
import '../chat/chat_transport.dart';
import '../chat/hermes_chat_repository.dart';
import '../chat/widgets/thread_actions_menu.dart';
import '../models/hermes_models_repository.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../share/shared_item.dart';
import 'conversation_window_args.dart';
import 'desktop_conversation_windows.dart';
import 'widgets/conversation_window_toolbar.dart';

/// A conversation window's content on macOS: one chat, on the profile it was
/// opened from, with no sidebar.
class ConversationWindowScreen extends StatefulWidget {
  const ConversationWindowScreen({
    super.key,
    required this.args,
    this.draft,
    required this.link,
    required this.chat,
    this.models,
    this.transport,
    this.attachmentSource,
  });

  final ConversationWindowArgs args;

  /// What the main window's composer held for this chat when it handed the
  /// chat over.
  final ConversationDraft? draft;
  final ConversationWindowLink link;
  final HermesChatRepository chat;
  final HermesModelsRepository? models;
  final ChatTransport? transport;

  /// The platform's plugins unless a test supplies its own.
  final AttachmentSource? attachmentSource;

  @override
  State<ConversationWindowScreen> createState() =>
      _ConversationWindowScreenState();
}

class _ConversationWindowScreenState extends State<ConversationWindowScreen> {
  late final AttentionNotifier _attention;
  late final ChatController _chat;
  BrokerQueueStore? _protectedQueue;
  late final AttachmentSource _attachmentSource;
  late final _composerController = TextEditingController(
    text: widget.draft?.text,
  );
  final _composerFocus = FocusNode();
  late final _attachments = <SharedFile>[...?widget.draft?.files];
  final _latestReply = LatestReply();
  bool _queueSending = false;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Whether the chat was shown; once it is, losing it (deleted or archived)
  /// closes the window.
  bool _opened = false;
  ({String title, bool pinned})? _reported;

  ConversationWindowArgs get _args => widget.args;
  ConversationWindowLink get _link => widget.link;

  @override
  void initState() {
    super.initState();
    _attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final link = widget.link;
    if (link is QueueWindowLink && _args.ownerKey != null) {
      _protectedQueue = BrokerQueueStore(
        (link as QueueWindowLink).queueOperation,
        visibility: (link as QueueWindowLink).queueVisibility,
      );
    }
    _chat = ChatController(
      queueStore: _protectedQueue == null ? null : () async => _protectedQueue!,
      queueScope: _protectedQueue == null
          ? null
          : (thread, profile) =>
                _protectedQueue!.visible && thread.id == _args.threadId
                ? QueueScope(
                    serverKey: _args.baseUrl,
                    accountKey: _args.ownerKey!,
                    profile: profile,
                    conversationId: thread.id,
                  )
                : null,
      queueChanges: _protectedQueue,
      canShowQueues: _protectedQueue == null
          ? null
          : () => _protectedQueue!.visible,
      repository: widget.chat,
      models: widget.models,
      transport: widget.transport,
      attention: _attention,
      report: _showMessage,
    )..addListener(_changed);
    _attachmentSource = widget.attachmentSource ?? PluginAttachmentSource();
    unawaited(_chat.loadThreads(_args.profile));
    _chat.open(
      NotificationTarget(threadId: _args.threadId, profile: _args.profile),
      fetchMissing: true,
    );
    _subscriptions
      ..add(_link.commands.listen(_onCommand))
      ..add(_link.keyChanges.listen(_onKeyChanged));
    unawaited(_link.present(frameName: _args.frameName, title: _args.title));
  }

  ChatThread? get _thread {
    final selected = _chat.selectedThread;
    return selected?.id == _args.threadId ? selected : null;
  }

  void _changed() {
    if (!mounted) return;
    final thread = _thread;
    if (thread != null) {
      _opened = true;
      final state = (title: thread.title, pinned: thread.pinned);
      if (state != _reported) {
        _reported = state;
        _link.reportThread(thread.title, pinned: thread.pinned);
      }
    } else if (_opened && !_chat.loadingThreads) {
      unawaited(_link.close());
    }
    setState(() {});
  }

  /// A [ThreadAction], by name, from the main window's menu bar while this
  /// window is key. The main window closes windows natively.
  void _onCommand(String command) {
    final action = ThreadAction.values.asNameMap()[command];
    final thread = _thread;
    if (action == null || thread == null || !mounted) return;
    if (action == ThreadAction.pin) return _togglePin();
    unawaited(
      runThreadAction(
        context,
        action,
        thread: thread,
        housekeeping: _chat.housekeeping,
      ),
    );
  }

  void _onKeyChanged(bool key) {
    _link.reportFocus(key);
    if (!key) return;
    _chat.checkConnection();
    if (_thread != null) unawaited(_chat.refreshThread(_args.threadId));
  }

  void _togglePin() {
    final thread = _thread;
    final housekeeping = _chat.housekeeping;
    if (thread == null || housekeeping == null) return;
    unawaited(housekeeping.setPinned(thread, !thread.pinned));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send(String text) async {
    if (_queueSending) return;
    final typed = text.trim();
    final files = List.of(_attachments);
    if (typed.isEmpty && files.isEmpty) return;
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

  String? _subtitle() {
    final model = (_chat.modelChoice ?? _chat.modelOptions?.current)?.modelId;
    final parts = [?_args.profile, ?model];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  void dispose() {
    _protectedQueue?.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _chat
      ..removeListener(_changed)
      ..dispose();
    _attention.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _latestReply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final thread = _thread;
    _latestReply.follow(chat, thread);
    final toolbar = ConversationWindowToolbar(
      title: thread?.title ?? _args.title,
      subtitle: _subtitle(),
      pinned: thread?.pinned ?? false,
      onShowInMain: () => _link.showInMain(_args.threadId, _args.profile),
      onTogglePin: thread == null ? null : _togglePin,
      onShare: thread == null
          ? null
          : (anchor) => _link.share(threadTranscript(thread.messages), anchor),
      onAction: thread == null
          ? null
          : (action) => runThreadAction(
              context,
              action,
              thread: thread,
              housekeeping: chat.housekeeping,
            ),
    );
    final Widget body;
    if (thread != null) {
      body = boundChatThreadView(
        chat: chat,
        thread: thread,
        composerController: _composerController,
        composerFocus: _composerFocus,
        attachments: _attachments,
        attachmentSource: _attachmentSource,
        onAddAttachments: (files) {
          final added = newAttachments(_attachments, files);
          if (added.isEmpty) return;
          setState(() => _attachments.addAll(added));
        },
        onRemoveAttachment: (file) => setState(() => _attachments.remove(file)),
        onSend: _send,
        commandRunning: _queueSending,
        latestReply: _latestReply,
      );
    } else if (_opened) {
      // Gone (deleted or archived); the window is closing.
      body = const SizedBox.shrink();
    } else if (!chat.threadsFailed && !chat.openFailed) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not open this chat'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _link.close,
              child: const Text('Close Window'),
            ),
          ],
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): _link.close,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            _link.showMain,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true):
            _togglePin,
      },
      child: Scaffold(
        body: Column(
          children: [
            toolbar,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
