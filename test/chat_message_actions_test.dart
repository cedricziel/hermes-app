import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart' show composerField, openThread;

/// The action bar under a finished reply: copy, and asking again on the
/// latest one.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late List<String> copied;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    transport = FakeChatTransport();
    copied = [];
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
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

  void chatTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    void Function()? arrange,
  }) {
    testWidgets(name, (tester) async {
      arrange?.call();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(
              create: (_) => AuthController(),
            ),
            ChangeNotifierProvider<ShareController>(
              create: (_) => ShareController(FakeShareInbox()),
            ),
          ],
          child: MaterialApp(
            theme: buildHermesLightTheme(),
            home: ChatScreen(
              repository: HermesChatRepository(server.client().raw),
              transport: transport,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openThread(tester, 'Run failure');
      await body(tester);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, FakeSend send, ChatEvent event) async {
    send.emit(event);
    await tester.pump();
    await tester.pump();
  }

  final copy = find.byTooltip('Copy');
  final tryAgain = find.byTooltip('Try again');
  final editPrompt = find.byTooltip('Edit prompt');
  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  chatTest('a loaded reply can be copied and asked again', (tester) async {
    expect(copy, findsOneWidget);
    expect(tryAgain, findsOneWidget);

    await tester.tap(copy);
    await tester.pump();

    expect(copied, ['A connection reset.']);
    expect(find.byTooltip('Copied'), findsOneWidget);
  });

  chatTest('the copied tick goes away after a moment', (tester) async {
    await tester.tap(copy);
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));

    expect(find.byTooltip('Copied'), findsNothing);
    expect(copy, findsOneWidget);
  });

  chatTest('trying again replaces the last turn', (tester) async {
    await tester.tap(tryAgain);
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));

    expect(transport.undos, [('s1', true)]);
    expect(transport.sends.single.text, 'Why did the run fail?');
    expect(transport.sends.single.threadId, 's1');
    expect(inTranscript('A connection reset.'), findsNothing);
    expect(inTranscript('Why did the run fail?'), findsOneWidget);
  });

  chatTest('no second undo while one is in flight', (tester) async {
    final gate = transport.undoGate = Completer<void>();
    await tester.tap(tryAgain);
    await tester.pump();

    expect(editPrompt, findsNothing);
    await tester.tap(tryAgain);
    await tester.pump();

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(transport.undos, [('s1', true)]);
    expect(transport.sends, hasLength(1));
  });

  chatTest('a server that cannot undo still tries again as a new turn', (
    tester,
  ) async {
    await tester.tap(tryAgain);
    await tester.pump();

    expect(transport.sends.single.text, 'Why did the run fail?');
    expect(inTranscript('A connection reset.'), findsOneWidget);
  }, arrange: () => transport.undoRemoved = null);

  chatTest('a failed undo sends nothing and says so', (tester) async {
    await tester.tap(tryAgain);
    await tester.pump();

    expect(transport.sends, isEmpty);
    expect(inTranscript('A connection reset.'), findsOneWidget);
    expect(find.textContaining('Could not try again'), findsOneWidget);
  }, arrange: () => transport.undoError = StateError('busy'));

  chatTest('editing puts the last prompt back in the composer', (tester) async {
    await tester.tap(editPrompt);
    await tester.pump();

    expect(transport.undos, [('s1', false)]);
    expect(transport.sends, isEmpty);
    expect(inTranscript('A connection reset.'), findsNothing);
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Why did the run fail?',
    );
  });

  chatTest('editing on a server that cannot undo says so', (tester) async {
    await tester.tap(editPrompt);
    await tester.pump();

    expect(inTranscript('A connection reset.'), findsOneWidget);
    expect(find.textContaining("can't edit"), findsOneWidget);
  }, arrange: () => transport.undoRemoved = null);

  chatTest('no action bar while the reply is being written', (tester) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Nothing '));

    expect(tryAgain, findsNothing);
    expect(copy, findsOneWidget);
  });

  chatTest('once a newer reply finishes, only it can be asked again', (
    tester,
  ) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Nothing new.'));
    await emit(tester, reply, const ReplyCompleted('Nothing new.'));

    await tester.pump(const Duration(seconds: 1));
    expect(copy, findsNWidgets(2));
    expect(tryAgain, findsOneWidget);

    await tester.tap(tryAgain);
    await tester.pump();

    expect(transport.sends.last.text, 'Any news?');
  });

  chatTest('a failed reply offers to try again but not to copy', (
    tester,
  ) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyCompleted('', failed: true));
    await tester.pump(const Duration(seconds: 1));

    expect(copy, findsOneWidget, reason: 'only the earlier reply');
    expect(tryAgain, findsOneWidget);
  });

  chatTest('a reply cut off can still copy what it kept', (tester) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Half an answer'));
    await emit(tester, reply, const ReplyCompleted('', failed: true));
    await tester.pump(const Duration(seconds: 1));

    expect(copy, findsNWidgets(2));
    expect(tryAgain, findsOneWidget);
  });

  chatTest('a reply stopped after some text is marked Stopped', (tester) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Nothing ne'));
    await emit(tester, reply, const ReplyCompleted('', stopped: true));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('Nothing ne'), findsOneWidget);
  });

  chatTest('a reply that completes is not marked Stopped', (tester) async {
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyCompleted('Nothing new.'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Stopped'), findsNothing);
  });

  chatTest(
    'a prompt that was only files cannot be tried again',
    (tester) async {
      expect(copy, findsOneWidget);
      expect(tryAgain, findsNothing);
    },
    arrange: () => server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 1, role: 'user', content: ''),
        messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
      ]),
    ),
  );
}
