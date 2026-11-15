import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A typed prompt Hermes takes as the stop phrase of its voice mode runs no
/// turn: the screen says so and keeps the words.
void main() {
  testWidgets('a typed stop phrase says so and puts the words back', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]));
    final transport = FakeChatTransport();
    await pumpChatScreen(tester, server: server, transport: transport);

    await tester.enterText(composerField, 'stop');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    transport.sends.single
      ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
      ..finish();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Hermes took that as a stop command. Nothing was sent.'),
      findsOneWidget,
    );
    expect(tester.widget<EditableText>(composerField).controller.text, 'stop');
  });
}
