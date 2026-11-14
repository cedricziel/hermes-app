import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../background/background_check_controller.dart';
import '../../background/background_scheduler.dart';
import '../../live_activities/live_activities.dart';
import '../../notifications/local_notification_service.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/notification_settings.dart';
import '../../notifications/request_answers.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// The iOS Live Activity and the notification service.
List<SingleChildWidget> liveActivityProviders() => [
  Provider<LiveActivities?>(
    lazy: false,
    create: (context) {
      if (defaultTargetPlatform != TargetPlatform.iOS) return null;
      return LiveActivities(
        service: PluginLiveActivityService(),
        settings: context.read<NotificationSettings>(),
        appLock: context.read<AppLockController>(),
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
];

/// Notification answers and the background refresh.
List<SingleChildWidget> backgroundProviders(Telemetry telemetry) => [
  Provider<RequestAnswers?>(
    lazy: false,
    create: (context) {
      if (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS &&
          defaultTargetPlatform != TargetPlatform.android) {
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
];
