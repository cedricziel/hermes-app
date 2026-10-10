import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/theme_controller.dart';
import '../theme/hermes_theme.dart';
import '../windows/conversation_window_args.dart';
import '../windows/desktop_conversation_windows.dart';
import 'widgets/quick_panel_placeholder.dart';

/// Runs the quick panel's engine (macOS), which desktop_multi_window started
/// for [windowId]. Like a conversation window it starts no telemetry,
/// notifications or session of its own.
Future<void> runQuickPanel(String windowId, QuickPanelLaunch launch) async {
  final link = DesktopQuickPanelLink(windowId);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController()..load(),
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Hermes',
          debugShowCheckedModeBanner: false,
          theme: buildHermesLightTheme(),
          darkTheme: buildHermesDarkTheme(),
          themeMode: context.select<ThemeController, ThemeMode>((t) => t.mode),
          home: QuickPanelPlaceholder(
            shown: link.shown,
            onHide: () => link.hide('escape'),
          ),
        ),
      ),
    ),
  );
  await link.present();
}
