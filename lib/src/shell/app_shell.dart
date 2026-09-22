import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';

import '../chat/chat_open_requests.dart';
import '../chat/chat_screen.dart';
import '../kanban/hermes_plugins_repository.dart';
import '../kanban/kanban_screen.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../schedules/hermes_cron_repository.dart';
import '../schedules/schedule_alerts.dart';
import '../schedules/schedule_models.dart';
import '../schedules/schedules_controller.dart';
import '../schedules/schedules_screen.dart';
import 'shell_navigation.dart';

enum _Destination { chat, kanban, schedules }

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
  final _openRequests = ChatOpenRequests();
  HermesPluginsRepository? _plugins;
  HermesCronRepository? _cron;
  HermesProfilesRepository? _profiles;
  bool _kanban = false;
  bool _schedules = false;
  int _detection = 0;
  _Destination _current = _Destination.chat;

  /// Destinations whose page has been built. A page loads only once its tab
  /// has been opened.
  final _opened = <_Destination>{};
  SchedulesController? _schedulesController;
  ScheduleWatcher? _watcher;

  /// A tap on a scheduled task's notification that came before the cron
  /// check was done.
  NotificationTarget? _pendingJob;

  @override
  void initState() {
    super.initState();
    final repositories = HermesRepositories.maybeOf(context);
    _plugins = widget.plugins ?? repositories?.plugins;
    _cron = widget.cron ?? repositories?.cron;
    _profiles = repositories?.profiles;
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
    _watcher?.dispose();
    _schedulesController?.dispose();
    _openRequests.dispose();
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
    _select(_Destination.chat);
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

  void _select(_Destination destination) {
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

  static const Map<_Destination, ShellDestination> _labels = {
    _Destination.chat: (
      icon: Icons.chat_bubble_outline,
      selected: Icons.chat_bubble,
      label: 'Chat',
    ),
    _Destination.kanban: (
      icon: Icons.view_kanban_outlined,
      selected: Icons.view_kanban,
      label: 'Kanban',
    ),
    _Destination.schedules: (
      icon: Icons.schedule_outlined,
      selected: Icons.schedule,
      label: 'Schedules',
    ),
  };

  @override
  Widget build(BuildContext context) {
    Widget chat({Widget? navigation}) => KeyedSubtree(
      key: _chatKey,
      child: ChatScreen(
        onShowChat: _showChat,
        openRequests: _openRequests,
        onOpenJob: _openJob,
        navigation: navigation,
      ),
    );
    final destinations = [
      _Destination.chat,
      if (_kanban) _Destination.kanban,
      if (_schedules) _Destination.schedules,
    ];
    if (destinations.length == 1) return chat();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideLayoutBreakpoint;
        final index = destinations.indexOf(_current);
        void select(int i) => _select(destinations[i]);
        final navigation = ShellNavigation(
          destinations: [for (final d in destinations) _labels[d]!],
          selectedIndex: index,
          onSelected: select,
        );

        Widget page(_Destination destination) {
          final content = switch (destination) {
            _Destination.chat => chat(navigation: wide ? navigation : null),
            _ when !_opened.contains(destination) => const SizedBox.shrink(),
            _Destination.kanban =>
              widget.kanbanBuilder?.call(context) ?? const KanbanScreen(),
            _Destination.schedules =>
              _schedulesController == null
                  ? const SizedBox.shrink()
                  : SchedulesScreen(
                      controller: _schedulesController!,
                      onOpenRun: _openRun,
                    ),
          };
          if (!wide ||
              destination == _Destination.chat ||
              !_opened.contains(destination)) {
            return content;
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
        return Scaffold(
          body: pages,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: select,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(_labels[d]!.icon),
                  selectedIcon: Icon(_labels[d]!.selected),
                  label: _labels[d]!.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
