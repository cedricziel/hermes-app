import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart' show openThread;

/// Branching a chat from one of its replies into a new chat.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
          messageRow(id: 3, role: 'user', content: 'Can you retry it?'),
          messageRow(id: 4, role: 'assistant', content: 'It passed this time.'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/branch-1',
        sessionDetailRow(id: 'branch-1', title: 'Run failure #2'),
      )
      ..on(
        'GET',
        '/api/sessions/branch-1/messages',
        messageListBody('branch-1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
        ]),
      );
  });

  void chatTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    void Function()? arrange,
  }) {
    testWidgets(name, (tester) async {
      arrange?.call();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(
              create: (_) => AuthController(),
            ),
            ChangeNotifierProvider<ShareController>(
              create: (_) => ShareController(FakeShareInbox()),
            ),
          ],
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            home: ChatScreen(
              repository: HermesChatRepository(server.client().raw),
              transport: transport,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openThread(tester, 'Run failure');
      await body(tester);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  final branch = find.byTooltip('Branch in new chat');
  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  chatTest('every finished reply offers a branch', (tester) async {
    expect(branch, findsNWidgets(2));
  });

  chatTest('an earlier reply branches without the turns after it', (
    tester,
  ) async {
    await tester.tap(branch.first);
    await settle(tester);

    expect(transport.branches, [('s1', null, 1)]);
    expect(inTranscript('A connection reset.'), findsOneWidget);
    expect(inTranscript('It passed this time.'), findsNothing);
  });

  chatTest(
    'a stored prompt that starts with a slash still counts',
    (tester) async {
      await tester.tap(branch.first);
      await settle(tester);

      expect(transport.branches, [('s1', null, 1)]);
    },
    arrange: () {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
          messageRow(id: 3, role: 'user', content: '/srv/run.sh fails again'),
          messageRow(id: 4, role: 'assistant', content: 'It passed this time.'),
        ]),
      );
    },
  );

  chatTest('the latest reply branches the whole chat', (tester) async {
    await tester.tap(branch.last);
    await settle(tester);

    expect(transport.branches, [('s1', null, 0)]);
  });

  chatTest('no branch while one is on its way', (tester) async {
    final gate = transport.branchGate = Completer<void>();
    await tester.tap(branch.first);
    await tester.pump();
    await tester.pump();

    expect(branch, findsNothing);
    expect(find.text('Branching…'), findsOneWidget);

    gate.complete();
    await settle(tester);
    expect(transport.branches, hasLength(1));
  });

  chatTest('a failed branch stays in the chat and says so', (tester) async {
    await tester.tap(branch.first);
    await settle(tester);

    expect(inTranscript('It passed this time.'), findsOneWidget);
    expect(find.text("Hermes couldn't branch the chat."), findsOneWidget);
  }, arrange: () => transport.branchError = GatewayRpcException(5008, 'no'));

  chatTest('an incomplete branch is deleted again', (tester) async {
    var deleted = false;
    server.onRequest('DELETE', '/api/sessions/branch-1', (_) {
      deleted = true;
      return (status: 200, body: {'ok': true});
    });
    transport.branchError = BranchIncomplete(
      const BranchedThread('branch-1'),
      GatewayRpcException(5008, 'undo failed'),
    );

    await tester.tap(branch.first);
    await settle(tester);

    expect(deleted, isTrue);
    expect(inTranscript('It passed this time.'), findsOneWidget);
    expect(find.text("Hermes couldn't branch the chat."), findsOneWidget);
  });

  chatTest('a server that cannot branch says so', (tester) async {
    await tester.tap(branch.first);
    await settle(tester);

    expect(
      find.text(
        "This Hermes server can't branch chats. Update Hermes to branch.",
      ),
      findsOneWidget,
    );
  }, arrange: () => transport.branchResult = null);
}
