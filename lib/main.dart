import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/app_lock/app_lock_controller.dart';
import 'src/auth/auth_controller.dart';
import 'src/chat/media/media_source.dart';
import 'src/chat/media/media_store.dart';
import 'src/notifications/local_notification_service.dart';
import 'src/notifications/notification_service.dart';
import 'src/notifications/notification_settings.dart';
import 'src/settings/theme_controller.dart';
import 'src/share/share_controller.dart';
import 'src/share/share_inbox.dart';

import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:flutter_otel_instrumentation_messaging/flutter_otel_instrumentation_messaging.dart';

import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';
import 'src/update/github_release_store.dart';
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
        // Downloaded files are deleted when the session ends, so this must be
        // listening from the start, not from the first file opened.
        Provider<MediaStore?>(
          lazy: false,
          create: (context) {
            final auth = context.read<AuthController>();
            return MediaStore(
              source: HermesMediaSource(() => auth.api),
              cacheDirectory: getApplicationCacheDirectory,
            )..clearOnSignOut(auth.signedOut);
          },
          dispose: (_, store) => store?.dispose(),
        ),
        Provider<MessagingConnectionTracer>.value(value: telemetry.gateway()),
        Provider<AppEventLogger>.value(value: telemetry.events()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => AppLockController()..load(),
        ),
        Provider<NotificationService>(
          create: (_) => LocalNotificationService(),
          dispose: (_, service) => service.dispose(),
        ),
        // Read after the notification providers above: a provider only sees
        // the ones declared before it.
        Provider<WatchBridge?>(
          lazy: false,
          create: (context) => WatchBridge.forAuth(
            context.read<AuthController>(),
            notifications: context.read<NotificationService>(),
            settings: context.read<NotificationSettings>(),
          )?..start(),
          dispose: (_, bridge) => bridge?.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShareController(createPlatformShareInbox())..start(),
        ),
      ],
      child: HermesApp(updateChecker: createUpdateChecker()),
    ),
  );
}
