import 'dart:async';

import 'package:hermes_app/src/theme/breakpoints.dart';

import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController, User;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';

import '../auth/auth_controller.dart';
import '../bots/bots_screen.dart';
import '../bots/hermes_bots_repository.dart';
import '../mcp/hermes_mcp_repository.dart';
import '../mcp/mcp_servers_screen.dart';
import '../models/hermes_models_repository.dart';
import '../models/widgets/composer_model_pill.dart';
import '../notifications/attention_notifier.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../plugins/hermes_plugin_manager_repository.dart';
import '../plugins/plugins_screen.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/profiles_screen.dart';
import '../settings/helper_models_screen.dart';
import '../screens/home_screen.dart';
import '../share/share_controller.dart';
import '../share/shared_item.dart';
import '../skills/hermes_skills_repository.dart';
import '../skills/skills_screen.dart';
import 'attachments/attachment_source.dart';
import 'attachments/attachment_surface.dart';
import 'attachments/plugin_attachment_source.dart';
import 'chat_controller.dart';
import 'chat_message_kinds.dart';
import 'chat_models.dart';
import 'chat_open_requests.dart';
import 'chat_theme.dart';
import 'chat_transport.dart';
import 'gateway/gateway_connection.dart';
import 'gateway/hermes_gateway_transport.dart';
import 'hermes_chat_repository.dart';
import 'queued_prompt.dart';
import 'widgets/chat_builders.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_composer_builder.dart';
import 'widgets/thread_actions_menu.dart';
import 'widgets/thread_sidebar.dart';

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
    this.models,
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
  final HermesModelsRepository? models;
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
  late final ChatController _chat;
  HermesProfilesRepository? _profiles;
  HermesBotsRepository? _bots;
  HermesSkillsRepository? _skills;
  HermesPluginManagerRepository? _plugins;
  HermesMcpRepository? _mcp;
  HermesModelsRepository? _models;
  HermesGatewayTransport? _ownedTransport;
  final _composerController = TextEditingController();
  final List<SharedFile> _attachments = [];
  late final AttachmentSource _attachmentSource;
  late final ShareController _share;
  late final AttentionNotifier _attention;
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
    final repositories = HermesRepositories.maybeOf(context);
    final api = repositories?.api;
    _profiles = widget.profiles ?? repositories?.profiles;
    _bots = widget.bots ?? repositories?.bots;
    _skills = widget.skills ?? repositories?.skills;
    _plugins = widget.plugins ?? repositories?.pluginManager;
    _mcp = widget.mcp ?? repositories?.mcp;
    _models = widget.models ?? repositories?.models;
    var transport = widget.transport;
    if (transport == null && api != null) {
      final auth = context.read<AuthController>();
      final telemetry = _maybeRead<MessagingConnectionTracer>();
      transport = _ownedTransport = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: auth.baseUrl!,
          authRequired: auth.status?.authRequired ?? true,
          api: api,
          telemetry: telemetry,
        ),
        telemetry: telemetry,
      );
    }
    _chat = ChatController(
      repository: widget.repository ?? repositories?.chat,
      profiles: _profiles,
      models: _models,
      transport: transport,
      attention: _attention,
      report: _showMessage,
      onShowChat: () => widget.onShowChat?.call(),
      onOpenJob: (target) => widget.onOpenJob?.call(target),
      onOpened: () => _scaffoldKey.currentState?.closeDrawer(),
    )..addListener(_changed);
    if (_chat.repository != null) _chat.loadThreads();
    _attachmentSource = widget.attachmentSource ?? PluginAttachmentSource();
    _share = context.read<ShareController>()..addListener(_onShared);
    _absorbShared();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _openFromNotification(NotificationTarget target) {
    if (target.isJob) return widget.onOpenJob?.call(target);
    _chat.open(target, fetchMissing: false);
  }

  /// Another destination asked for a session. Unlike a notification tap, it
  /// is fetched when the loaded threads do not hold it, on its own profile.
  void _onOpenRequest() {
    final target = widget.openRequests?.take();
    if (target != null) _chat.open(target, fetchMissing: true);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    _chat.checkConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.openRequests?.removeListener(_onOpenRequest);
    _share.removeListener(_onShared);
    _attention.dispose();
    _chat
      ..removeListener(_changed)
      ..dispose();
    _ownedTransport?.close();
    _composerController.dispose();
    _latestReplyId.dispose();
    super.dispose();
  }

  void _newThread() {
    _chat.newThread();
    _closeDrawerIfNarrow();
  }

  void _selectThread(String id) {
    _chat.select(id);
    _closeDrawerIfNarrow();
  }

  void _openProfiles() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          repository: _profiles,
          chatProfile: _chat.profile,
          onSwitched: _chat.repository == null ? null : _chat.loadThreads,
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
            SkillsScreen(repository: _skills, chatProfile: _chat.profile),
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

  void _openHelperModels() {
    _closeDrawerIfNarrow();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HelperModelsScreen(repository: _models!, profile: _chat.profile),
      ),
    );
  }

  void _showConnection() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _closeDrawerIfNarrow() {
    if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  /// The package composer reports attachments-only sends as an empty [text].
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
    final chat = _chat;
    if (chat.loadingThreads) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (chat.threadsFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your chats'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: chat.loadThreads,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kWideLayoutBreakpoint;
        final selected = chat.selectedThread;
        final modelOptions = chat.modelOptions;
        _followLatestReply(selected);
        ThreadSidebar buildSidebar({Widget? navigation}) => ThreadSidebar(
          navigation: navigation,
          threads: chat.threads,
          selectedId: chat.selectedId,
          onSelect: _selectThread,
          onNewThread: _newThread,
          housekeeping: chat.housekeeping,
          onOpenProfiles: _profiles == null ? null : _openProfiles,
          onOpenBots: _bots == null ? null : _openBots,
          onOpenSkills: _skills == null ? null : _openSkills,
          onOpenPlugins: _plugins == null ? null : _openPlugins,
          onOpenMcp: _mcp == null ? null : _openMcp,
          onOpenHelperModels: _models == null ? null : _openHelperModels,
        );

        return Scaffold(
          key: _scaffoldKey,
          drawer: isWide ? null : Drawer(width: 280, child: buildSidebar()),
          appBar: isWide
              ? null
              : AppBar(
                  title: Text(selected?.title ?? 'Hermes'),
                  actions: [
                    if (selected != null && selected.remote)
                      ThreadActionsButton(
                        key: const Key('header-thread-actions'),
                        thread: selected,
                        housekeeping: chat.housekeeping,
                        includeCopyTranscript: true,
                      ),
                    ConnectionInfoButton(onPressed: _showConnection),
                  ],
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
                  chatController: chat.controllerFor(selected),
                  composerController: _composerController,
                  attachments: _attachments,
                  attachmentSource: _attachmentSource,
                  onAddAttachments: _addAttachments,
                  onRemoveAttachment: (file) =>
                      setState(() => _attachments.remove(file)),
                  onSend: _send,
                  latestReplyId: _latestReplyId,
                  modelPill:
                      modelOptions == null || modelOptions.providers.isEmpty
                      ? null
                      : ComposerModelPill(
                          options: modelOptions,
                          choice: chat.modelChoice,
                          onChanged: chat.chooseModel,
                        ),
                  onRetry:
                      selected == null || chat.lastPromptText(selected) == null
                      ? null
                      : () => chat.retry(selected),
                  header: isWide
                      ? ChatHeader(
                          thread: selected,
                          housekeeping: chat.housekeeping,
                          onShowConnection: _showConnection,
                        )
                      : null,
                  onLoadOlder: selected == null || !chat.hasOlder(selected.id)
                      ? null
                      : () => chat.loadOlder(selected.id),
                  onAnswerApproval: selected == null
                      ? null
                      : (id, choice) =>
                            chat.answerApproval(selected, id, choice),
                  onAnswerClarify: selected == null
                      ? null
                      : (id, answers) =>
                            chat.answerClarify(selected, id, answers),
                  onSkipUnsupported: selected == null
                      ? null
                      : (id, kind) => chat.skipUnsupported(selected, id, kind),
                  onStop: selected == null || chat.transport == null
                      ? null
                      : () => chat.stopReply(selected),
                  queued: selected == null ? const [] : chat.queuedIn(selected),
                  onRemoveQueued: selected == null
                      ? null
                      : (prompt) => chat.removeQueued(selected, prompt),
                  onSendQueued: selected == null || !chat.queuePaused(selected)
                      ? null
                      : () => chat.sendQueued(selected),
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
    this.modelPill,
    this.header,
    this.onRetry,
    this.onLoadOlder,
    this.onAnswerApproval,
    this.onAnswerClarify,
    this.onSkipUnsupported,
    this.onStop,
    this.queued = const [],
    this.onRemoveQueued,
    this.onSendQueued,
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
  final Widget? modelPill;

  /// Shown above the thread in a wide layout.
  final Widget? header;
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
  final List<QueuedPrompt> queued;
  final ValueChanged<QueuedPrompt>? onRemoveQueued;
  final VoidCallback? onSendQueued;

  @override
  Widget build(BuildContext context) {
    final greetingName = context.select<AuthController, String?>(
      (auth) => auth.identity?.displayName,
    );
    final builders =
        buildChatBuilders(
          onPickPrompt: onSend,
          greetingName: greetingName,
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
            replying: thread?.isReplying == true,
            onStop: thread?.isReplying == true ? onStop : null,
            queued: queued,
            onRemoveQueued: onRemoveQueued,
            onSendQueued: onSendQueued,
            modelPill: modelPill,
          ),
        );

    return Column(
      children: [
        if (header case final header?) ...[header, const Divider(height: 1)],
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
