import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import '../chat/billing_fixtures.dart' show billingVerificationFixture;
import '../chat/connector_fixtures.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

class _Lock extends AppLockController {
  @override
  bool get covered => false;
}

/// What waits on the user, docked above the composer: a connector sign-in
/// answered and not confirmed, the connection lost, billing verification and
/// two requests at once, on a phone and a desktop in both themes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('desktop', desktopSize, TargetPlatform.linux),
  ]) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$name, $mode: sign-in, unconfirmed, offline, billing', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('needs-you-$name-$mode');
        final gateway = FakeGateway()..activeSessions = {};
        gateway.silent.add('connection.respond');
        gateway.handlers['session.resume'] = (params) => {
          'session_id': 'rt-1',
          'stored_session_id': params['session_id'],
          'session_key': params['session_id'],
        };
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/profiles',
            profileListBody([profileRow(name: 'default', isDefault: true)]),
          )
          ..on(
            'GET',
            '/api/profiles/active',
            activeProfileBody(active: 'default'),
          )
          ..on(
            'GET',
            '/api/sessions',
            sessionListBody([
              sessionRow(id: 'stored-1', title: 'Weekly digest'),
            ]),
          )
          ..on(
            'GET',
            '/api/sessions/stored-1/messages',
            messageListBody('stored-1', [
              messageRow(
                id: 1,
                role: 'user',
                content: 'Add the Notion pages to the weekly digest.',
              ),
              messageRow(
                id: 2,
                role: 'assistant',
                content: 'I need access to Notion first.',
              ),
            ]),
          );
        final profiles = ChatProfiles(
          HermesProfilesRepository(server.client().raw),
        );
        addTearDown(profiles.dispose);
        await shots.start(tester, size);
        await pumpChatScreen(
          tester,
          server: server,
          withProfiles: true,
          transport: transport,
          chatProfiles: profiles,
          size: size,
          platform: platform,
          theme: withScreenshotFont(
            dark
                ? buildHermesDarkTheme(platform: platform)
                : buildHermesLightTheme(platform: platform),
          ),
          wrap: shots.frame,
          providers: [
            ChangeNotifierProvider<AppLockController>(create: (_) => _Lock()),
          ],
        );
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              (_) async => null,
            );

        Future<void> settle() async {
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump();
          }
        }

        await openThread(tester, 'Weekly digest');
        await settle();
        await shots.capture(tester, 'chat');

        gateway.event('connection.request', 'rt-1', {
          ...connectionRequestFixture,
          'deadline_at':
              DateTime.now().millisecondsSinceEpoch / 1000 + 4 * 60 + 30,
          'targets': [
            {
              ...(connectionRequestFixture['targets']! as List).single
                  as Map<String, Object?>,
              'name': 'Notion',
              'instructions': 'Continue in the browser to approve access.',
            },
          ],
        });
        await settle();
        await shots.capture(tester, 'sign-in-waiting');

        await tester.tap(find.byKey(const Key('needs-you-continue')));
        await tester.pump();
        await shots.capture(tester, 'sending');

        await tester.pump(const Duration(seconds: 10));
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.byKey(const Key('needs-you-continue')),
              )
              .onPressed,
          isNotNull,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await shots.capture(tester, 'unconfirmed');

        gateway.drop();
        await settle();
        await tester.pump(const Duration(milliseconds: 300));
        await shots.capture(tester, 'offline');

        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('$name, $mode: two requests, paged', (tester) async {
        final shots = ScreenshotRecorder('needs-you-paged-$name-$mode');
        final gateway = FakeGateway()..activeSessions = {};
        gateway.handlers['session.resume'] = (params) => {
          'session_id': 'rt-1',
          'stored_session_id': params['session_id'],
          'session_key': params['session_id'],
        };
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/profiles',
            profileListBody([profileRow(name: 'default', isDefault: true)]),
          )
          ..on(
            'GET',
            '/api/profiles/active',
            activeProfileBody(active: 'default'),
          )
          ..on(
            'GET',
            '/api/sessions',
            sessionListBody([
              sessionRow(id: 'stored-1', title: 'Weekly digest'),
            ]),
          )
          ..on(
            'GET',
            '/api/sessions/stored-1/messages',
            messageListBody('stored-1', [
              messageRow(id: 1, role: 'user', content: 'Run the digest.'),
            ]),
          );
        final profiles = ChatProfiles(
          HermesProfilesRepository(server.client().raw),
        );
        addTearDown(profiles.dispose);
        await shots.start(tester, size);
        await pumpChatScreen(
          tester,
          server: server,
          withProfiles: true,
          transport: transport,
          chatProfiles: profiles,
          size: size,
          platform: platform,
          theme: withScreenshotFont(
            dark
                ? buildHermesDarkTheme(platform: platform)
                : buildHermesLightTheme(platform: platform),
          ),
          wrap: shots.frame,
          providers: [
            ChangeNotifierProvider<AppLockController>(create: (_) => _Lock()),
          ],
        );
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              (_) async => null,
            );
        Future<void> settle() async {
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump();
          }
        }

        await openThread(tester, 'Weekly digest');
        await settle();
        gateway.event('connection.request', 'rt-1', {
          ...connectionRequestFixture,
          'deadline_at':
              DateTime.now().millisecondsSinceEpoch / 1000 + 4 * 60 + 30,
        });
        await settle();
        gateway.event(
          'billing.step_up.verification',
          'rt-1',
          billingVerificationFixture,
        );
        await settle();
        await shots.capture(tester, 'one-of-two');

        await tester.tap(find.byKey(const Key('needs-you-next')));
        await tester.pump();
        await shots.capture(tester, 'two-of-two');

        final target =
            (connectionRequestFixture['targets']! as List).single
                as Map<String, Object?>;
        gateway.event('connection.request', 'rt-1', {
          ...connectionRequestFixture,
          'op_id': 'two-targets',
          'deadline_at':
              DateTime.now().millisecondsSinceEpoch / 1000 + 4 * 60 + 30,
          'targets': [
            {...target, 'name': 'Notion'},
            {...target, 'name': 'Google Calendar'},
          ],
        });
        await settle();
        await tester.tap(find.byKey(const Key('needs-you-next')));
        await tester.pump();
        await shots.capture(tester, 'three-of-three-two-targets');

        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
