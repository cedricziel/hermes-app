import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      );
  });

  final composerField = find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(EditableText),
  );

  Future<FakeSend> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  Future<void> pump(WidgetTester tester) =>
      pumpChatScreen(tester, server: server, transport: transport);

  testWidgets('no Stop while nothing is replying', (tester) async {
    await pump(tester);

    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('Stop shows while a reply is in flight and stops that thread', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    await send(tester, 'One');
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(transport.stops, ['s1']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Stop is gone once the reply ended', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'One');

    turn.emit(const ReplyCompleted('', stopped: true));
    await tester.pump();

    expect(find.text('Stop'), findsNothing);
    expect(find.text('Stopped.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sending works again after a stop', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(const ReplyCompleted('', stopped: true));
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a stop that fails says so and stays available', (tester) async {
    await pump(tester);
    await send(tester, 'One');
    transport.answerError = Exception('socket closed');

    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(find.text('Could not stop the reply. Try again.'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
