import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/screens/home_screen.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

class _ConnectionAuth extends CatalogAuth {
  _ConnectionAuth(FakeHermesServer server) : super(server: server, gated: true);
  int changes = 0;
  int signOuts = 0;
  @override
  Future<void> changeServer() async {
    changes++;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${platform.name} ${brightness.name}: address validation and connection recovery',
        (tester) async {
          final shots = ScreenshotRecorder(
            'connection-${platform.name}-${brightness.name}',
          );
          final server = FakeHermesServer()
            ..on('GET', '/api/status', {'detail': 'unavailable'}, status: 503);
          final auth = _ConnectionAuth(server);
          addTearDown(auth.dispose);
          final providers = [
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ];
          await pumpScreen(
            tester,
            shots,
            const ServerSetupScreen(),
            providers: providers,
            platform: platform,
            brightness: brightness,
            size: platform == TargetPlatform.iOS ? phoneSize : desktopSize,
          );
          await shots.capture(tester, 'setup');
          await tester.enterText(find.byType(EditableText), '');
          await tester.tap(find.text('Connect'));
          await tester.pumpAndSettle();
          expect(find.text('Enter a URL'), findsOneWidget);
          expect(server.requests, isEmpty);
          await shots.capture(tester, 'address-required');
          await pumpScreen(
            tester,
            shots,
            const HomeScreen(),
            providers: providers,
            platform: platform,
            brightness: brightness,
            size: platform == TargetPlatform.iOS ? phoneSize : desktopSize,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Could not load status'), findsOneWidget);
          await shots.capture(tester, 'status-failed');
          server.on('GET', '/api/status', {
            'auth_required': true,
            'auth_providers': ['oidc'],
            'version': '0.21.4',
          });
          await tester.tap(find.byKey(const Key('connection-refresh')));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          expect(find.text('0.21.4'), findsOneWidget);
          expect(find.text('Enabled (oidc)'), findsOneWidget);
          expect(server.requestsTo('GET', '/api/status').length, 2);
          await shots.capture(tester, 'status-recovered');
          await tester.ensureVisible(find.text('Sign out'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sign out'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Change server'));
          await tester.pumpAndSettle();
          expect(auth.signOuts, 1);
          expect(auth.changes, 1);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
