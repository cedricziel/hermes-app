import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The new chat a wide window opens on takes the keyboard at once.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Telegram pairing')]),
      );
  });

  bool composerFocused(WidgetTester tester) =>
      tester.widget<EditableText>(composerField).focusNode.hasFocus;

  testWidgets('a wide window opens with the cursor in the composer', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);

    expect(composerFocused(tester), isTrue);
  });

  testWidgets('a phone opens on the chat list without the keyboard', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server, size: const Size(390, 844));

    expect(composerField, findsNothing);
  });
}
