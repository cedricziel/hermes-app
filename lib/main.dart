import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/auth/auth_controller.dart';
import 'src/notifications/local_notification_service.dart';
import 'src/notifications/notification_service.dart';
import 'src/notifications/notification_settings.dart';
import 'src/settings/theme_controller.dart';
import 'src/share/share_controller.dart';
import 'src/share/share_inbox.dart';

import 'package:flutter_otel_instrumentation_messaging/flutter_otel_instrumentation_messaging.dart';

import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';
import 'src/watch/watch_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final telemetry = await Telemetry.initialize(
    TelemetryConfig.fromEnvironment(),
  );
  telemetry.logUncaughtErrors();
  final httpInterceptor = telemetry.dioInterceptor();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController(
            interceptors: [?httpInterceptor],
            events: telemetry.events(),
          )..bootstrap(),
        ),
        Provider<WatchBridge?>(
          lazy: false,
          create: (context) =>
              WatchBridge.forAuth(context.read<AuthController>())?..start(),
          dispose: (_, bridge) => bridge?.dispose(),
        ),
        Provider<MessagingConnectionTracer>.value(value: telemetry.gateway()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
        Provider<NotificationService>(
          create: (_) => LocalNotificationService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShareController(createPlatformShareInbox())..start(),
        ),
      ],
      child: const HermesApp(),
    ),
  );
}
