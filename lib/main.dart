import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/handoff/handoff_controller.dart';
import 'src/handoff/handoff_bridge.dart';
import 'src/api/hermes_repositories.dart';
import 'src/app_lock/app_lock_controller.dart';
import 'src/auth/auth_controller.dart';
import 'src/chat/media/media_source.dart';
import 'src/chat/media/media_store.dart';
import 'src/macos/mac_window.dart';
import 'src/network/network_signals.dart';
import 'src/live_activities/live_activities.dart';
import 'src/notifications/local_notification_service.dart';
import 'src/notifications/notification_service.dart';
import 'src/notifications/notification_settings.dart';
import 'src/notifications/request_answers.dart';
import 'src/settings/theme_controller.dart';
import 'src/share/share_provider.dart';
import 'src/telemetry/breadcrumbs.dart';
import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';
import 'src/update/github_release_store.dart';
import 'src/voice/dictation_settings.dart';
import 'src/voice/on_device_speech.dart';
import 'src/watch/watch_bridge.dart';
import 'src/windows/conversation_window_app.dart';
import 'src/windows/conversation_windows.dart';
import 'src/windows/desktop_conversation_windows.dart';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (conversationWindowLaunch(args) case final window?) {
    return runConversationWindow(window.windowId, window.arguments);
  }
  await MacWindow.initialize();
  final telemetry = await Telemetry.initialize(
    TelemetryConfig.fromEnvironment(),
  );
  telemetry.logUncaughtErrors();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => HandoffController(HandoffBridge())..start(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            telemetry: telemetry.forConnection,
            networkSignals: ConnectivityNetworkSignals(),
          )..bootstrap(),
        ),
        ProxyProvider<AuthController, HermesRepositories?>(
          update: (_, auth, previous) =>
              HermesRepositories.forAuth(auth, previous),
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
        Provider<Breadcrumbs>.value(value: telemetry.breadcrumbs()),
        ChangeNotifierProvider<ConversationWindows?>(
          lazy: false,
          create: (context) {
            if (!MacWindow.enabled) return null;
            final auth = context.read<AuthController>();
            final windows = ConversationWindows(
              host: DesktopConversationWindowHost(),
              store: ConversationWindowStore(SharedPreferencesAsync()),
              connection: () {
                final baseUrl = auth.baseUrl;
                if (auth.state != HermesConnectionState.ready ||
                    baseUrl == null) {
                  return null;
                }
                return (
                  baseUrl: baseUrl,
                  authRequired: auth.status?.authRequired ?? true,
                );
              },
              headers: auth.windowAuthHeaders,
              breadcrumbs: context.read<Breadcrumbs>(),
            );
            // An expired session keeps the windows for after the sign-in.
            auth.signedOut.listen(
              (_) => windows.closeAll(forget: !auth.sessionExpired),
            );
            return windows;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
        ChangeNotifierProvider(create: (_) => DictationSettings()..load()),
        // One app-wide listener: the recognizer's event channel has a single
        // native sink.
        Provider<OnDeviceSpeech>(
          create: (_) => OnDeviceSpeech(),
          dispose: (_, speech) => speech.dispose(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => AppLockController()..load(),
        ),
        Provider<LiveActivities?>(
          lazy: false,
          create: (context) {
            if (defaultTargetPlatform != TargetPlatform.iOS) return null;
            return LiveActivities(
              service: PluginLiveActivityService(),
              settings: context.read<NotificationSettings>(),
              signedOut: context.read<AuthController>().signedOut,
              breadcrumbs: context.read<Breadcrumbs>(),
            )..start();
          },
          dispose: (_, activities) => activities?.dispose(),
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
            events: telemetry.events(),
            notifications: context.read<NotificationService>(),
            settings: context.read<NotificationSettings>(),
            speech: context.read<OnDeviceSpeech>(),
            dictation: context.read<DictationSettings>(),
          )?..start(),
          dispose: (_, bridge) => bridge?.dispose(),
        ),
        Provider<RequestAnswers?>(
          lazy: false,
          create: (context) {
            if (defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform != TargetPlatform.macOS) {
              return null;
            }
            return RequestAnswers.forAuth(
              context.read<AuthController>(),
              service: context.read<NotificationService>(),
              breadcrumbs: context.read<Breadcrumbs>(),
            )..start();
          },
          dispose: (_, answers) => answers?.dispose(),
        ),
        shareProvider(),
      ],
      child: HermesApp(updateChecker: createUpdateChecker()),
    ),
  );
}
