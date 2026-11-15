import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';

import '../bot_screen/bot_screen_repository_test.dart' show statusJson;
import '../support/fake_gateway.dart';
import '../support/find_app_icon.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

/// A chat with no profile of its own works in the profile the dashboard was
/// launched with (`current` of `GET /api/profiles/active`), never in a
/// literal `default` and never in the sticky `active` one.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;

  setUp(() {
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) => statusJson();
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'main', 'current': 'work'})
      ..on('GET', '/api/chat/workspaces', {
        'home': '/home/u',
        'projects': <Object?>[],
        'repos': <Object?>[],
      })
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {
            ...sessionRow(id: 'stored-1', title: 'Book a table'),
            'cwd': '/srv/notes',
          },
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Book a table'),
        ]),
      );
  });

  Future<void> openChatWithActivity(WidgetTester tester) async {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      workspaces: HermesWorkspacesRepository(
        server.client().raw,
        transport.requestKeepingConnection,
      ),
      size: desktopSize,
      platform: TargetPlatform.linux,
    );
    await openThread(tester, 'Book a table');
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Bot Screen asks for the launch profile', (tester) async {
    await openChatWithActivity(tester);

    expect(gateway.requestOf('display.status')['params'], {'profile': 'work'});
    await close(tester);
  });

  testWidgets('the workspace catalog is read for the launch profile', (
    tester,
  ) async {
    await openChatWithActivity(tester);
    await tester.tap(findAppIcon(AppIcons.compose).first);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();

    final reads = server.requestsTo('GET', '/api/chat/workspaces').toList();
    expect(reads, isNotEmpty);
    expect(reads.map((r) => r.queryParameters['profile']).toSet(), {'work'});
    await close(tester);
  });
}
