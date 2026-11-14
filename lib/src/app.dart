import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../l10n/l10n.dart';
import 'app_lock/app_lock_gate.dart';
import 'app_lock/app_lock_controller.dart';
import 'api/hermes_repositories.dart';
import 'navigation/connection_pages.dart';
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
import 'theme/material_ui_bridge.dart';

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
  final _pushedRoutes = PushedRoutes();
  late final _connectionPages = ConnectionPageCloser(_pushedRoutes);
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

  T? _read<T extends Object>() {
    try {
      return context.read<T?>();
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
    _connectionPages.dispose();
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
    _connectionPages
      ..bind(auth)
      ..breadcrumbs = _read<Breadcrumbs>() ?? Breadcrumbs.none;
    _syncHistory(auth);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_handoffObserver, _history, _pushedRoutes],
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        ...kMaterialUiLocalizationsDelegates,
      ],
      supportedLocales: kReleasedLocales,
      theme: widget.lightTheme ?? buildHermesLightTheme(),
      darkTheme: widget.darkTheme ?? buildHermesDarkTheme(),
      themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
      builder: (context, child) => MaterialUiThemeScope(
        child: MenuBarExtraHost(
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
      ),
      home: _RootRouter(updateChecker: widget.updateChecker),
    );
  }
}

/// Switches between setup / login / home on [AuthController.state] — no named
/// routes yet, since the bootstrap app only has these three destinations. The
/// home shell is also rebuilt when the account owner generation changes.
class _RootRouter extends StatefulWidget {
  const _RootRouter({this.updateChecker});

  final Upgrader? updateChecker;

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  /// The owner generation the shell on screen was built for. It follows
  /// [AuthController.ownerGeneration] only while protected requests are
  /// allowed: an ungated server's sign-out moves the generation while the
  /// state stays `ready`, but the API client and the repositories over it are
  /// replaced a moment later, and a shell built in between would keep the old
  /// ones. An expiry never moves the generation, so it keeps its shell.
  int? _shellOwner;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final state = auth.state;
    if (state != HermesConnectionState.ready) {
      _shellOwner = null;
    } else if (auth.protectedRequestsAllowed) {
      _shellOwner = auth.ownerGeneration;
    }
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
        // A new owner gets a new shell: the old one holds the old owner's
        // controllers, runs and gateway, and stays unauthorized for good.
        final shell = AppShell(key: ValueKey(_shellOwner));
        final updateChecker = widget.updateChecker;
        if (updateChecker == null) return shell;
        return UpgradeAlert(
          upgrader: updateChecker,
          showReleaseNotes: false,
          child: shell,
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
