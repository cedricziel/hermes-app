import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The transcript follows a streaming reply while the reader is at the
/// bottom, and leaves them alone once they scroll up.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server
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
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
        ]),
      );
  });

  ScrollPosition transcript(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ChatAnimatedList),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      )
      .position;

  double distanceFromBottom(WidgetTester tester) {
    final position = transcript(tester);
    return position.maxScrollExtent - position.pixels;
  }

  /// What a mouse wheel over the transcript does; a negative [dy] scrolls up.
  Future<void> wheel(WidgetTester tester, double dy) async {
    transcript(tester).pointerScroll(dy);
    await tester.pumpAndSettle();
  }

  Future<FakeSend> startReply(WidgetTester tester) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');
    await tester.enterText(find.byType(EditableText), 'Tell me everything');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final reply = transport.sends.single..emit(const ReplyStarted());
    await tester.pump();
    return reply;
  }

  Future<void> streamLines(
    WidgetTester tester,
    FakeSend reply,
    int count,
  ) async {
    for (var i = 0; i < count; i++) {
      reply.emit(ReplyDelta('Line $i of a long answer.\n\n'));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a streaming reply stays in view while it grows', (tester) async {
    final reply = await startReply(tester);

    await streamLines(tester, reply, 60);
    await tester.pump(const Duration(seconds: 1));

    expect(transcript(tester).maxScrollExtent, greaterThan(0));
    expect(distanceFromBottom(tester), lessThan(1));

    // Past the point where the scroll-to-bottom button's timer fires, the
    // list must keep following.
    await streamLines(tester, reply, 20);
    expect(distanceFromBottom(tester), lessThan(1));

    reply.finish();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('scrolling up stops following, scrolling back resumes it', (
    tester,
  ) async {
    final reply = await startReply(tester);
    await streamLines(tester, reply, 60);

    await wheel(tester, -400);
    final readingAt = transcript(tester).pixels;

    await streamLines(tester, reply, 10);
    expect(transcript(tester).pixels, readingAt);

    await wheel(tester, 4000);
    await streamLines(tester, reply, 10);
    expect(distanceFromBottom(tester), lessThan(1));

    reply.finish();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long thread opens at its latest message', (tester) async {
    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        for (var i = 0; i < 40; i++)
          messageRow(
            id: i,
            role: i.isEven ? 'user' : 'assistant',
            content: 'Message $i\n\nwith a second paragraph.',
          ),
      ]),
    );
    await pumpChatScreen(tester, server: server, transport: transport);
    await openThread(tester, 'Run failure');

    expect(transcript(tester).maxScrollExtent, greaterThan(0));
    expect(distanceFromBottom(tester), lessThan(1));
  });
}
