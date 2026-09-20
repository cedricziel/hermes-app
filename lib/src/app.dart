import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'auth/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/server_setup_screen.dart';
import 'settings/theme_controller.dart';
import 'shell/app_shell.dart';
import 'theme/hermes_theme.dart';

class HermesApp extends StatelessWidget {
  /// Prompts to update when [updateChecker] finds a newer release. Left off in
  /// tests, so they never reach out to GitHub.
  const HermesApp({super.key, this.updateChecker});

  final Upgrader? updateChecker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      debugShowCheckedModeBanner: false,
      theme: buildHermesLightTheme(),
      darkTheme: buildHermesDarkTheme(),
      themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
      home: _RootRouter(updateChecker: updateChecker),
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
        return const ServerSetupScreen();
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
