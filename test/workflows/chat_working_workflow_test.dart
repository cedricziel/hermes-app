import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/working_dot.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// A turn running in a thread this client never streamed — started on the TUI
/// or another device — on a phone and on a desktop: the working mark in the
/// thread list, and the thread opened mid-turn showing its replying
/// indicator. A spinner never settles, so nothing here pumps until settle.
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
          sessionRow(id: 's1', title: 'Backup failure', lastActive: 1780000900),
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

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: a turn running elsewhere', (tester) async {
      final shots = ScreenshotRecorder('chat-working-$name');
      await pumpScreen(
        tester,
        shots,
        ChatScreen(
          repository: HermesChatRepository(server.client().raw),
          transport: transport,
        ),
        size: size,
      );

      await openSidebar(tester);
      transport.active['s1'] = 'working';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await runFrames(tester);
      expect(find.byType(WorkingDot), findsOneWidget);
      await shots.capture(tester, 'thread-list-working');

      await tester.tap(find.byKey(const ValueKey('thread-s1')));
      await runFrames(tester);
      transport.followUpStreams['s1']!.emit(const ReplyStarted());
      transport.followUpStreams['s1']!.emit(const ReplyDelta('Still digging.'));
      await runFrames(tester);
      expect(find.text('Stop'), findsOneWidget);
      await shots.capture(tester, 'picked-up-replying');

      transport.active.clear();
      transport.followUpStreams['s1']!.emit(
        const ReplyCompleted('It was the retry loop.'),
      );
      await runFrames(tester);
      expect(find.text('Stop'), findsNothing);
      await runFrames(tester);
    });
  }
}
