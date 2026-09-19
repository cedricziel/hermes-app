import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// Sending through a [ChatTransport]: the streamed reply, from the composer
/// through the real widget tree, against a fake dashboard for the session
/// list and a hand-driven fake transport for the reply.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(id: 3, role: 'user', content: 'Draft the release notes.'),
        ]),
      );
  });

  /// Runs [body], then lets the transcript's scroll timers fire.
  void chatTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pumpChat(WidgetTester tester, {ShareController? share}) async {
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
            create: (_) => share ?? ShareController(FakeShareInbox()),
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
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, FakeSend send, ChatEvent event) async {
    send.emit(event);
    await tester.pump();
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  List<ChatThread> sidebarThreads(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).threads;

  List<Object> transcriptMessages(WidgetTester tester) =>
      tester.widget<Chat>(find.byType(Chat)).chatController.messages;

  chatTest('a send shows the prompt and a thinking placeholder at once', (
    tester,
  ) async {
    await pumpChat(tester);

    await send(tester, 'Any news?');

    expect(inTranscript('Any news?'), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsOneWidget);
    expect(transport.sends.single.text, 'Any news?');
  });

  chatTest('no canned reply appears when a transport is present', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');

    await tester.pump(const Duration(seconds: 2));

    expect(inTranscript('placeholder reply'), findsNothing);
    expect(find.byType(ThinkingIndicator), findsOneWidget);
  });

  chatTest('the composer clears on send', (tester) async {
    await pumpChat(tester);

    await send(tester, 'Any news?');

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, isEmpty);
  });

  chatTest('deltas stream text into the reply', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyStarted());
    expect(find.byType(ThinkingIndicator), findsOneWidget);

    await emit(tester, reply, const ReplyDelta('Nothing '));
    expect(find.byType(ThinkingIndicator), findsNothing);
    expect(inTranscript('Nothing'), findsOneWidget);

    await emit(tester, reply, const ReplyDelta('new.'));
    expect(inTranscript('Nothing new.'), findsOneWidget);

    await emit(tester, reply, const ReplyCompleted('Nothing new.'));
    expect(inTranscript('Nothing new.'), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsNothing);
  });

  chatTest('a tool shows as a running card, then completes', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ToolStarted(name: 'web_search'));
    var card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
    expect(card.call.name, 'web_search');
    expect(card.call.status, ToolCallStatus.running);

    await emit(tester, reply, const ToolFinished(name: 'web_search'));
    card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
    expect(card.call.status, ToolCallStatus.completed);

    await emit(tester, reply, const ReplyDelta('Found it.'));
    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(inTranscript('Found it.'), findsOneWidget);
  });

  chatTest('a failed tool shows an error card', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ToolStarted(name: 'web_search'));
    await emit(
      tester,
      reply,
      const ToolFinished(name: 'web_search', failed: true),
    );

    final card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
    expect(card.call.status, ToolCallStatus.error);
  });

  chatTest('a failed completion shows the reply as an error', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Let me'));
    await emit(
      tester,
      reply,
      const ReplyCompleted('Model unavailable', failed: true),
    );

    expect(inTranscript('Model unavailable'), findsOneWidget);
    final last = transcriptMessages(tester).last as TextMessage;
    expect(last.metadata, {'error': true});
  });

  chatTest('a dropped stream marks the reply as an error', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');

    transport.sends.single.fail();
    await tester.pump();

    expect(inTranscript(kReplyFailedMessage), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsNothing);
    final last = transcriptMessages(tester).last as TextMessage;
    expect(last.metadata, {'error': true});
  });

  chatTest('a stream that ends without a completion is an error', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    final reply = transport.sends.single;

    await emit(tester, reply, const ReplyDelta('Half an ans'));
    reply.finish();
    await tester.pump();

    expect(inTranscript('Half an ans'), findsOneWidget);
    final last = transcriptMessages(tester).last as TextMessage;
    expect(last.metadata, {'error': true});
  });

  chatTest('the user can send again after a dropped stream', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Any news?');
    transport.sends.single.fail();
    await tester.pump();

    await send(tester, 'Try again');
    final retry = transport.sends.last;
    await emit(tester, retry, const ReplyDelta('Here you go.'));
    await emit(tester, retry, const ReplyCompleted('Here you go.'));

    expect(transport.sends, hasLength(2));
    expect(inTranscript('Here you go.'), findsOneWidget);
    expect(inTranscript(kReplyFailedMessage), findsOneWidget);
  });

  chatTest('sending to a server thread passes its id', (tester) async {
    await pumpChat(tester);

    await send(tester, 'And then?');

    expect(transport.sends.single.threadId, 's1');
  });

  chatTest('a send into a loaded thread appends after its messages', (
    tester,
  ) async {
    await pumpChat(tester);

    await send(tester, 'And then?');
    await emit(tester, transport.sends.single, const ReplyCompleted('Then.'));

    expect(inTranscript('Why did the run fail?'), findsOneWidget);
    expect(inTranscript('A connection reset.'), findsOneWidget);
    expect(inTranscript('And then?'), findsOneWidget);
    expect(inTranscript('Then.'), findsOneWidget);
  });

  chatTest('sending to a new local thread passes no id', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();

    await send(tester, 'Fresh start');

    expect(transport.sends.single.threadId, isNull);
  });

  group('a new thread bound by the dashboard', () {
    Future<FakeSend> startNewThread(WidgetTester tester) async {
      await pumpChat(tester);
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await send(tester, 'Fresh start');
      return transport.sends.single;
    }

    chatTest('takes the dashboard id, keeping a single row', (tester) async {
      final reply = await startNewThread(tester);

      await emit(tester, reply, const ThreadBound('dash-1'));

      final threads = sidebarThreads(tester);
      expect(threads, hasLength(3));
      expect(threads.map((t) => t.id), contains('dash-1'));
      expect(threads.map((t) => t.title), contains('Fresh start'));
    });

    chatTest('gets the next send under that id', (tester) async {
      final reply = await startNewThread(tester);
      await emit(tester, reply, const ThreadBound('dash-1'));
      await emit(tester, reply, const ReplyCompleted('Hello'));

      await send(tester, 'Next');

      expect(transport.sends.last.threadId, 'dash-1');
    });

    chatTest('keeps streaming into the same transcript', (tester) async {
      final reply = await startNewThread(tester);

      await emit(tester, reply, const ThreadBound('dash-1'));
      await emit(tester, reply, const ReplyDelta('Hello'));

      expect(inTranscript('Fresh start'), findsOneWidget);
      expect(inTranscript('Hello'), findsOneWidget);
    });

    chatTest('keeps its transcript when opened again', (tester) async {
      final reply = await startNewThread(tester);
      await emit(tester, reply, const ThreadBound('dash-1'));
      await emit(tester, reply, const ReplyCompleted('Hello'));

      await tester.tap(find.text('Release notes'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text('Fresh start'),
        ),
      );
      await tester.pumpAndSettle();

      expect(inTranscript('Hello'), findsOneWidget);
      expect(
        server.requestsTo('GET', '/api/sessions/dash-1/messages'),
        isEmpty,
      );
    });

    chatTest('is titled by the dashboard in the sidebar and top bar', (
      tester,
    ) async {
      final reply = await startNewThread(tester);
      await emit(tester, reply, const ThreadBound('dash-1'));

      await emit(tester, reply, const ThreadTitled('Getting started'));

      expect(find.text('Getting started'), findsNWidgets(2));
      expect(
        sidebarThreads(tester).map((t) => t.title),
        contains('Getting started'),
      );
    });
  });

  chatTest('a title for a server thread renames it', (tester) async {
    await pumpChat(tester);
    await send(tester, 'And then?');

    await emit(tester, transport.sends.single, const ThreadTitled('Renamed'));

    expect(find.text('Renamed'), findsNWidgets(2));
    expect(find.text('Run failure'), findsNothing);
  });

  chatTest('a reply keeps its thread when the user switches away', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'And then?');
    final reply = transport.sends.single;
    await emit(tester, reply, const ReplyDelta('Streaming '));

    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();
    await emit(tester, reply, const ReplyDelta('on'));
    await emit(tester, reply, const ReplyCompleted('Streaming on'));

    expect(inTranscript('Streaming'), findsNothing);
    expect(inTranscript('Draft the release notes.'), findsOneWidget);

    await tester.tap(find.text('Run failure'));
    await tester.pumpAndSettle();
    expect(inTranscript('Streaming on'), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsNothing);
  });

  chatTest('a thread opened mid-stream shows the reply so far', (tester) async {
    await pumpChat(tester);
    await send(tester, 'And then?');
    final reply = transport.sends.single;
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();

    await emit(tester, reply, const ReplyDelta('Partial'));
    await tester.tap(find.text('Run failure'));
    await tester.pumpAndSettle();

    expect(inTranscript('Partial'), findsOneWidget);
  });

  chatTest('replies stay beside their prompt when sends overlap', (
    tester,
  ) async {
    await pumpChat(tester);

    await send(tester, 'FIRSTQ');
    await send(tester, 'SECONDQ');
    final [first, second] = transport.sends;
    await emit(tester, second, const ReplyCompleted('SECONDA'));
    await emit(tester, first, const ReplyDelta('FIRST'));
    await emit(tester, first, const ReplyCompleted('FIRSTA'));

    double top(String text) {
      final found = find.descendant(
        of: find.byType(Chat),
        matching: find.text(text, findRichText: true),
      );
      expect(found, findsOneWidget);
      return tester.getTopLeft(found).dy;
    }

    final ordered = [
      top('FIRSTQ'),
      top('FIRSTA'),
      top('SECONDQ'),
      top('SECONDA'),
    ];
    expect(ordered, orderedEquals([...ordered]..sort()));
    expect(find.byType(ThinkingIndicator), findsNothing);
  });

  chatTest('an attachments-only send goes out naming the files', (
    tester,
  ) async {
    final share = ShareController(
      FakeShareInbox([
        const SharedFile(path: '/tmp/a/report.pdf', name: 'report.pdf'),
      ]),
    );
    await share.start();
    await pumpChat(tester, share: share);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(transport.sends.single.text, 'Attached: report.pdf');
    expect(find.byTooltip('Remove report.pdf'), findsNothing);
  });
}
