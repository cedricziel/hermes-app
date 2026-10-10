import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/attachments/attachment_source.dart';
import '../chat/attachments/attachment_surface.dart';
import '../chat/attachments/plugin_attachment_source.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/hermes_chat_repository.dart';
import '../chat/widgets/chat_composer.dart';
import '../chat/widgets/chat_composer_builder.dart';
import '../chat/widgets/chat_thread_view.dart';
import '../chat/widgets/message_actions.dart' show TurnActionStatus;
import '../models/hermes_models_repository.dart';
import '../models/widgets/composer_model_pill.dart';
import '../notifications/attention_notifier.dart';
import '../share/shared_item.dart';
import '../voice/composer_dictation.dart';
import '../voice/dictation_settings.dart';
import '../voice/dictation_view.dart';
import '../voice/on_device_speech.dart';
import '../voice/voice_recorder.dart';
import '../windows/conversation_window_args.dart';
import '../windows/desktop_conversation_windows.dart';
import 'quick_panel_session.dart';
import 'widgets/quick_panel_view.dart';

/// The quick panel's content (macOS): one chat on the main window's current
/// profile. Each show continues the chat when it was used in the last five
/// minutes on that profile, and otherwise starts empty.
class QuickPanelScreen extends StatefulWidget {
  const QuickPanelScreen({
    super.key,
    required this.link,
    required this.chat,
    this.models,
    this.transport,
    this.attachmentSource,
    this.voiceRecorder,
    this.transcribeConnect,
    this.dictationSettings,
    this.onDevice,
  });

  final QuickPanelLink link;
  final HermesChatRepository chat;
  final HermesModelsRepository? models;
  final ChatTransport? transport;

  /// The platform's plugins unless a test supplies its own.
  final AttachmentSource? attachmentSource;

  /// The microphone; no dictation without one.
  final VoiceRecorder? voiceRecorder;

  /// Opens the live transcription socket; without one, recordings are
  /// uploaded.
  final MixedSocketConnect? transcribeConnect;
  final DictationSettings? dictationSettings;
  final OnDeviceSpeech? onDevice;

  @override
  State<QuickPanelScreen> createState() => _QuickPanelScreenState();
}

class _QuickPanelScreenState extends State<QuickPanelScreen> {
  late final AttentionNotifier _attention;
  late final ChatController _chat;
  late final AttachmentSource _attachmentSource;
  ComposerDictation? _dictation;
  final _session = QuickPanelSession();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _attachments = <SharedFile>[];
  final _latestReplyId = ValueNotifier<String?>(null);
  final _turnActionStatus = ValueNotifier(TurnActionStatus.idle);
  final _compactKey = GlobalKey();
  final _subscriptions = <StreamSubscription<void>>[];

  /// Whether threads were loaded for the profile the chat is on.
  var _loaded = false;
  double? _height;

  QuickPanelLink get _link => widget.link;

  @override
  void initState() {
    super.initState();
    _attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    _chat = ChatController(
      repository: widget.chat,
      models: widget.models,
      transport: widget.transport,
      attention: _attention,
      report: _showMessage,
    )..addListener(_changed);
    _attachmentSource = widget.attachmentSource ?? PluginAttachmentSource();
    if (widget.voiceRecorder case final recorder?) {
      _dictation = ComposerDictation(
        repository: widget.chat,
        connect:
            widget.transcribeConnect ??
            ([_ = const {}]) => Future.error(StateError('No live socket')),
        recorder: recorder,
        field: _composerController,
        settings: widget.dictationSettings,
        onDevice: widget.onDevice,
      );
      _dictation!.controller.addListener(_rebuild);
    }
    _subscriptions
      ..add(_link.shown.listen((_) => unawaited(_onShown())))
      ..add(_link.hidden.listen((_) => _dictation?.controller.cancel()));
    // Listening first: presenting shows the panel.
    unawaited(_link.present());
  }

  Future<void> _onShown() async {
    _composerFocus.requestFocus();
    final profile = await _link.currentProfile();
    if (!mounted) return;
    final continued = _session.resume(profile) && _chat.selectedThread != null;
    _link.reportChat(continued: continued);
    if (continued) return;
    if (!_loaded || profile != _chat.profile) {
      _loaded = true;
      await _chat.loadThreads(profile);
      if (!mounted) return;
      unawaited(_dictation?.configure(profile));
    }
    _startEmpty();
  }

  void _startEmpty() {
    _chat.clearSelection();
    setState(() {
      _composerController.clear();
      _attachments.clear();
    });
    _composerFocus.requestFocus();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    if (_chat.selectedThread case final thread?
        when thread.messages.isNotEmpty) {
      _session.touch(_chat.profile);
    }
    setState(() {});
  }

  bool get _expanded => _chat.selectedThread?.messages.isNotEmpty ?? false;

  /// Fits the panel to the composer before the first send, and to the chat
  /// after it.
  void _fit() {
    // A streaming reply rebuilds on every delta; the expanded size is fixed.
    if (_expanded && _height == QuickPanelView.expandedHeight) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final double height;
      if (_expanded) {
        height = QuickPanelView.expandedHeight;
      } else {
        final box =
            _compactKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        height = box.size.height;
      }
      if (height == _height) return;
      _height = height;
      unawaited(_link.resize(height));
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _send(String text) {
    final typed = text.trim();
    final files = List.of(_attachments);
    if (typed.isEmpty && files.isEmpty) return;
    if (!_chat.submit(typed, files)) return;
    setState(() {
      _composerController.clear();
      _attachments.clear();
    });
  }

  void _addAttachments(List<SharedFile> files) {
    final added = files.where((f) => !_attachments.contains(f)).toList();
    if (added.isEmpty) return;
    setState(() => _attachments.addAll(added));
  }

  void _escape() {
    final dictation = _dictation?.controller;
    if (dictation != null && dictation.busy) {
      unawaited(dictation.cancel());
      return;
    }
    unawaited(_link.hide('escape'));
  }

  ChatThread? get _savedThread => switch (_chat.selectedThread) {
    final thread? when thread.remote => thread,
    _ => null,
  };

  /// Moves the chat, with what the composer holds, to a conversation window
  /// and starts the next show empty. The panel hides first, so the window
  /// coming forward does not count as the panel losing focus.
  Future<void> _openInHermes() async {
    final thread = _savedThread;
    if (thread == null) return;
    final draft = ConversationDraft(
      text: _composerController.text,
      files: List.of(_attachments),
    );
    await _link.hide('open_in_hermes');
    await _link.showInWindow(
      threadId: thread.id,
      profile: _chat.profile,
      title: thread.title,
      draft: draft.isEmpty ? null : draft,
    );
    if (!mounted) return;
    _session.clear();
    _startEmpty();
  }

  void _followLatestReply(ChatThread? thread) {
    final id = latestFinishedReplyId(thread);
    final status = thread == null
        ? TurnActionStatus.idle
        : _chat.turnActionStatus(thread);
    if (_latestReplyId.value == id && _turnActionStatus.value == status) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _latestReplyId.value = id;
      _turnActionStatus.value = status;
    });
  }

  Widget? _modelPill() {
    final options = _chat.modelOptions;
    if (options == null || options.providers.isEmpty) return null;
    return ComposerModelPill(
      options: options,
      choice: _chat.modelChoice,
      onChanged: _chat.chooseModel,
    );
  }

  DictationView? _dictationView() {
    final dictation = _dictation?.controller;
    if (dictation == null || !dictation.available) return null;
    return DictationView.of(
      dictation,
      onSend: () =>
          sendAfterDictation(dictation, _composerController, _send, null),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _chat
      ..removeListener(_changed)
      ..dispose();
    _attention.dispose();
    _dictation?.controller.removeListener(_rebuild);
    _dictation?.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _latestReplyId.dispose();
    _turnActionStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final thread = chat.selectedThread;
    _followLatestReply(thread);
    _fit();
    final Widget body;
    if (thread != null && _expanded) {
      body = ChatThreadView(
        thread: thread,
        chatController: chat.controllerFor(thread),
        composerController: _composerController,
        composerFocus: _composerFocus,
        dictation: _dictation?.controller,
        attachments: _attachments,
        attachmentSource: _attachmentSource,
        onAddAttachments: _addAttachments,
        onRemoveAttachment: (file) => setState(() => _attachments.remove(file)),
        onSend: _send,
        onPickStarter: (_) {},
        latestReplyId: _latestReplyId,
        turnActionStatus: _turnActionStatus,
        welcome: false,
        modelPill: _modelPill(),
        botContext: thread.botContext,
        onLoadOlder: chat.hasOlder(thread.id)
            ? () => chat.loadOlder(thread.id)
            : null,
        onRetry: chat.lastPromptText(thread) == null
            ? null
            : () => chat.retry(thread),
        onAnswerApproval: (id, choice) =>
            chat.answerApproval(thread, id, choice),
        onAnswerClarify: (id, answers) =>
            chat.answerClarify(thread, id, answers),
        onSkipUnsupported: (id, kind) => chat.skipUnsupported(thread, id, kind),
        onAnswerVault:
            (id, kind, {identifier = '', password = '', code = ''}) =>
                chat.answerVaultRequest(
                  thread,
                  id,
                  kind,
                  identifier: identifier,
                  password: password,
                  code: code,
                ),
        onStop: chat.transport == null ? null : () => chat.stopReply(thread),
        queued: chat.queuedIn(thread),
        onRemoveQueued: (prompt) => chat.removeQueued(thread, prompt),
        onSendQueued: chat.queuePaused(thread)
            ? () => chat.sendQueued(thread)
            : null,
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AttachmentSurface(
          source: _attachmentSource,
          onAdd: _addAttachments,
          builder: (context, openMenu) => ChatComposer(
            controller: _composerController,
            focusNode: _composerFocus,
            onSend: _send,
            onAttach: openMenu,
            attachments: _attachments,
            onRemoveAttachment: (file) =>
                setState(() => _attachments.remove(file)),
            modelPill: _modelPill(),
            dictation: _dictationView(),
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
            unawaited(_openInHermes()),
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.topCenter,
          child: KeyedSubtree(
            key: _expanded ? null : _compactKey,
            child: QuickPanelView(
              title: _savedThread?.title,
              onOpenInHermes: _savedThread == null
                  ? null
                  : () => unawaited(_openInHermes()),
              compact: !_expanded,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
