import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_device_authenticator.dart';
import 'fake_notification_service.dart';
import 'fake_share_inbox.dart';
import 'screenshot_recorder.dart';

/// The providers `main` sets up around [HermesApp], minus telemetry, the
/// platform share inbox and native notifications.
List<SingleChildWidget> workflowProviders(AppLockController appLock) => [
  ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
  ChangeNotifierProvider<AppLockController>.value(value: appLock),
  ChangeNotifierProvider(create: (_) => NotificationSettings()),
  Provider<NotificationService>.value(value: FakeNotificationService()),
];

/// An unlocked [AppLockController] on a device with no biometrics. Set
/// `SharedPreferencesAsyncPlatform.instance` first.
Future<AppLockController> newAppLock(WidgetTester tester) async {
  final appLock = AppLockController(authenticator: FakeDeviceAuthenticator());
  addTearDown(appLock.dispose);
  await tester.runAsync(appLock.load);
  return appLock;
}

/// Mounts the whole [HermesApp] in light mode.
///
/// The test binding answers every HTTP request with 400, so this lifts that
/// for the test: [auth] talks to a real [LocalDashboard]. Set
/// `SharedPreferencesAsyncPlatform.instance` before building [auth]. End the
/// test with [letSocketsIdle].
Future<void> pumpWorkflowApp(
  WidgetTester tester,
  ScreenshotRecorder shots, {
  required AuthController auth,
}) async {
  HttpOverrides.global = null;
  await shots.start(tester, phoneSize);
  final appLock = await newAppLock(tester);
  await tester.pumpWidget(
    shots.frame(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ...workflowProviders(appLock),
        ],
        child: HermesApp(
          lightTheme: withScreenshotFont(buildHermesLightTheme()),
          darkTheme: withScreenshotFont(buildHermesDarkTheme()),
        ),
      ),
    ),
  );
}

/// Lets the keep-alive timers of the app's HTTP connections run out, which the
/// test would otherwise report as still pending.
Future<void> letSocketsIdle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 10));

/// Pumps until [finder] matches, giving real sockets time to answer in
/// between (the fake clock does not move them). It ends on a fixed pump, not
/// `pumpAndSettle`, since a spinner on screen never settles.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  throw TestFailure('never found $finder');
}

/// Mounts one screen (or any [home]) in a themed [MaterialApp] at [size], with
/// the providers most screens read.
Future<void> pumpScreen(
  WidgetTester tester,
  ScreenshotRecorder shots,
  Widget home, {
  Size size = phoneSize,
  Brightness brightness = Brightness.light,
  List<SingleChildWidget> providers = const [],
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await shots.start(tester, size);
  final dark = brightness == Brightness.dark;
  await tester.pumpWidget(
    shots.frame(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ...providers,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withScreenshotFont(
            dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pops the top route, as the system back gesture does.
Future<void> popRoute(WidgetTester tester) {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  return tester.pumpAndSettle();
}

/// Opens the thread sidebar on a phone, where it is a drawer; on a wide screen
/// it is always there.
Future<void> openSidebar(WidgetTester tester) async {
  if (find.byType(ThreadSidebar).evaluate().isNotEmpty) return;
  await tester.tap(find.byIcon(Icons.menu).first);
  await tester.pumpAndSettle();
}

/// Lets a chat's scroll and fade animations play out frame by frame, as they
/// would on a device. `pumpAndSettle` cannot be used while a spinner runs, and
/// one long pump skips frames the list relies on.
Future<void> runFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// One frame to start the animations a change triggers (a floating label, an
/// error line, a button's colours) and a second to run them out.
Future<void> animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
