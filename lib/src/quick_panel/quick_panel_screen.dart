import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/attachments/attachment_source.dart';
import '../chat/attachments/attachment_surface.dart';
import '../chat/attachments/plugin_attachment_source.dart';
import '../chat/chat_controller.dart';
import '../chat/queue_storage/queue_broker.dart';
import '../chat/queue_storage/queue_record.dart';
import '../chat/chat_models.dart';
import '../chat/chat_thread_bindings.dart';
import '../chat/chat_transport.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/hermes_chat_repository.dart';
import '../chat/widgets/chat_composer.dart';
import '../chat/widgets/chat_composer_builder.dart';
import '../models/hermes_models_repository.dart';
import '../notifications/attention_notifier.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../share/shared_item.dart';
import '../voice/composer_dictation.dart';
import '../voice/dictation_controller.dart';
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
/// minutes on that profile, and otherwise starts empty. The unsent draft
/// and picked files stay across hides.
class QuickPanelScreen extends StatefulWidget {
  const QuickPanelScreen({
    super.key,
    required this.link,
    required this.chat,
    this.profiles,
    this.models,
    this.transport,
    this.attachmentSource,
    this.voiceRecorder,
    this.transcribeConnect,
    this.dictationSettings,
    this.onDevice,
    this.queueServerKey,
    this.queueOwnerKey,
  });

  final QuickPanelLink link;
  final String? queueServerKey;
  final String? queueOwnerKey;
  final HermesChatRepository chat;

  /// The sticky active profile, for when the main window names none.
  final HermesProfilesRepository? profiles;
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
  BrokerQueueStore? _protectedQueue;
  late final AttachmentSource _attachmentSource;
  ComposerDictation? _dictation;
  final _session = QuickPanelSession();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _attachments = <SharedFile>[];
  final _latestReply = LatestReply();
  bool _queueSending = false;
  final _compactKey = GlobalKey();
  final _subscriptions = <StreamSubscription<void>>[];

  /// The profile the main window named on the last show, and whether its
  /// chats loaded. Nothing is sent until they have: a send would go to the
  /// wrong profile.
  String? _profile;
  var _loaded = false;
  var _loading = false;
  var _loadFailed = false;

  /// A send asked for while the profile was loading; it goes out once the
  /// load is done.
  var _sendWhenLoaded = false;
  var _dictating = false;
  double? _height;

  QuickPanelLink get _link => widget.link;
  DictationController? get _voice => _dictation?.controller;

  @override
  void initState() {
    super.initState();
    _attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final link = widget.link;
    if (link is QueueWindowLink &&
        widget.queueOwnerKey != null &&
        widget.queueServerKey != null) {
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
                _protectedQueue!.visible &&
                    identical(thread, _chat.selectedThread)
                ? QueueScope(
                    serverKey: widget.queueServerKey!,
                    accountKey: widget.queueOwnerKey!,
                    profile: profile,
                    conversationId: thread.id,
                  )
                : null,
      queueChanges: _protectedQueue,
      canShowQueues: _protectedQueue == null
          ? null
          : () => _protectedQueue!.visible,
      repository: widget.chat,
      profiles: widget.profiles,
      models: widget.models,
      transport: widget.transport,
      attention: _attention,
      report: _showMessage,
    )..addListener(_changed);
    _attachmentSource = _HeldAttachmentSource(
      widget.attachmentSource ?? PluginAttachmentSource(),
      _link.hold,
    );
    if (widget.voiceRecorder case final recorder?) {
      _dictation = ComposerDictation(
        repository: widget.chat,
        connect:
            widget.transcribeConnect ??
            ([_ = const {}]) => Future.error(StateError('No live socket')),
        recorder: recorder,
        field: _composerController,
        profile: () => _chat.profile,
        settings: widget.dictationSettings,
        onDevice: widget.onDevice,
      );
      _voice!.addListener(_onVoice);
    }
    _subscriptions
      ..add(_link.shown.listen((_) => unawaited(_onShown())))
      ..add(_link.hidden.listen((_) => _voice?.cancel()))
      ..add(
        _link.commands.listen((command) {
          if (command == 'stopDictation') unawaited(_voice?.cancel());
        }),
      );
    // Listening first: presenting shows the panel.
    unawaited(_link.present());
  }

  Future<void> _onShown() async {
    _composerFocus.requestFocus();
    // Another engine may have changed it since the last show.
    unawaited(widget.dictationSettings?.load());
    _chat.checkConnection();
    final profile = await _link.currentProfile();
    if (!mounted) return;
    final thread = _chat.selectedThread;
    final continued = _session.resume(profile) && thread != null;
    _link.reportChat(continued: continued);
    if (continued) {
      if (thread.remote) unawaited(_chat.refreshThread(thread.id));
      return;
    }
    _chat.clearSelection();
    if (!_loaded || profile != _profile) await _load(profile);
  }

  Future<void> _load(String? profile) async {
    _profile = profile;
    setState(() {
      _loaded = false;
      _loading = true;
      _loadFailed = false;
    });
    await _chat.loadThreads(profile);
    if (!mounted || _profile != profile) return;
    final loaded = !_chat.threadsFailed;
    setState(() {
      _loading = false;
      _loaded = loaded;
      _loadFailed = !loaded;
    });
    if (!loaded) return;
    unawaited(_dictation?.refresh());
    if (_sendWhenLoaded) {
      _sendWhenLoaded = false;
      unawaited(_send(_composerController.text));
    }
  }

  /// Keeps the panel up while a recording starts (the first one asks for
  /// the microphone) and runs, and tells the main window to stop its own.
  void _onVoice() {
    final dictating = _voice!.busy;
    if (dictating != _dictating) {
      _dictating = dictating;
      unawaited(_link.hold(dictating));
      if (dictating) _link.reportDictating();
    }
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    // Reply events keep the chat going; reloads and model options do not.
    if (_chat.selectedThread?.isReplying ?? false) {
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

  Future<void> _send(String text) async {
    if (_queueSending) return;
    if (_loading) {
      _sendWhenLoaded = true;
      return;
    }
    if (!_loaded) return;
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
    _session.touch(_chat.profile);
    setState(() {
      _composerController.clear();
      _attachments.clear();
    });
  }

  void _addAttachments(List<SharedFile> files) {
    final added = newAttachments(_attachments, files);
    if (added.isEmpty) return;
    setState(() => _attachments.addAll(added));
  }

  void _escape() {
    final voice = _voice;
    if (voice != null && voice.busy) {
      unawaited(voice.cancel());
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
  /// coming forward does not count as the panel losing focus. A window that
  /// already showed the chat takes no draft, so the panel keeps it; a move
  /// that failed keeps the chat too.
  Future<void> _openInHermes() async {
    final thread = _savedThread;
    if (thread == null) return;
    final draft = ConversationDraft(
      text: _composerController.text,
      files: List.of(_attachments),
    );
    await _link.hide('open_in_hermes');
    final move = await _link.showInWindow(
      threadId: thread.id,
      profile: _chat.profile,
      title: thread.title,
      draft: draft.isEmpty ? null : draft,
    );
    if (!mounted || move == WindowMove.failed) return;
    _session.clear();
    _chat.clearSelection();
    if (move == WindowMove.opened) {
      setState(() {
        _composerController.clear();
        _attachments.clear();
      });
    }
  }

  DictationView? _dictationView() {
    final voice = _voice;
    if (voice == null || !voice.available) return null;
    return DictationView.of(
      voice,
      onSend: () => sendAfterDictation(voice, _composerController, _send, null),
    );
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
    _voice?.removeListener(_onVoice);
    _dictation?.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _latestReply.dispose();
    super.dispose();
  }

  Widget _compact() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_loadFailed) _LoadFailed(onRetry: () => unawaited(_load(_profile))),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AttachmentSurface(
          source: _attachmentSource,
          onAdd: _addAttachments,
          builder: (context, openMenu) => ChatComposer(
            controller: _composerController,
            focusNode: _composerFocus,
            onSend: _send,
            commandRunning:
                _queueSending ||
                (_chat.selectedThread != null &&
                    _chat.queueBusy(_chat.selectedThread!)),
            queueView: protectedQueueView(_chat, _chat.selectedThread),
            onAttach: openMenu,
            attachments: _attachments,
            onRemoveAttachment: (file) =>
                setState(() => _attachments.remove(file)),
            modelPill: composerModelPill(_chat),
            dictation: _dictationView(),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final thread = chat.selectedThread;
    _latestReply.follow(chat, thread);
    _fit();
    final saved = _savedThread;
    final open = saved == null ? null : () => unawaited(_openInHermes());
    final Widget content;
    if (thread != null && _expanded) {
      content = QuickPanelView(
        title: saved?.title,
        onOpenInHermes: open,
        child: boundChatThreadView(
          chat: chat,
          thread: thread,
          composerController: _composerController,
          composerFocus: _composerFocus,
          dictation: _voice,
          attachments: _attachments,
          attachmentSource: _attachmentSource,
          onAddAttachments: _addAttachments,
          onRemoveAttachment: (file) =>
              setState(() => _attachments.remove(file)),
          onSend: _send,
          commandRunning: _queueSending,
          latestReply: _latestReply,
          welcome: false,
        ),
      );
    } else {
      // Unbounded in height, so the measured size is what the content
      // needs, not what the panel has now.
      content = OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: NotificationListener<SizeChangedLayoutNotification>(
          // A taller prompt or a row of attachments grows the panel.
          onNotification: (_) {
            _fit();
            return true;
          },
          child: SizeChangedLayoutNotifier(
            key: _compactKey,
            child: QuickPanelView(
              title: saved?.title,
              onOpenInHermes: open,
              compact: true,
              child: _compact(),
            ),
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
      child: Scaffold(backgroundColor: Colors.transparent, body: content),
    );
  }
}

/// The panel's chats did not load, so it cannot send yet.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Could not load your chats.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

/// Holds the panel open while a file dialog has the focus.
class _HeldAttachmentSource implements AttachmentSource {
  _HeldAttachmentSource(this._source, this._hold);

  final AttachmentSource _source;
  final Future<void> Function(bool held) _hold;

  @override
  List<AttachOrigin> get origins => _source.origins;

  @override
  bool get acceptsDrops => _source.acceptsDrops;

  @override
  Future<List<SharedFile>> pick(AttachOrigin origin) async {
    await _hold(true);
    try {
      return await _source.pick(origin);
    } finally {
      unawaited(_hold(false));
    }
  }

  @override
  Widget dropTarget({
    required Widget child,
    required ValueChanged<bool> onHover,
    required ValueChanged<List<SharedFile>> onDrop,
  }) => _source.dropTarget(child: child, onHover: onHover, onDrop: onDrop);

  @override
  Future<bool> hasFilesToPaste() => _source.hasFilesToPaste();

  @override
  Future<List<SharedFile>> pasted() => _source.pasted();

  @override
  Future<List<SharedFile>> inserted(KeyboardInsertedContent content) =>
      _source.inserted(content);
}
