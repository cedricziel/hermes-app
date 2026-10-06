import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../auth/auth_controller.dart';
import '../handoff/handoff_controller.dart';
import '../bot_mode/bot_mode_chat_repository.dart';
import '../bot_mode/bot_chat_context.dart';
import '../bot_mode/bot_mode_roster_repository.dart';
import '../bot_mode/bot_mode_roster_screen.dart';
import '../bot_mode/group_protocol/hermes_groups_repository.dart';
import '../bot_mode/groups/group_chat_screen.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';

import '../chat/chat_open_requests.dart';
import '../chat/chat_screen.dart';
import '../kanban/hermes_plugins_repository.dart';
import '../macos/mac_commands.dart';
import '../macos/mac_sidebar.dart';
import '../settings/account_actions.dart';
import '../settings/settings_dialog.dart';
import '../kanban/kanban_screen.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/chat_profiles.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/mac_profiles_page.dart';
import '../profiles/widgets/mac_profile_switcher.dart';
import '../schedules/hermes_cron_repository.dart';
import '../schedules/schedule_alerts.dart';
import '../schedules/schedule_models.dart';
import '../schedules/schedules_controller.dart';
import '../schedules/schedules_screen.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../windows/conversation_windows.dart';
import 'shell_navigation.dart';

enum _Destination { chat, bots, kanban, schedules, profiles }

/// Top-level navigation between Chat and the destinations the server offers:
/// Kanban while its plugin is on, Schedules while it has the cron routes.
///
/// With neither, the shell is just the chat. Both are checked on connect and
/// whenever the app returns to the foreground. A page is built when its
/// destination is first opened and stays alive behind Chat afterwards, so its
/// filters and selection survive; it is dropped when the destination goes off.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.plugins, this.cron, this.kanbanBuilder});

  /// Overrides the repository built from the signed-in client.
  final HermesPluginsRepository? plugins;

  /// Overrides the cron repository built from the signed-in client.
  final HermesCronRepository? cron;

  /// Overrides the Kanban page.
  final WidgetBuilder? kanbanBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _chatKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _openRequests = ChatOpenRequests();
  HermesPluginsRepository? _plugins;
  HermesCronRepository? _cron;
  HermesProfilesRepository? _profiles;
  HermesGatewayTransport? _gateway;
  BotModeRosterRepository? _botsRepository;
  BotModeChatRepository? _botChats;
  HermesGroupsRepository? _groups;
  bool _bots = false;

  /// The profiles a Mac window switches between in its sidebar; listed on
  /// the first Mac build.
  ChatProfiles? _chatProfiles;

  /// The sidebar of a Mac window, which a pick in it closes when it lies
  /// over the page.
  final _sidebar = MacSidebarController();

  /// Whether the Mac-only state has been read, on the first Mac build.
  bool _macLoaded = false;
  bool _kanban = false;
  bool _schedules = false;
  int _detection = 0;
  int _botOpenVersion = 0;
  _Destination _current = _Destination.chat;

  /// Destinations whose page has been built. A page loads only once its tab
  /// has been opened.
  final _opened = <_Destination>{};
  SchedulesController? _schedulesController;
  ScheduleWatcher? _watcher;

  /// A tap on a scheduled task's notification that came before the cron
  /// check was done.
  NotificationTarget? _pendingJob;
  StreamSubscription<void>? _showInMain;

  @override
  void initState() {
    super.initState();
    final repositories = HermesRepositories.maybeOf(context);
    _plugins = widget.plugins ?? repositories?.plugins;
    _cron = widget.cron ?? repositories?.cron;
    _profiles = repositories?.profiles;
    if (_profiles case final profiles?) {
      _chatProfiles = ChatProfiles(profiles);
    }
    final auth = _maybeRead<AuthController>();
    if (repositories != null && auth?.baseUrl != null) {
      final telemetry = _maybeRead<MessagingConnectionTracer>();
      _gateway = HermesGatewayTransport(
        connect: hermesGatewayConnect(
          baseUrl: auth!.baseUrl!,
          authRequired: auth.status?.authRequired ?? true,
          api: repositories.api,
          telemetry: telemetry,
        ),
        telemetry: telemetry,
      );
      _botsRepository = BotModeRosterRepository(
        _gateway!.request,
        serverId: auth.baseUrl!,
      );
      _botChats = BotModeChatRepository(_gateway!.request);
      _groups = HermesGroupsRepository(_gateway!.request);
      _bots = true;
    }
    final service = _maybeRead<NotificationService>();
    final settings = _maybeRead<NotificationSettings>();
    if (service != null && settings != null && _cron != null) {
      _watcher = ScheduleWatcher(
        repository: _cron!,
        service: service,
        settings: settings,
        profiles: _profiles,
      );
    }
    WidgetsBinding.instance.addObserver(this);
    _detect();
    final windows = _maybeRead<ConversationWindows?>();
    if (windows != null) {
      _showInMain = windows.showInMainRequests.listen((chat) {
        _openRequests.request(
          NotificationTarget(threadId: chat.threadId, profile: chat.profile),
        );
        _showChat();
      });
      unawaited(windows.restore());
    }
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showInMain?.cancel();
    _watcher?.dispose();
    _chatProfiles?.dispose();
    _sidebar.dispose();
    _schedulesController?.dispose();
    _openRequests.dispose();
    _gateway?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _schedulesController?.foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) _detect();
  }

  /// Puts Chat in front. The chat asks for this when a notification tap or
  /// shared content lands there while another page is on screen. Screens
  /// pushed over that page (a task, board management, a job) are dismissed
  /// too, or the user would stay on them.
  void _showChat() {
    if (_current == _Destination.chat) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _select(_Destination.chat, cancelHandoff: false);
  }

  Future<void> _detect() async {
    final detection = ++_detection;
    final (kanban, schedules) = await (
      _plugins?.isKanbanEnabled() ?? Future.value(false),
      _cron?.isAvailable() ?? Future.value(false),
    ).wait;
    if (!mounted || detection != _detection) return;
    if (kanban == _kanban && schedules == _schedules) return;
    setState(() {
      _kanban = kanban;
      _schedules = schedules;
      if (!kanban) _drop(_Destination.kanban);
      if (!schedules) _drop(_Destination.schedules);
    });
    _watcher?.available = schedules;
    _syncSchedules();
    final pending = _pendingJob;
    if (schedules && pending != null) {
      _pendingJob = null;
      _openJob(pending);
    }
  }

  /// Forgets a destination that went off, so it is not rebuilt, or reloaded,
  /// by coming back on.
  void _drop(_Destination destination) {
    _opened.remove(destination);
    if (_current == destination) _current = _Destination.chat;
    if (destination == _Destination.schedules) {
      final controller = _schedulesController;
      _schedulesController = null;
      // The page still listens until this frame is built.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller?.dispose(),
      );
    }
  }

  void _select(_Destination destination, {bool cancelHandoff = true}) {
    if (cancelHandoff) _maybeRead<HandoffController>()?.cancel();
    _sidebar.closeOverlay();
    if (_current == destination) return;
    setState(() {
      _current = destination;
      _opened.add(destination);
      if (destination == _Destination.schedules) _ensureSchedules();
    });
    _syncSchedules();
  }

  void _ensureSchedules() {
    final cron = _cron;
    if (cron == null || _schedulesController != null) return;
    _schedulesController = SchedulesController(
      repository: cron,
      profiles: _profiles,
      prefs: SharedPreferencesAsync(),
    );
  }

  void _syncSchedules() {
    final inFront = _current == _Destination.schedules;
    _schedulesController?.active = inFront;
    _watcher?.schedulesInFront = inFront;
  }

  /// Shows a scheduled task a notification was about. Chat cannot, so it hands
  /// the tap over. Before the cron check has answered the tap waits for it.
  void _openJob(NotificationTarget target) {
    if (!_schedules) {
      _pendingJob = target;
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    _select(_Destination.schedules);
    _schedulesController?.requestOpen(
      target.jobId ?? '',
      profile: target.profile,
    );
  }

  void _openRun(CronRun run, CronJob job) {
    _openRequests.request(
      NotificationTarget(
        threadId: run.sessionId,
        profile: run.profile ?? job.profile,
      ),
    );
    _showChat();
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _openBot(BotModeBot bot) async {
    final version = ++_botOpenVersion;
    try {
      final roster = await _botsRepository!.load();
      final currentBot = roster.bots.singleWhere(
        (candidate) => candidate.identity == bot.identity,
      );
      final chat = await _botChats!.open(currentBot);
      if (!mounted || version != _botOpenVersion) return;
      _openRequests.request(
        NotificationTarget(threadId: chat.storedId, profile: chat.profile),
        bot: BotChatContext(
          bot: currentBot,
          rootId: chat.rootId,
          storedId: chat.storedId,
          peers: roster.bots,
          protocolEnabled: roster.supported,
        ),
      );
      _showChat();
    } on Object {
      if (mounted && version == _botOpenVersion) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the bot chat. Retry from Bots.'),
          ),
        );
      }
    }
  }

  void _openGroup(GroupRoom room) {
    final groups = _groups;
    if (groups == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          repository: groups,
          room: room,
          onDisbanded: () {
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  static const Map<_Destination, ShellDestination> _labels = {
    _Destination.chat: (
      icon: AppIcons.chat,
      selected: AppIcons.chatFilled,
      label: 'Chat',
      caption: null,
    ),
    _Destination.bots: (
      icon: AppIcons.bot,
      selected: AppIcons.bot,
      label: 'Bots',
      caption: null,
    ),
    _Destination.kanban: (
      icon: AppIcons.kanban,
      selected: AppIcons.kanbanFilled,
      label: 'Kanban',
      // The board is shared by every profile.
      caption: 'All profiles',
    ),
    _Destination.schedules: (
      icon: AppIcons.scheduleOutlined,
      selected: AppIcons.schedule,
      label: 'Schedules',
      caption: null,
    ),
    _Destination.profiles: (
      icon: AppIcons.person,
      selected: AppIcons.person,
      label: 'Profiles',
      caption: null,
    ),
  };

  Future<void> _switchProfile(String name) async {
    final switched = await _chatProfiles?.switchTo(name) ?? false;
    if (switched || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not switch profile')));
  }

  /// The profile switcher above the destinations of a Mac sidebar.
  Widget? _profileSwitcher() {
    final profiles = _chatProfiles;
    if (profiles == null) return null;
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) => MacProfileSwitcher(
        profiles: profiles.profiles,
        current: profiles.current,
        onSwitch: _switchProfile,
        onNewProfile: () => createProfile(context, profiles),
        onManage: () => _select(_Destination.profiles),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final built = _build(context);
    if (platformChromeOf(context) != PlatformChrome.macos) return built;
    if (!_macLoaded) {
      _macLoaded = true;
      _sidebar.load();
      _chatProfiles?.load();
    }
    final signIn = context.select<AuthController?, bool>(
      (auth) => auth?.status?.authRequired ?? false,
    );
    return MacCommandScope(
      commands: {
        MacCommand.settings: MacCommandHandler(
          () => showSettingsDialog(context),
        ),
        MacCommand.connectionDetails: MacCommandHandler(
          () => showConnectionDetails(context),
        ),
        MacCommand.signOut: MacCommandHandler(
          signIn
              ? () => confirmSignOut(context, context.read<AuthController>())
              : null,
        ),
      },
      child: MacSidebarScope(controller: _sidebar, child: built),
    );
  }

  Widget _build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    Widget chat({Widget? navigation}) => KeyedSubtree(
      key: _chatKey,
      child: ChatScreen(
        visible: _current == _Destination.chat,
        transport: _gateway,
        onShowChat: _showChat,
        openRequests: _openRequests,
        onOpenJob: _openJob,
        navigation: navigation,
        chatProfiles: mac ? _chatProfiles : null,
      ),
    );
    final destinations = [
      _Destination.chat,
      if (_bots) _Destination.bots,
      if (_kanban) _Destination.kanban,
      if (_schedules) _Destination.schedules,
      if (mac && _chatProfiles != null) _Destination.profiles,
    ];
    if (destinations.length == 1) return chat();

    return LayoutBuilder(
      builder: (context, constraints) {
        // A Mac window keeps its sidebar at any width; a compact one opens it
        // over the page.
        final wide =
            hasMacSidebar(context) ||
            isWideLayout(context, width: constraints.maxWidth);
        final index = destinations.indexOf(_current);
        void select(int i) => _select(destinations[i]);
        final switcher = mac ? _profileSwitcher() : null;
        final shellNavigation = ShellNavigation(
          destinations: [for (final d in destinations) _labels[d]!],
          selectedIndex: index,
          onSelected: select,
        );
        final navigation = switcher == null
            ? shellNavigation
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: switcher,
                  ),
                  shellNavigation,
                ],
              );

        Widget page(_Destination destination) {
          final content = switch (destination) {
            _Destination.chat => chat(navigation: navigation),
            _ when !_opened.contains(destination) => const SizedBox.shrink(),
            _Destination.bots => BotModeRosterScreen(
              repository: _botsRepository!,
              models: HermesRepositories.maybeOf(context)?.models,
              onOpen: _openBot,
              groups: _groups,
              onOpenGroup: _openGroup,
            ),
            _Destination.kanban =>
              widget.kanbanBuilder?.call(context) ?? const KanbanScreen(),
            _Destination.schedules =>
              _schedulesController == null
                  ? const SizedBox.shrink()
                  : SchedulesScreen(
                      controller: _schedulesController!,
                      onOpenRun: _openRun,
                    ),
            _Destination.profiles => MacProfilesPage(profiles: _chatProfiles!),
          };
          if (!wide ||
              destination == _Destination.chat ||
              !_opened.contains(destination)) {
            return content;
          }
          if (platformChromeOf(context) == PlatformChrome.macos) {
            return MacSplitView(
              sidebar: ShellSidebar(navigation: navigation),
              content: content,
            );
          }
          return Row(
            children: [
              ShellSidebar(navigation: navigation),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        }

        final pages = IndexedStack(
          index: index,
          children: [for (final d in destinations) page(d)],
        );
        if (wide) return Scaffold(body: pages);
        // A narrow layout keeps the destinations in a drawer, as Chat keeps
        // its threads: Chat lists them above its threads in its own drawer,
        // the other pages open this one from their app bar.
        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            width: 280,
            child: ShellSidebar(navigation: navigation),
          ),
          drawerEnableOpenDragGesture: _current != _Destination.chat,
          body: ShellMenu(onOpen: _openMenu, child: pages),
        );
      },
    );
  }
}
