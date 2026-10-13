import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/background_check_controller.dart';
import 'package:hermes_app/src/background/background_scheduler.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/notifications/notifications_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Tasks implements PeriodicTasks {
  @override
  Future<bool?> isScheduled(String name) async => true;
  @override
  Future<void> initialize(Function dispatcher) async {}
  @override
  Future<void> cancel(String name) async {}
  @override
  Future<void> register(String name, {required Duration interval}) async {}
}

void main() {
  testWidgets(
    'fresh permission removes a cached denial warning in the open dialog',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final settings = NotificationSettings();
      await settings.recordPermission(granted: false);
      final changes = ChangeNotifier();
      final ended = StreamController<void>.broadcast();
      final permission = Completer<bool?>();
      final checks = BackgroundCheckController(
        changes: changes,
        account: () => null,
        signedOut: ended.stream,
        permission: () => permission.future,
        tasks: _Tasks(),
        name: () async => 'refresh',
        platform: TargetPlatform.android,
        observeLifecycle: false,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: checks),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showNotificationsDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Turn on notifications for Hermes in system settings.'),
        findsOneWidget,
      );
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Notifications: Allowed'), findsOneWidget);
      expect(
        find.text('Turn on notifications for Hermes in system settings.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      checks.dispose();
      settings.dispose();
      changes.dispose();
      await ended.close();
    },
  );
}
