import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart' show composerField;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _bot = BotModeBot(
  serverId: 'fixture',
  name: 'research',
  revision: 1,
  displayName: 'Research Specialist',
);
const _writer = BotModeBot(
  serverId: 'fixture',
  name: 'writer',
  revision: 1,
  displayName: 'Writer',
);
void main() {
  for (final (label, size, brightness) in [
    ('phone', phoneSize, Brightness.light),
    ('desktop', desktopSize, Brightness.light),
    ('phone-dark', phoneSize, Brightness.dark),
    ('desktop-dark', desktopSize, Brightness.dark),
  ]) {
    testWidgets('canonical bot chat $label', (tester) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions', sessionListBody([]))
        ..on(
          'GET',
          '/api/sessions/root',
          sessionRow(id: 'root', title: 'Bot Chat'),
        )
        ..on('GET', '/api/sessions/root/messages', messageListBody('root', []));
      final transport = FakeChatTransport();
      final requests = ChatOpenRequests()
        ..request(
          const NotificationTarget(threadId: 'root', profile: 'research'),
          bot: const BotChatContext(
            bot: _bot,
            rootId: 'root',
            storedId: 'root',
            peers: [_bot, _writer],
          ),
        );
      addTearDown(requests.dispose);
      final shots = ScreenshotRecorder('bot-chat-$label');
      await pumpScreen(
        tester,
        shots,
        ChatScreen(
          repository: HermesChatRepository(server.client().raw),
          transport: transport,
          openRequests: requests,
        ),
        size: size,
        brightness: brightness,
      );
      expect(find.textContaining('@research'), findsOneWidget);
      await shots.capture(tester, 'canonical-empty');
      await tester.enterText(composerField, 'Ask @wr');
      await tester.pumpAndSettle();
      await shots.capture(tester, 'mentions');
      await tester.tap(find.text('@writer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      final send = transport.sends.single;
      send.emit(
        const ToolStarted(
          id: 'dm',
          name: 'message_agent',
          summary: 'Message to @writer',
          args: {'target': 'writer'},
        ),
      );
      send.emit(
        const ToolFinished(
          id: 'dm',
          name: 'message_agent',
          resultData: {
            'status': 'queued',
            'to': '@writer',
            'detail': 'Waiting for Writer to return an attributed reply.',
          },
        ),
      );
      send.emit(
        const ReplyCompleted(
          'The handoff is queued; its outcome will appear here.',
        ),
      );
      await tester.pumpAndSettle();
      expect(send.text, 'Ask @writer');
      await tester.tap(find.text('message_agent'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Queued · awaiting outcome'), findsWidgets);
      await shots.capture(tester, 'queued-handoff');
      await tester.tap(find.byKey(const Key('header-thread-actions')));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
      await tester.tap(find.text('Retire Bot Chat…'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('next time you open this bot'),
        findsOneWidget,
      );
      await shots.capture(tester, 'retirement-confirmation');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  }
}
