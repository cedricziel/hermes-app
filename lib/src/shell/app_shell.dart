import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../agent_messages/agent_message_watcher.dart';
import '../api/hermes_repositories.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../handoff/handoff_controller.dart';
import '../bot_mode/bot_mode_chat_repository.dart';
import '../bot_mode/bot_chat_context.dart';
import '../bot_mode/bot_mode_roster_repository.dart';
import '../bot_mode/bot_mode_roster_screen.dart';
import '../bot_mode/group_protocol/hermes_groups_repository.dart';
import '../bot_mode/groups/group_chat_screen.dart';
import '../bot_screen/bot_screen_repository.dart';
import '../bot_screen/install/bot_screen_installs.dart';
import '../bot_screen/widgets/sudo_password_prompt.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';

import '../chat/chat_open_requests.dart';
import '../chat/chat_screen.dart';
import '../deep_links/deep_link_listener.dart';
import '../deep_links/deep_link_target.dart';
import '../kanban/hermes_plugins_repository.dart';
import '../macos/mac_app.dart';
import '../macos/mac_window.dart';
import '../macos/mac_commands.dart';
import '../navigation/desktop_navigation_history.dart';
import '../macos/mac_sidebar.dart';
import '../settings/account_actions.dart';
import '../settings/settings_dialog.dart';
import '../kanban/kanban_screen.dart';
import '../telemetry/breadcrumbs.dart';
import '../notifications/attention_notifier.dart' show appLockHidesRequests;
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../platform_hint/platform_hint_offer.dart';
import '../platform_hint/show_platform_hint_prompt.dart';
import '../profiles/chat_profiles.dart';
import '../server_care/server_attention_mark.dart';
import '../server_care/server_care_controller.dart';
import '../server_care/server_care_scope.dart';
import '../server_care/server_screen.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../profiles/mac_profiles_page.dart';
import '../profiles/widgets/mac_profile_switcher.dart';
import '../profiles/widgets/new_profile_dialog.dart';
import '../schedules/hermes_cron_repository.dart';
import '../schedules/schedule_alerts.dart';
import '../schedules/schedule_models.dart';
import '../schedules/schedules_controller.dart';
import '../schedules/schedules_screen.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../windows/conversation_windows.dart';
import 'app_presence.dart';
import 'shell_navigation.dart';
import '../widgets/route_dismissal.dart';
import '../widgets/root_navigation_queue.dart';

part 'app_shell_deep_links.dart';
part 'app_shell_navigation.dart';
part 'app_shell_platform_hint.dart';
part 'app_shell_detection.dart';
part 'app_shell_watchers.dart';
part 'app_shell_bots.dart';
part 'app_shell_sudo_prompt.dart';
part 'app_shell_profiles.dart';

enum _Destination { chat, bots, kanban, schedules, profiles, server }

/// Top-level navigation between Chat and the destinations the server offers:
/// Kanban while its plugin is on, Schedules while it has the cron routes.
///
/// With neither, the shell is just the chat. Both are checked on connect and
/// whenever the app returns to the foreground. A page is built when its
/// destination is first opened and stays alive behind Chat afterwards, so its
/// filters and selection survive; it is dropped when the destination goes off.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.plugins,
    this.cron,
    this.kanbanBuilder,
    this.gatewayConnect,
  });

  /// Overrides the repository built from the signed-in client.
  final HermesPluginsRepository? plugins;

  /// Overrides the cron repository built from the signed-in client.
  final HermesCronRepository? cron;

  /// Overrides the Kanban page.
  final WidgetBuilder? kanbanBuilder;

  /// Overrides how the gateway socket is opened.
  final GatewayConnect? gatewayConnect;

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

  /// The installs of the desktop on the server the user started, which go on
  /// whatever page is up and ask for the sudo password over it.
  BotScreenInstalls? _installs;
  BotModeRosterRepository? _botsRepository;
  BotModeChatRepository? _botChats;
  HermesGroupsRepository? _groups;
  bool _bots = false;

  /// The profiles a Mac window switches between in its sidebar; listed on
  /// the first Mac build.
  ChatProfiles? _chatProfiles;

  /// What the Server screen and the attention mark read; one per shell, so
  /// it ends with the connection.
  ServerCareController? _serverCare;

  /// The sidebar of a Mac window, which a pick in it closes when it lies
  /// over the page.
  final _sidebar = MacSidebarController();

  /// Whether the Mac-only state has been read, on the first Mac build.
  bool _macLoaded = false;
  bool _kanban = false;
  bool _schedules = false;
  int _detection = 0;
  int _botOpenVersion = 0;
  int _externalIntentRevision = 0;
  _Destination _current = _Destination.chat;
  late final Breadcrumbs _breadcrumbs;

  /// Destinations whose page has been built. A page loads only once its tab
  /// has been opened.
  final _opened = <_Destination>{};
  SchedulesController? _schedulesController;
  ScheduleWatcher? _watcher;
  AgentMessageWatcher? _messages;
  final _finds = AgentMessageFinds();
  StreamSubscription<bool>? _windowlessChanges;
  var _appForeground = true;

  /// Whether the macOS runner reports no window on screen. The app goes on
  /// then; only the watcher polls, not a Schedules page nobody sees.
  var _windowless = false;

  /// A tap on a scheduled task's notification that came before the cron
  /// check was done.
  NotificationTarget? _pendingJob;

  /// Whether a check has answered, one way or the other, for each tab. A
  /// check that could not reach the server answers neither.
  var _kanbanKnown = false;
  var _schedulesKnown = false;

  /// A link to Kanban or Schedules that came before that answer.
  PendingDeepLink? _waitingLink;
  RootNavigationQueue? _navigationQueue;
  DeepLinks? _deepLinks;
  AppLockController? _appLock;

  /// Whether the link being opened was kept back by App Lock.
  var _lockHeld = false;
  StreamSubscription<void>? _showInMain;
  ConversationWindows? _windows;
  AuthController? _auth;
  int? _ownerGeneration;
  bool _sessionAuthorized = true;

  bool get _authorizedOwner =>
      mounted &&
      (_auth == null ||
          (_auth!.state == HermesConnectionState.ready &&
              _auth!.protectedRequestsAllowed &&
              _auth!.ownerGeneration == _ownerGeneration));

  @override
  void initState() {
    super.initState();
    _breadcrumbs = _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none;
    final repositories = HermesRepositories.maybeOf(context);
    _plugins = widget.plugins ?? repositories?.plugins;
    _cron = widget.cron ?? repositories?.cron;
    _profiles = repositories?.profiles;
    if (_profiles case final profiles?) {
      _chatProfiles = ChatProfiles(profiles);
    }
    final auth = _auth = _maybeRead<AuthController>();
    _ownerGeneration = auth?.ownerGeneration;
    _sessionAuthorized = _authorizedOwner;
    auth?.addListener(_resumeExternalNavigation);
    if (repositories != null && auth?.baseUrl != null) {
      final telemetry = repositories.telemetry.gateway();
      final gateway = _gateway = HermesGatewayTransport(
        connect:
            widget.gatewayConnect ??
            hermesGatewayConnect(
              baseUrl: auth!.baseUrl!,
              authRequired: auth.status?.authRequired ?? true,
              api: repositories.api,
              telemetry: telemetry,
            ),
        telemetry: telemetry,
        events: repositories.telemetry.events,
      );
      _installs = BotScreenInstalls(
        repository: BotScreenRepository(
          gateway.requestKeepingConnection,
          telemetry: repositories.telemetry,
          connectionRpc: gateway.requestKeepingConnectionOnClient,
        ),
        connectionEvents: gateway.connectionEvents,
        registerServerRequestHandler: gateway.registerServerRequestHandler,
        askPassword: _askSudoPassword,
        host: Uri.tryParse(auth!.baseUrl!)?.host ?? 'your server',
        telemetry: repositories.telemetry,
      );
      _botsRepository = BotModeRosterRepository(
        _gateway!.request,
        serverId: auth.baseUrl!,
      );
      _botChats = BotModeChatRepository(_gateway!.request);
      _groups = HermesGroupsRepository(_gateway!.request);
      _bots = true;
      final server = auth.baseUrl!;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerHint(repositories, server),
      );
    }
    _appLock = _maybeRead<AppLockController>()?..addListener(_takeDeepLink);
    if (repositories != null) {
      final care = _serverCare = ServerCareController(
        repository: repositories.serverCare,
        telemetry: repositories.telemetry,
        covered: () => _appLock?.covered ?? false,
      );
      _chatProfiles?.addListener(_followServerCareProfile);
      care.lookUpProfile = _resolveServerCareProfile;
      care.addListener(_careSupportChanged);
      _appLock?.addListener(_readServerCareAfterUnlock);
      // The chat reports its profile after its threads load, and not at all
      // when it works in the server's default, so the default is resolved by
      // name here. Nothing is read before some profile is known.
      unawaited(_resolveServerCareProfile());
    }
    final service = _maybeRead<NotificationService>();
    final settings = _maybeRead<NotificationSettings>();
    if (service != null && settings != null && _cron != null) {
      final accounts = _maybeRead<AuthController>();
      _watcher = ScheduleWatcher(
        repository: _cron!,
        service: service,
        settings: settings,
        profiles: _profiles,
        account: () => accounts?.accountKey ?? '',
      )..paused = !_sessionAuthorized;
    }
    if (agentMessagesSupported() &&
        service != null &&
        settings != null &&
        repositories != null) {
      final accounts = _maybeRead<AuthController>();
      _messages = AgentMessageWatcher(
        chat: repositories.chat,
        profiles: repositories.profiles,
        service: service,
        settings: settings,
        finds: _finds,
        appLock: () => appLockHidesRequests(_appLock),
        shownProfile: () => _chatProfiles?.current,
        account: () => accounts?.accountKey ?? '',
        breadcrumbs: _breadcrumbs,
        events: repositories.telemetry.events,
        paused: !_sessionAuthorized,
      );
    }
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      _windowlessChanges = MacApp.windowlessChanges.listen(_onWindowless);
    }
    _detect();
    _deepLinks = _maybeRead<DeepLinks?>()?..addListener(_takeDeepLink);
    // A link that came before this shell existed waited for sign-in.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _takeDeepLink(held: true),
    );
    final windows = _windows = _maybeRead<ConversationWindows?>();
    if (windows != null) {
      windows.currentProfile = () => _chatProfiles?.current;
      _showInMain = windows.showInMainRequests.listen((chat) {
        _queueExternalNavigation(() {
          _openRequests.request(
            NotificationTarget(threadId: chat.threadId, profile: chat.profile),
          );
          _showChat();
        });
      });
      unawaited(windows.restore());
    }
  }

  // Listener tear-offs must stay on the State: an extension method tear-off
  // is a new closure each time, so removeListener would never match.
  void _resumeExternalNavigation() {
    final authorized = _authorizedOwner;
    if (authorized != _sessionAuthorized) {
      _sessionAuthorized = authorized;
      _detection++;
      _watcher?.paused = !authorized;
      _messages?.paused = !authorized;
      if (authorized) unawaited(_detect());
    }
    _navigationQueue?.resume();
  }

  /// Takes the waiting link, unless App Lock covers the app: the shell stays
  /// mounted under the lock screen, and a link must not start anything (a
  /// chat, the microphone) before the user is back.
  void _takeDeepLink({bool held = false}) {
    final deepLinks = _deepLinks;
    if (deepLinks == null) {
      if (!(_appLock?.covered ?? false)) _navigationQueue?.resume();
      return;
    }
    if (_appLock?.covered ?? false) {
      _lockHeld = _lockHeld || deepLinks.pending != null;
      return;
    }
    final waited = held || _lockHeld;
    if (deepLinks.take() case final link?) {
      _lockHeld = false;
      _openDeepLink(link, waited: waited);
    }
    _releaseWaitingLink();
    _navigationQueue?.resume();
  }

  void _rebuild(VoidCallback update) => setState(update);

  /// Whether the server has a status route, as last seen: the Mac sidebar
  /// lists Server only while it does.
  bool _careSupported = true;

  void _careSupportChanged() {
    final supported = _serverCare?.supported ?? true;
    if (supported == _careSupported || !mounted) return;
    setState(() => _careSupported = supported);
  }

  /// The server's own default profile, by name; null until read.
  String? _defaultProfile;

  Future<void> _resolveServerCareProfile() async {
    try {
      final active = await _profiles?.loadActive();
      if (active != null) {
        final name = active.current.isNotEmpty ? active.current : active.active;
        _defaultProfile = name.isEmpty ? null : name;
      }
    } on Object {
      // The chat's own report is then what names the profile.
    }
    if (!mounted) return;
    _followServerCareProfile();
    _serverCare?.profileLookupEnded(
      found: (_chatProfiles?.current ?? _defaultProfile) != null,
    );
  }

  void _followServerCareProfile() =>
      _serverCare?.profileChanged(_chatProfiles?.current ?? _defaultProfile);

  /// A status read skipped under App Lock is made up for on unlock.
  void _readServerCareAfterUnlock() {
    if (!(_appLock?.covered ?? true)) unawaited(_serverCare?.resumed());
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
    _navigationQueue?.dispose();
    _auth?.removeListener(_resumeExternalNavigation);
    _deepLinks?.removeListener(_takeDeepLink);
    _appLock?.removeListener(_takeDeepLink);
    _showInMain?.cancel();
    _windowlessChanges?.cancel();
    _windows?.currentProfile = null;
    _watcher?.dispose();
    _messages?.dispose();
    _finds.dispose();
    _chatProfiles?.removeListener(_followServerCareProfile);
    _appLock?.removeListener(_readServerCareAfterUnlock);
    _serverCare
      ?..removeListener(_careSupportChanged)
      ..dispose();
    _chatProfiles?.dispose();
    _sidebar.dispose();
    _schedulesController?.dispose();
    _openRequests.dispose();
    _installs?.dispose();
    _gateway?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The states between the two are passing steps of the same trip.
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      _breadcrumbs('app.lifecycle', {'state': state.name});
    }
    _appForeground = AppPresence.foreground(state);
    _syncSchedulesForeground();
    if (state == AppLifecycleState.resumed) {
      // The default profile's name is still owed when the first lookup failed.
      if (_serverCare != null &&
          _defaultProfile == null &&
          _chatProfiles?.current == null) {
        unawaited(_resolveServerCareProfile());
      }
      unawaited(_serverCare?.resumed());
      _installs?.resumed();
      _detect();
    }
  }

  var _shareEntry = 0;
  var _shareEntryValid = false;

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

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
    // The label and the caption are filled in where it is listed.
    _Destination.server: (
      icon: AppIcons.server,
      selected: AppIcons.server,
      label: '',
      caption: null,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final built = ChangeNotifierProvider.value(
      value: _finds,
      child: switch (_installs) {
        final installs? => ChangeNotifierProvider.value(
          value: installs,
          child: _build(context),
        ),
        null => _build(context),
      },
    );
    final care = _serverCare;
    final provided = care == null
        ? built
        : ChangeNotifierProvider<ServerCareController>.value(
            value: care,
            child: built,
          );
    final chrome = platformChromeOf(context);
    if (!chrome.isApple) return provided;
    final mac = chrome == PlatformChrome.macos;
    if (mac && !_macLoaded) {
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
      child: mac
          ? MacSidebarScope(controller: _sidebar, child: provided)
          : provided,
    );
  }

  Widget _build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    Widget chat({Widget? navigation}) => KeyedSubtree(
      key: _chatKey,
      child: ChatScreen(
        visible: _current == _Destination.chat,
        shareEntry: _shareEntry,
        transport: _gateway,
        onShowChat: _showChat,
        onExternalNavigation: _queueExternalNavigation,
        onShareEntry: _recoverShared,
        openRequests: _openRequests,
        onOpenJob: _openJob,
        navigation: navigation,
        chatProfiles: _chatProfiles,
      ),
    );
    final destinations = [
      _Destination.chat,
      if (_bots) _Destination.bots,
      if (_kanban) _Destination.kanban,
      if (_schedules) _Destination.schedules,
      if (mac && _chatProfiles != null) _Destination.profiles,
      if (mac && _serverCare != null && _careSupported) _Destination.server,
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
        void select(int i) => _selectByUser(destinations[i]);
        final switcher = mac ? _profileSwitcher() : null;
        // Only a Mac sidebar shows the caption; others need not rebuild.
        final l10n = context.l10n;
        final serverCaption = !mac || _serverCare == null
            ? null
            : serverMarkCaption(
                l10n,
                context.select<ServerCareController, ServerAttentionMark>(
                  (care) => care.mark,
                ),
              );
        final shellNavigation = ShellNavigation(
          destinations: [
            for (final d in destinations)
              d == _Destination.server
                  ? (
                      icon: _labels[d]!.icon,
                      selected: _labels[d]!.selected,
                      label: l10n.serverCareTitle,
                      caption: serverCaption,
                    )
                  : _labels[d]!,
          ],
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
            _Destination.profiles => MacProfilesPage(
              profiles: _chatProfiles!,
              changeSource: _gateway,
              transport: _gateway,
            ),
            _Destination.server => const ServerScreen(source: 'sidebar'),
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

        // Pages kept alive behind the one in front keep their floating
        // buttons, whose heroes would clash with the front page's when a
        // route is pushed.
        final pages = IndexedStack(
          index: index,
          children: [
            for (final (i, d) in destinations.indexed)
              HeroMode(enabled: i == index, child: page(d)),
          ],
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
