import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/chat_branch_notice.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

String _descendant(String id) => '/api/sessions/$id/latest-descendant';

/// A branched chat and the way back to the chat it was copied from: the row
/// with the title known, while it opens, once it opened, and when the
/// original is gone or Hermes cannot be reached, on a phone and a desktop
/// window, light and dark.
///
/// It mounts [ChatScreen] rather than the whole app, as the other chat
/// workflows do: the row belongs to the chat screen.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(
            id: 'b1',
            title: 'Try the second approach',
            lastActive: 1780000900,
          )..['_branched_from'] = 'p1',
          sessionRow(
            id: 'p1',
            title: 'Plan the soil survey',
            lastActive: 1780000500,
          ),
        ]),
      );
    for (final id in ['b1', 'p1']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [
          messageRow(id: 1, role: 'user', content: 'How should we sample?'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'Along three transects, ten metres apart.',
          ),
        ]),
      );
    }
    server.on('GET', _descendant('p1'), {
      'requested_session_id': 'p1',
      'session_id': 'p1',
      'path': ['p1'],
      'changed': false,
    });
  });

  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openBranch(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
  }) async {
    await pumpScreen(
      tester,
      shots,
      ChatScreen(
        profileResolver: ProfileResolver.known('default'),
        repository: HermesChatRepository(server.client().raw),
        transport: FakeChatTransport(),
      ),
      size: size,
      brightness: brightness,
      platform: platform,
    );
    await idle(tester);
    await openSidebar(tester);
    await tester.tap(find.text('Try the second approach').first);
    await tester.pumpAndSettle();
    await idle(tester);
    expect(find.byType(ChatBranchNotice), findsOneWidget);
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;
    for (final (name, size, platform) in [
      ('android', phoneSize, TargetPlatform.android),
      ('mac', desktopSize, TargetPlatform.macOS),
      if (!dark) ('ios', phoneSize, TargetPlatform.iOS),
    ]) {
      testWidgets('$name ($mode): the row, and a tap to the original', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('branch-notice-$name-$mode');
        await openBranch(
          tester,
          shots,
          size: size,
          brightness: brightness,
          platform: platform,
        );
        await shots.capture(tester, 'branch');
        expect(
          find.textContaining('Branched from Plan the soil survey'),
          findsOneWidget,
        );

        await tester.tap(find.byType(ChatBranchNotice));
        await tester.pumpAndSettle();
        await idle(tester);
        await shots.capture(tester, 'original');

        expect(server.requestsTo('GET', _descendant('p1')), hasLength(1));
        expect(find.byType(ChatBranchNotice), findsNothing);
      });
    }
  }

  testWidgets('phone: opening, then the original was deleted', (tester) async {
    final answer = Completer<FakeResponse>();
    server.onRequest('GET', _descendant('p1'), (_) => answer.future);
    final shots = ScreenshotRecorder('branch-notice-phone-deleted');
    await openBranch(tester, shots, size: phoneSize);

    await tester.tap(find.byType(ChatBranchNotice));
    await tester.pump();
    await shots.capture(tester, 'opening');
    expect(find.text('Opening the original chat…'), findsOneWidget);

    answer.complete((status: 404, body: {'detail': 'Session not found'}));
    await idle(tester);
    await shots.capture(tester, 'deleted');
    expect(find.text('The original chat was deleted.'), findsOneWidget);
    await tester.tap(find.byType(ChatBranchNotice));
    await idle(tester);
    expect(server.requestsTo('GET', _descendant('p1')), hasLength(1));
  });

  testWidgets('phone: could not reach Hermes, then try again', (tester) async {
    server.on('GET', _descendant('p1'), {'detail': 'down'}, status: 503);
    final shots = ScreenshotRecorder('branch-notice-phone-unreachable');
    await openBranch(tester, shots, size: phoneSize);

    await tester.tap(find.byType(ChatBranchNotice));
    await idle(tester);
    await shots.capture(tester, 'unreachable');
    expect(find.textContaining('Try again'), findsOneWidget);

    server.on('GET', _descendant('p1'), {
      'requested_session_id': 'p1',
      'session_id': 'p1',
      'path': ['p1'],
      'changed': false,
    });
    await tester.tap(find.byType(ChatBranchNotice));
    await idle(tester);
    await shots.capture(tester, 'retried');
    expect(server.requestsTo('GET', _descendant('p1')), hasLength(2));
    expect(find.byType(ChatBranchNotice), findsNothing);
  });
}
