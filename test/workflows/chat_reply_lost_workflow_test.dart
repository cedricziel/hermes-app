import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/starter_context_loader.dart';
import 'package:hermes_app/src/chat/widgets/reply_interrupted_note.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// A reply streaming with a tool call while the server restarts: the chat shows
/// the interrupted note beside the composer, Stop is gone, the message typed
/// meanwhile waits in a paused queue, and nothing is sent again.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/dashboard/plugins', <Object?>[])
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Backup failure', lastActive: 1780000900),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1',
        sessionRow(id: 's1', title: 'Backup failure', lastActive: 1780000900),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Earlier question'),
          messageRow(id: 2, role: 'assistant', content: 'Earlier answer.'),
        ]),
      )
      ..on('GET', '/api/model/options', {
        'model': 'demo',
        'provider': 'demo',
        'providers': [
          {
            'slug': 'demo',
            'name': 'Demo',
            'models': ['demo'],
          },
        ],
      });
  });

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: a restarted server leaves a note, no Stop and a '
        'paused queue', (tester) async {
      ReplyInterruptedNote.forgetAnnouncements();
      final shots = ScreenshotRecorder('chat-reply-lost-$name');
      await pumpScreen(
        tester,
        shots,
        ChatScreen(
          repository: HermesChatRepository(server.client().raw),
          models: HermesModelsRepository(server.client().raw),
          transport: transport,
          starterContext: StarterContextLoader(
            HermesRepositories(server.client()),
          ),
        ),
        size: size,
      );
      await openSidebar(tester);
      await tester.tap(find.byKey(const ValueKey('thread-s1')));
      await tester.pumpAndSettle();

      await tester.enterText(composerField, 'Run the build');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await runFrames(tester);
      final reply = transport.sends.single;
      reply
        ..emit(const ReplyStarted())
        ..emit(const ReplyDelta('Starting the build. '))
        ..emit(const ToolStarted(name: 'terminal', id: 't1', summary: 'make'));
      await runFrames(tester);

      // Typed while the reply runs: it waits.
      await tester.enterText(composerField, 'And then deploy');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await runFrames(tester);
      expect(find.byTooltip('Stop'), findsOneWidget);
      await shots.capture(tester, 'running');

      reply.fail(const GatewaySessionGone(4007, restarted: true));
      await runFrames(tester);

      expect(
        find.text('Hermes restarted. This reply was interrupted.'),
        findsOneWidget,
      );
      expect(
        find.text('Something went wrong. Try sending it again.'),
        findsNothing,
      );
      expect(find.byTooltip('Stop'), findsNothing);
      expect(find.textContaining('Queue paused'), findsWidgets);
      expect(find.text('And then deploy'), findsWidgets);
      // Nothing was resent, and the queued message was not sent by itself.
      expect(transport.sends, hasLength(1));
      await shots.capture(tester, 'interrupted');
    });
  }
}
