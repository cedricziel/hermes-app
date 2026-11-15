import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/widgets/chat_history_state.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';

import 'package:hermes_app/src/theme/app_icons.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';
import 'support/screenshot_recorder.dart';
import 'support/find_app_icon.dart';
import 'support/workflow_app.dart';

/// What the transcript shows between picking a stored chat and its messages
/// being on screen, through the real screen, controller and client.
void main() {
  late FakeHermesServer server;
  // Made by the handler, inside the test's fake-async zone.
  Completer<void>? slow;
  var failing = true;

  setUp(() {
    slow = null;
    failing = true;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000500),
          sessionRow(id: 's3', title: 'Flaky chat', lastActive: 1780000400),
          sessionRow(id: 's4', title: 'Quick one', lastActive: 1780000300),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..onRequest('GET', '/api/sessions/s2/messages', (_) async {
        await (slow ??= Completer<void>()).future;
        return (
          status: 200,
          body: messageListBody('s2', [
            messageRow(id: 3, role: 'user', content: 'Draft the notes.'),
          ]),
        );
      })
      ..onRequest(
        'GET',
        '/api/sessions/s3/messages',
        (_) => failing
            ? (status: 500, body: {'detail': 'boom'})
            : (
                status: 200,
                body: messageListBody('s3', [
                  messageRow(id: 5, role: 'user', content: 'Back again.'),
                ]),
              ),
      )
      ..onRequest('GET', '/api/sessions/s4/messages', (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return (
          status: 200,
          body: messageListBody('s4', [
            messageRow(id: 7, role: 'user', content: 'Done quickly.'),
          ]),
        );
      });
  });

  final skeleton = find.byType(LoadingSkeleton);
  final welcome = find.text(kStarterPrompts.first);

  Future<void> pick(WidgetTester tester, String id) async {
    // A phone shows the chat list as a page, and a chat opens over it.
    if (find.byKey(ValueKey('thread-$id')).hitTestable().evaluate().isEmpty) {
      Navigator.of(tester.element(find.byType(Chat))).pop();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(ValueKey('thread-$id')));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> elapse(WidgetTester tester, int milliseconds) async {
    for (var left = milliseconds; left > 0; left -= 50) {
      await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
    }
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.text(text, findRichText: true),
  );

  for (final (name, size) in [
    ('phone', phoneSize),
    ('desktop', const Size(1400, 900)),
  ]) {
    group(name, () {
      testWidgets('a slow load shows a labelled skeleton after the delay, '
          'never the welcome view or the last chat', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpChatScreen(tester, server: server, size: size);
        await pick(tester, 's1');
        await elapse(tester, 400);
        expect(inTranscript('Why did the run fail?'), findsOneWidget);

        await pick(tester, 's2');
        // Nothing yet: not the welcome view, not the previous chat.
        await elapse(tester, 100);
        expect(skeleton, findsNothing);
        expect(welcome, findsNothing);
        expect(inTranscript('Why did the run fail?'), findsNothing);

        await elapse(tester, 400);
        expect(skeleton, findsOneWidget);
        expect(welcome, findsNothing);
        expect(inTranscript('Why did the run fail?'), findsNothing);
        final node = tester.getSemantics(find.bySemanticsLabel('Loading chat'));
        expect(node.flagsCollection.isLiveRegion, isTrue);

        slow!.complete();
        await elapse(tester, 400);
        expect(skeleton, findsNothing);
        expect(inTranscript('Draft the notes.'), findsOneWidget);
        expect(welcome, findsNothing);
        semantics.dispose();
      });

      testWidgets('a load that finishes inside the delay never flashes it', (
        tester,
      ) async {
        await pumpChatScreen(tester, server: server, size: size);
        await pick(tester, 's4');
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(skeleton, findsNothing);
          expect(welcome, findsNothing);
        }
        expect(inTranscript('Done quickly.'), findsOneWidget);
      });

      testWidgets('a failed load says so and Retry reads it again', (
        tester,
      ) async {
        await pumpChatScreen(tester, server: server, size: size);
        await pick(tester, 's3');
        await elapse(tester, 400);
        expect(find.text('Could not load the messages'), findsOneWidget);
        expect(skeleton, findsNothing);
        expect(welcome, findsNothing);

        failing = false;
        await tester.tap(find.text('Retry'));
        await elapse(tester, 400);
        expect(find.text('Could not load the messages'), findsNothing);
        expect(inTranscript('Back again.'), findsOneWidget);
      });

      testWidgets('a new chat keeps its welcome view', (tester) async {
        await pumpChatScreen(tester, server: server, size: size);
        if (size == phoneSize) {
          await tester.tap(findAppIcon(AppIcons.compose).first);
          await tester.pumpAndSettle();
        }
        expect(welcome, findsOneWidget);
        await elapse(tester, 600);
        expect(skeleton, findsNothing);
        expect(find.byType(ChatHistoryState), findsNothing);
      });
    });
  }

  testWidgets('a chat opened by a notification shows the loading state', (
    tester,
  ) async {
    final requests = ChatOpenRequests();
    await pumpScreen(
      tester,
      ScreenshotRecorder('chat-history-loading-notification'),
      ChatScreen(
        repository: HermesChatRepository(server.client().raw),
        openRequests: requests,
      ),
    );
    requests.request(const NotificationTarget(threadId: 's2'));
    await elapse(tester, 500);
    expect(skeleton, findsOneWidget);
    expect(welcome, findsNothing);
    slow!.complete();
    await elapse(tester, 400);
    expect(skeleton, findsNothing);
    expect(inTranscript('Draft the notes.'), findsOneWidget);
  });
}
