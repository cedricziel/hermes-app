import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'app_lock/app_lock_gate.dart';
import 'app_lock/app_lock_controller.dart';
import 'api/hermes_repositories.dart';
import 'navigation/desktop_history_owner.dart';
import 'navigation/desktop_navigation_history.dart';
import 'navigation/desktop_navigation_commands.dart';
import 'navigation/workers_navigation_resolver.dart';
import 'telemetry/breadcrumbs.dart';
import 'handoff/handoff_controller.dart';
import 'handoff/handoff_gate.dart';
import 'windows/conversation_windows_menu.dart';
import 'auth/auth_controller.dart';
import 'macos/dock/dock_menu_gate.dart';
import 'macos/mac_menu_bar.dart';
import 'macos/mac_app.dart';
import 'windows/conversation_windows.dart';
import 'macos/menu_bar_extra/menu_bar_extra_host.dart';
import 'macos/mac_window.dart';
import 'screens/login_screen.dart';
import 'screens/server_setup_screen.dart';
import 'settings/theme_controller.dart';
import 'shell/app_shell.dart';
import 'theme/hermes_theme.dart';

class HermesApp extends StatefulWidget {
  /// Prompts to update when [updateChecker] finds a newer release. Left off in
  /// tests, so they never reach out to GitHub.
  const HermesApp({
    super.key,
    this.updateChecker,
    this.lightTheme,
    this.darkTheme,
  });

  final Upgrader? updateChecker;

  /// Replace the built-in themes. Tests use it to render with a font loaded
  /// from the SDK.
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  @override
  State<HermesApp> createState() => _HermesAppState();
}

class _HermesAppState extends State<HermesApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _handoffObserver = HandoffNavigationObserver();
  late final _history = DesktopNavigationHistory(
    canNavigate: _canNavigate,
    resolve: _resolve,
  );
  final _historyOwner = DesktopHistoryOwner();
  bool? _available;
  ConversationWindows? _windows;
  String? _keyWindowId;
  bool _windowless = false;
  StreamSubscription<bool>? _windowlessChanges;

  @override
  void initState() {
    super.initState();
    _windowlessChanges = MacApp.windowlessChanges.listen((windowless) {
      if (_windowless == windowless) return;
      _windowless = windowless;
      _history.gateChanged();
    });
  }

  void _bindWindows(ConversationWindows? windows) {
    if (identical(_windows, windows)) return;
    _windows?.removeListener(_windowOwnershipChanged);
    _windows = windows;
    windows?.addListener(_windowOwnershipChanged);
    _windowOwnershipChanged();
  }

  void _windowOwnershipChanged() {
    final key = _windows?.keyWindow?.windowId;
    if (_keyWindowId == key) return;
    _keyWindowId = key;
    _history.gateChanged();
  }

  T? _read<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool _canNavigate() {
    if (!mounted) return false;
    final auth = _read<AuthController>();
    final lock = _read<AppLockController>();
    final handoff = _read<HandoffController>();
    return auth?.state == HermesConnectionState.ready &&
        auth!.protectedRequestsAllowed &&
        _historyOwner.matches(
          userGeneration: auth.userGeneration,
          server: auth.baseUrl,
          owner: auth.verifiedOwner,
        ) &&
        !_windowless &&
        _read<ConversationWindows>()?.keyWindow == null &&
        lock?.covered != true &&
        handoff?.needsConnection != true &&
        handoff?.error == null;
  }

  Future<Route<void>?> _resolve(DesktopNavigationTarget target) async {
    final repositories = HermesRepositories.maybeOf(context);
    if (repositories == null || !_canNavigate()) return null;
    return switch (target) {
      WorkersNavigationTarget workers => resolveWorkersNavigation(
        workers,
        repositories,
        _canNavigate,
      ),
    };
  }

  void _syncHistory(AuthController auth) {
    if (_historyOwner.update(
      ready: auth.state == HermesConnectionState.ready,
      userGeneration: auth.userGeneration,
      server: auth.baseUrl,
      owner: auth.verifiedOwner,
      expired: auth.sessionExpired,
      expiredOwner: auth.expiredOwner,
    )) {
      _history.clear();
    }
    final available = _canNavigate();
    if (_available != available) _history.gateChanged();
    _available = available;
    _history.breadcrumbs = _read<Breadcrumbs>() ?? Breadcrumbs.none;
  }

  @override
  void dispose() {
    _windows?.removeListener(_windowOwnershipChanged);
    unawaited(_windowlessChanges?.cancel());
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _handoffObserver.handoff = context.read<HandoffController?>();
    final auth = context.watch<AuthController>();
    context.watch<AppLockController?>();
    context.watch<HandoffController?>();
    _bindWindows(context.watch<ConversationWindows?>());
    _syncHistory(auth);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_handoffObserver, _history],
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      theme: widget.lightTheme ?? buildHermesLightTheme(),
      darkTheme: widget.darkTheme ?? buildHermesDarkTheme(),
      themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
      builder: (context, child) => MenuBarExtraHost(
        navigatorKey: _navigatorKey,
        child: MacMenuBar(
          navigatorKey: _navigatorKey,
          child: ConversationWindowsMenu(
            child: DesktopNavigationHistoryScope(
              history: _history,
              child: Builder(
                builder: (context) {
                  final content = MacWindowChrome(
                    child: AppLockGate(
                      child: DockMenuGate(child: HandoffGate(child: child!)),
                    ),
                  );
                  return switch (Theme.of(context).platform) {
                    TargetPlatform.macOS ||
                    TargetPlatform.windows ||
                    TargetPlatform.linux => DesktopNavigationCommands(
                      history: _history,
                      child: content,
                    ),
                    _ => content,
                  };
                },
              ),
            ),
          ),
        ),
      ),
      home: _RootRouter(updateChecker: widget.updateChecker),
    );
  }
}

/// Switches between setup / login / home purely on [AuthController.state] —
/// no named routes yet, since the bootstrap app only has these three
/// destinations.
class _RootRouter extends StatelessWidget {
  const _RootRouter({this.updateChecker});

  final Upgrader? updateChecker;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthController>().state;
    switch (state) {
      case HermesConnectionState.initializing:
        return const _SplashScreen();
      case HermesConnectionState.needsServerUrl:
      case HermesConnectionState.connecting:
      case HermesConnectionState.connectionError:
        return ServerSetupScreen(
          initialUrl: context.watch<HandoffController?>()?.setupUrl,
        );
      case HermesConnectionState.needsLogin:
      case HermesConnectionState.signingIn:
        return const LoginScreen();
      case HermesConnectionState.ready:
        final updateChecker = this.updateChecker;
        if (updateChecker == null) return const AppShell();
        return UpgradeAlert(
          upgrader: updateChecker,
          showReleaseNotes: false,
          child: const AppShell(),
        );
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
