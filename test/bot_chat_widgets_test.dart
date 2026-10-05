import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_chat_banner.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_handoff_body.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';

const owner = BotModeBot(
  serverId: 'server',
  name: 'research',
  revision: 0,
  displayName: 'Research Specialist',
);
const peers = [
  owner,
  BotModeBot(
    serverId: 'server',
    name: 'writer',
    revision: 0,
    displayName: 'Alex',
  ),
  BotModeBot(
    serverId: 'server',
    name: 'editor',
    revision: 0,
    displayName: 'Alex',
  ),
  BotModeBot(
    serverId: 'server',
    name: 'default',
    revision: 0,
    displayName: 'Hermes',
  ),
];
const botContext = BotChatContext(
  bot: owner,
  rootId: 'root',
  storedId: 'tip',
  peers: peers,
);

void main() {
  testWidgets('bot context exposes friendly title and owner without renaming', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BotChatBanner(context: botContext)),
      ),
    );
    expect(find.textContaining('Research Specialist'), findsOneWidget);
    expect(find.textContaining('@research'), findsOneWidget);
  });
  testWidgets(
    'selected teammate inserts exact owner handle despite ambiguous titles',
    (tester) async {
      final text = TextEditingController(text: 'Ask @al');
      addTearDown(text.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              controller: text,
              onSend: (_) {},
              onRemoveAttachment: (_) {},
              botContext: botContext,
            ),
          ),
        ),
      );
      expect(find.text('@writer'), findsOneWidget);
      expect(find.text('@editor'), findsOneWidget);
      await tester.tap(find.text('@writer'));
      expect(text.text, 'Ask @writer ');
    },
  );
  testWidgets('queued and ambiguous receipts never imply completed delivery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BotHandoffBody(data: {'status': 'queued', 'to': '@writer'}),
        ),
      ),
    );
    expect(find.text('Queued · awaiting outcome'), findsOneWidget);
    expect(find.text('Reply received'), findsNothing);
    expect(find.textContaining('Do not resend'), findsOneWidget);
  });
  test('unknown tokens and email addresses stay unchanged', () {
    expect(botContext.suggestions('email user@example.com', 22), isEmpty);
    expect(botContext.suggestions('Ask @unknown', 12), isEmpty);
    expect(botContext.suggestions('@h', 2).single.handle, 'hermes');
  });
}
