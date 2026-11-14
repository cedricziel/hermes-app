import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../agent_messages/agent_message_record.dart';
import '../../api/hermes_repositories.dart';
import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../background/running_replies.dart';
import '../../core/signed_out_cleanup.dart';
import '../../deep_links/deep_link_listener.dart';
import '../../intents/ask_hermes.dart';
import '../../intents/intent_shortcuts.dart';
import '../../intents/intents_channel.dart';
import '../../notifications/badge_controller.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/notification_settings.dart';
import '../../quick_actions/quick_actions_controller.dart';
import '../../schedules/schedule_baseline.dart';
import '../../spotlight/chat_spotlight_indexer.dart';
import '../../spotlight/spotlight_index.dart';
import '../../spotlight/spotlight_settings.dart';
import '../../surfaces/surface_snapshot_store.dart';
import '../../surfaces/surface_snapshots.dart';
import '../../surfaces/widget_usage_reporter.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// Widgets, quick actions, Spotlight, intents and the state they share.
List<SingleChildWidget> surfaceProviders(Telemetry telemetry) => [
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
      final messages = AgentMessageRecord();
      return SignedOutCleanup(
        context.read<AuthController>().signedOut,
        () => Future.wait([
          baseline.clear(),
          messages.clear(),
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
];

/// What the connection says about the account, for the surfaces that must
/// not trust a stored snapshot of an account that may be gone.
SurfaceSession _surfaceSession(AuthController auth) => switch (auth.state) {
  HermesConnectionState.ready => SurfaceSession.signedIn,
  HermesConnectionState.needsLogin ||
  HermesConnectionState.needsServerUrl => SurfaceSession.signedOut,
  _ => SurfaceSession.unknown,
};
