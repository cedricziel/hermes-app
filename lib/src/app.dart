import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'app_lock/app_lock_gate.dart';
import 'handoff/handoff_controller.dart';
import 'handoff/handoff_gate.dart';
import 'windows/conversation_windows_menu.dart';
import 'auth/auth_controller.dart';
import 'macos/mac_menu_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    _handoffObserver.handoff = context.read<HandoffController?>();
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_handoffObserver],
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      theme: widget.lightTheme ?? buildHermesLightTheme(),
      darkTheme: widget.darkTheme ?? buildHermesDarkTheme(),
      themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
      builder: (context, child) => MacMenuBar(
        navigatorKey: _navigatorKey,
        child: ConversationWindowsMenu(
          child: MacWindowChrome(
            child: AppLockGate(child: HandoffGate(child: child!)),
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
