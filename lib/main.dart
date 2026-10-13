import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/drag_out/drag_out_source.dart';
import 'src/drag_out/drag_out_telemetry.dart';
import 'src/drag_out/mac_drag_out_source.dart';
import 'src/handoff/handoff_controller.dart';
import 'src/handoff/handoff_bridge.dart';
import 'src/api/hermes_repositories.dart';
import 'src/app_lock/app_lock_controller.dart';
import 'src/auth/auth_controller.dart';
import 'src/background/background_scheduler.dart';
import 'src/background/background_check_controller.dart';
import 'src/background/running_replies.dart';
import 'src/chat/media/media_source.dart';
import 'src/deep_links/deep_link_listener.dart';
import 'src/chat/media/media_store.dart';
import 'src/chat/media/quick_look.dart';
import 'src/core/signed_out_cleanup.dart';
import 'src/macos/dock/dock_menu_bridge.dart';
import 'src/macos/dock/dock_menu_controller.dart';
import 'src/macos/mac_window.dart';
import 'src/network/network_signals.dart';
import 'src/intents/ask_hermes.dart';
import 'src/intents/intent_shortcuts.dart';
import 'src/intents/intents_channel.dart';
import 'src/live_activities/live_activities.dart';
import 'src/notifications/attention_notifier.dart' show appLockHidesRequests;
import 'src/notifications/badge_controller.dart';
import 'src/notifications/local_notification_service.dart';
import 'src/notifications/notification_service.dart';
import 'src/macos/menu_bar_extra/menu_bar_extra_settings.dart';
import 'src/notifications/notification_settings.dart';
import 'src/notifications/request_answers.dart';
import 'src/quick_panel/global_shortcut.dart';
import 'src/quick_panel/quick_panel_shortcut.dart';
import 'src/schedules/schedule_baseline.dart';
import 'src/settings/theme_controller.dart';
import 'src/share/share_provider.dart';
import 'src/quick_actions/quick_actions_controller.dart';
import 'src/spotlight/chat_spotlight_indexer.dart';
import 'src/spotlight/spotlight_index.dart';
import 'src/spotlight/spotlight_links.dart';
import 'src/spotlight/spotlight_settings.dart';
import 'src/surfaces/surface_snapshot_store.dart';
import 'src/surfaces/surface_snapshots.dart';
import 'src/surfaces/widget_usage_reporter.dart';
import 'src/telemetry/breadcrumbs.dart';
import 'src/telemetry/telemetry.dart';
import 'src/telemetry/telemetry_config.dart';
import 'src/update/github_release_store.dart';
import 'src/voice/dictation_settings.dart';
import 'src/voice/on_device_speech.dart';
import 'src/watch/watch_bridge.dart';
import 'src/watch/watch_complication.dart';
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
                quickLook: platformQuickLook(),
              )
              ..clearOnSignOut(auth.signedOut)
              // Files from an earlier run that nobody opened again.
              ..sweep(mediaCacheMaxAge);
          },
          dispose: (_, store) => store?.dispose(),
        ),
        Provider<Breadcrumbs>.value(value: telemetry.breadcrumbs()),
        // Where the system search is; nothing off iOS. Its taps are links, so
        // it sits before the deep links.
        Provider<SpotlightIndex>(
          create: (_) => SpotlightIndex.forPlatform(events: telemetry.events()),
          dispose: (_, index) => index.dispose(),
        ),
        // Above the screens, so a link opened on the sign-in screen waits for
        // the shell. Only where the `hermes` scheme is registered.
        ChangeNotifierProvider<DeepLinks?>(
          lazy: false,
          create: (context) {
            if (kIsWeb ||
                (defaultTargetPlatform != TargetPlatform.iOS &&
                    defaultTargetPlatform != TargetPlatform.macOS &&
                    defaultTargetPlatform != TargetPlatform.android)) {
              return null;
            }
            return DeepLinks(
              links: linksWithSpotlight(
                AppLinks().uriLinkStream,
                context.read<SpotlightIndex>(),
                events: telemetry.events(),
              ),
              signedOut: context.read<AuthController>().signedOut,
              breadcrumbs: context.read<Breadcrumbs>(),
            );
          },
        ),
        Provider<GlobalShortcut?>(
          create: (_) => MacWindow.enabled ? ChannelGlobalShortcut() : null,
        ),
        // Null where nothing can be dragged out (every platform but macOS).
        // One source for the engine: a reconnect only swaps its telemetry, so
        // a drop in flight is still answered and later drops are logged
        // against the new server.
        ProxyProvider2<HermesRepositories?, Breadcrumbs, DragOutSource?>(
          update: (_, repositories, breadcrumbs, previous) {
            if (!MacDragOutSource.supported) return null;
            final telemetry = DragOutTelemetry.forConnection(
              repositories?.telemetry ?? const ConnectionTelemetry(),
              breadcrumbs,
            );
            if (previous case final MacDragOutSource source) {
              return source..telemetry = telemetry;
            }
            return MacDragOutSource(telemetry: telemetry);
          },
          dispose: (_, source) {
            if (source case final MacDragOutSource mac) mac.dispose();
          },
        ),
        ChangeNotifierProvider<ConversationWindows?>(
          lazy: false,
          create: (context) {
            if (!MacWindow.enabled) return null;
            final auth = context.read<AuthController>();
            final windows = ConversationWindows(
              host: DesktopConversationWindowHost(),
              store: ConversationWindowStore(SharedPreferencesAsync()),
              ownerKey: () => windowSessionOwnerKey(auth),
              connection: () {
                final baseUrl = auth.baseUrl;
                if (!auth.protectedRequestsAllowed ||
                    auth.state != HermesConnectionState.ready ||
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
              events: telemetry.events(),
            );
            windows.bindSession(auth);
            if (context.read<GlobalShortcut?>() case final shortcut?) {
              QuickPanelShortcut(
                shortcut: shortcut,
                windows: windows,
                events: telemetry.events(),
                breadcrumbs: context.read<Breadcrumbs>(),
              ).start();
            }
            return windows;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
        ChangeNotifierProvider(create: (_) => DictationSettings()..load()),
        ChangeNotifierProvider(
          create: (context) =>
              SpotlightSettings(breadcrumbs: context.read<Breadcrumbs>())
                ..load(),
        ),
        ChangeNotifierProvider(create: (_) => MenuBarExtraSettings()..load()),
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
        ChangeNotifierProvider<DockMenuController?>(
          lazy: false,
          create: (context) => MacWindow.enabled
              ? DockMenuController(
                  bridge: DockMenuBridge(),
                  unlock: context.read<AppLockController>().unlock,
                  breadcrumbs: context.read<Breadcrumbs>(),
                  events: telemetry.events(),
                )
              : null,
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
        // Widgets, quick actions and shortcuts read what the app shares
        // through the App Group; only phones have them. The Mac has none of
        // them but follows the open requests in its Dock badge, from local
        // state and without telemetry.
        Provider<SurfaceSnapshotStore?>(
          create: (_) {
            final mac = defaultTargetPlatform == TargetPlatform.macOS;
            if (!mac &&
                defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform != TargetPlatform.android) {
              return null;
            }
            return mac
                ? SurfaceSnapshotStore(storage: MemorySurfaceStorage())
                : SurfaceSnapshotStore(events: telemetry.events());
          },
          dispose: (_, store) => store?.dispose(),
        ),
        // What background runs announce when the app is away: replies that
        // were running when it left. Scheduled runs keep their baseline on
        // every platform, the app in front uses it too.
        Provider<RunningReplies?>(
          create: (_) =>
              defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android
              ? RunningReplies()
              : null,
        ),
        Provider<SignedOutCleanup>(
          lazy: false,
          create: (context) {
            final running = context.read<RunningReplies?>();
            final baseline = ScheduleBaseline();
            return SignedOutCleanup(
              context.read<AuthController>().signedOut,
              () => Future.wait([
                baseline.clear(),
                if (running != null) running.clearAll(),
                if (running != null) running.clearAnnounced(),
              ]),
            );
          },
          dispose: (_, cleanup) => cleanup.dispose(),
        ),
        // Only the iOS Home Screen widgets exist; the report says which are
        // placed, at most once a day.
        Provider<WidgetUsageReporter?>(
          lazy: false,
          create: (_) {
            if (defaultTargetPlatform != TargetPlatform.iOS) return null;
            final reporter = WidgetUsageReporter(events: telemetry.events());
            unawaited(reporter.report());
            return reporter;
          },
        ),
        ProxyProvider3<
          HermesRepositories?,
          SurfaceSnapshotStore?,
          AuthController,
          SurfaceSnapshots?
        >(
          lazy: false,
          update: (context, repositories, store, auth, previous) {
            if (store == null) return null;
            // The repositories outlive a session, so the connection state
            // says whether anyone is signed in.
            return (previous ??
                  SurfaceSnapshots(
                    store: store,
                    session: () => _surfaceSession(auth),
                    signedOut: auth.signedOut,
                    appLock: context.read<AppLockController>(),
                    // The Mac only has the Dock badge to feed.
                    localOnly: defaultTargetPlatform == TargetPlatform.macOS,
                  ))
              ..repositories = repositories
              ..sessionChanged();
          },
          dispose: (_, snapshots) => snapshots?.dispose(),
        ),
        // The icon's badge counts the open requests of the snapshot.
        Provider<BadgeController?>(
          lazy: false,
          create: (context) => BadgeController.forPlatform(
            platform: defaultTargetPlatform,
            store: context.read<SurfaceSnapshotStore?>(),
            settings: context.read<NotificationSettings>(),
            signedOut: context.read<AuthController>().signedOut,
            breadcrumbs: context.read<Breadcrumbs>(),
          )?..start(),
          dispose: (_, controller) => controller?.dispose(),
        ),
        Provider<QuickActionsController?>(
          lazy: false,
          create: (context) => QuickActionsController.forPlatform(
            store: context.read<SurfaceSnapshotStore?>(),
            deepLinks: context.read<DeepLinks?>(),
            platform: defaultTargetPlatform,
            events: telemetry.events(),
            breadcrumbs: context.read<Breadcrumbs>(),
          )?..start(),
          dispose: (_, controller) => controller?.dispose(),
        ),
        Provider<IntentShortcuts?>(
          lazy: false,
          create: (context) => IntentShortcuts.forPlatform(
            store: context.read<SurfaceSnapshotStore?>(),
            platform: defaultTargetPlatform,
          )?..start(),
          dispose: (_, shortcuts) => shortcuts?.dispose(),
        ),
        // "Ask Hermes" from Siri and Shortcuts, when the app's own engine is
        // the one that is up.
        Provider<IntentsChannel?>(
          lazy: false,
          create: (context) {
            if (defaultTargetPlatform != TargetPlatform.iOS) return null;
            final channel = IntentsChannel(
              AskHermes(
                engine: AskEngine.foreground,
                notifications: context.read<NotificationService>(),
                settings: context.read<NotificationSettings>(),
                events: telemetry.events(),
                breadcrumbs: context.read<Breadcrumbs>(),
                running: context.read<RunningReplies?>(),
                tracer: telemetry.forConnection(const {}).tracer,
              ),
              openLink: context.read<DeepLinks?>()?.open,
            );
            unawaited(channel.start());
            return channel;
          },
          dispose: (_, channel) => channel?.dispose(),
        ),
        Provider<ChatSpotlightIndexer?>(
          lazy: false,
          create: (context) {
            final store = context.read<SurfaceSnapshotStore?>();
            if (store == null || !SpotlightSettings.offered) return null;
            final auth = context.read<AuthController>();
            return ChatSpotlightIndexer(
              index: context.read<SpotlightIndex>(),
              settings: context.read<SpotlightSettings>(),
              store: store,
              appLock: context.read<AppLockController>(),
              signedOut: context.read<AuthController>().signedOut,
              session: () => _surfaceSession(auth),
              sessionChanges: auth,
              events: telemetry.events(),
            )..start();
          },
          dispose: (_, indexer) => indexer?.dispose(),
        ),
        Provider<WatchComplicationStatus?>(
          lazy: false,
          create: (context) {
            if (defaultTargetPlatform != TargetPlatform.iOS) return null;
            final appLock = context.read<AppLockController>();
            final status = WatchComplicationStatus.overChannel(
              const MethodChannel(WatchBridge.channelName),
              appLock: () => appLockHidesRequests(appLock),
              lockChanges: appLock,
              breadcrumbs: context.read<Breadcrumbs>(),
            );
            context.read<AuthController>().signedOut.listen(
              (_) => status.clear(),
            );
            return status;
          },
          dispose: (_, status) => status?.dispose(),
        ),
        // Read after the notification providers above: a provider only sees
        // the ones declared before it.
        Provider<WatchBridge?>(
          lazy: false,
          create: (context) => WatchBridge.forAuth(
            context.read<AuthController>(),
            durableSendState: true,
            requestsEnabled: true,
            events: telemetry.events(),
            notifications: context.read<NotificationService>(),
            settings: context.read<NotificationSettings>(),
            appLock: context.read<AppLockController>(),
            speech: context.read<OnDeviceSpeech>(),
            dictation: context.read<DictationSettings>(),
            complication: context.read<WatchComplicationStatus?>(),
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
              appLock: context.read<AppLockController>(),
              breadcrumbs: context.read<Breadcrumbs>(),
            )..start();
          },
          dispose: (_, answers) => answers?.dispose(),
        ),
        ChangeNotifierProvider<BackgroundCheckController>(
          lazy: false,
          create: (context) => BackgroundCheckController.forAuth(
            context.read<AuthController>(),
            context.read<NotificationService>(),
          )..start(),
        ),
        Provider<BackgroundScheduler>(
          lazy: false,
          create: (context) => BackgroundScheduler.forAuth(
            context.read<AuthController>(),
            events: telemetry.events(),
          )..start(),
          dispose: (_, scheduler) => scheduler.dispose(),
        ),
        shareProvider(),
      ],
      child: HermesApp(updateChecker: createUpdateChecker()),
    ),
  );
}

/// What the connection says about the account, for the surfaces that must
/// not trust a stored snapshot of an account that may be gone.
SurfaceSession _surfaceSession(AuthController auth) => switch (auth.state) {
  HermesConnectionState.ready => SurfaceSession.signedIn,
  HermesConnectionState.needsLogin ||
  HermesConnectionState.needsServerUrl => SurfaceSession.signedOut,
  _ => SurfaceSession.unknown,
};
