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
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

class _Lock extends AppLockController {
  @override
  bool get covered => false;
}

const _long =
    'Waiting for the nightly backup of the analytics warehouse on the '
    'staging cluster to finish';

/// The activity line while Hermes works: a memory recall beside the plan
/// counter, a long status that truncates, a process with a billing request
/// docked below, the inspector replacing the line, and the turn settling.
/// A spinner never settles, so nothing here pumps until settle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('desktop', desktopSize, TargetPlatform.linux),
  ]) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$name, $mode: recall, plan, long status, process, '
          'billing', (tester) async {
        final shots = ScreenshotRecorder('chat-activity-line-$name-$mode');
        final gateway = FakeGateway()..activeSessions = {};
        gateway.silent.add('billing.step_up');
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
                content: 'Back up the warehouse and write the digest.',
              ),
              messageRow(
                id: 2,
                role: 'assistant',
                content: 'Starting with the backup.',
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
          await tester.pump(const Duration(milliseconds: 300));
        }

        await openThread(tester, 'Weekly digest');
        await settle();
        await shots.capture(tester, 'idle');

        gateway.event('todo.updated', 'rt-1', {
          'revision': 1,
          'todos': [
            {'id': 'a', 'content': 'Back up', 'status': 'completed'},
            {'id': 'b', 'content': 'Write the digest', 'status': 'pending'},
            {'id': 'c', 'content': 'Send it', 'status': 'pending'},
            {'id': 'd', 'content': 'Archive', 'status': 'pending'},
            {'id': 'e', 'content': 'Report', 'status': 'pending'},
          ],
        });
        gateway.event('status.update', 'rt-1', {
          'kind': 'lifecycle',
          'text': '🧠 robot-notes — recalled 5 memories',
        });
        await settle();
        expect(find.byKey(const Key('activity-line')), findsOneWidget);
        await shots.capture(tester, 'recall-with-plan');

        gateway.event('status.update', 'rt-1', {
          'kind': 'process',
          'text': _long,
        });
        await settle();
        await shots.capture(tester, 'long-status');

        gateway.event('agent.terminal.output', 'rt-1', {
          'process_id': 'backup',
          'chunk': 'dumping tables',
        });
        gateway.event(
          'billing.step_up.verification',
          'rt-1',
          billingVerificationFixture,
        );
        await settle();
        await shots.capture(tester, 'process-and-billing');

        await tester.tap(find.byKey(const Key('activity-line')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await shots.capture(tester, 'panel-opened');

        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
