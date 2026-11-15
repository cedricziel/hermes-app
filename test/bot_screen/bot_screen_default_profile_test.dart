import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import 'bot_screen_repository_test.dart' show statusJson;

void main() {
  testWidgets('a chat on the default profile asks display.status for '
      '"default"', (tester) async {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) => statusJson();
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Book a table')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Book a table'),
        ]),
      );
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      size: desktopSize,
      platform: TargetPlatform.linux,
    );
    await openThread(tester, 'Book a table');
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }

    expect(gateway.requestOf('display.status')['params'], {
      'profile': 'default',
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  });
}
