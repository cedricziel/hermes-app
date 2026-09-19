import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'chat/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/server_setup_screen.dart';
import 'settings/theme_controller.dart';
import 'theme/hermes_theme.dart';

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      theme: buildHermesLightTheme(),
      darkTheme: buildHermesDarkTheme(),
      themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
      home: const _RootRouter(),
    );
  }
}

/// Switches between setup / login / home purely on [AuthController.state] —
/// no named routes yet, since the bootstrap app only has these three
/// destinations.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

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
        return const ChatScreen();
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
