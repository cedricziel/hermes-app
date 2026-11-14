import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/app/providers/app_lock_providers.dart';
import 'src/app/providers/auth_providers.dart';
import 'src/app/providers/deep_link_providers.dart';
import 'src/app/providers/macos_providers.dart';
import 'src/app/providers/notification_providers.dart';
import 'src/app/providers/settings_providers.dart';
import 'src/app/providers/surface_providers.dart';
import 'src/app/providers/telemetry_providers.dart';
import 'src/app/providers/voice_providers.dart';
import 'src/app/providers/watch_providers.dart';
import 'src/macos/mac_window.dart';
import 'src/network/user_certificates.dart';
import 'src/share/share_provider.dart';
import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';
import 'src/update/github_release_store.dart';
import 'src/windows/conversation_window_app.dart';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (conversationWindowLaunch(args) case final window?) {
    return runConversationWindow(window.windowId, window.arguments);
  }
  final certificates = trustUserCertificates();
  await MacWindow.initialize();
  final telemetry = await Telemetry.initialize(
    TelemetryConfig.fromEnvironment(),
  );
  telemetry.logUncaughtErrors();
  await certificates;
  // A certificate installed in Settings counts once the user is back.
  AppLifecycleListener(onResume: () => unawaited(trustUserCertificates()));

  runApp(
    MultiProvider(
      providers: [
        ...authProviders(telemetry),
        ...telemetryProviders(telemetry),
        ...deepLinkProviders(telemetry),
        ...macosInputProviders(telemetry),
        ...appLockProviders(telemetry),
        ...macosWindowProviders(telemetry),
        ...settingsProviders(),
        ...voiceProviders(),
        ...macosDockProviders(telemetry),
        ...liveActivityProviders(),
        ...surfaceProviders(telemetry),
        ...watchProviders(telemetry),
        ...backgroundProviders(telemetry),
        shareProvider(),
      ],
      child: HermesApp(updateChecker: createUpdateChecker()),
    ),
  );
}
