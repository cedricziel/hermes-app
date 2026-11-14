import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/attention_notifier.dart' show appLockHidesRequests;
import '../../notifications/notification_service.dart';
import '../../notifications/notification_settings.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';
import '../../voice/dictation_settings.dart';
import '../../voice/on_device_speech.dart';
import '../../watch/watch_bridge.dart';
import '../../watch/watch_complication.dart';

/// The watch complication status and the watch bridge.
List<SingleChildWidget> watchProviders(Telemetry telemetry) => [
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
      context.read<AuthController>().signedOut.listen((_) => status.clear());
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
];
