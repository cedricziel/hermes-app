import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/find_app_icon.dart';
import 'support/pump_chat.dart' show composerField;

class _FakeLink implements ConversationWindowLink {
  final calls = <String>[];
  final titles = <String>[];
  final commandsIn = StreamController<String>.broadcast(sync: true);
  final keysIn = StreamController<bool>.broadcast(sync: true);

  void dispose() {
    commandsIn.close();
    keysIn.close();
  }

  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};

  @override
  Stream<String> get commands => commandsIn.stream;

  @override
  Stream<bool> get keyChanges => keysIn.stream;

  @override
  void reportFocus(bool focused) => calls.add('focus:$focused');

  @override
  void reportThread(String title, {required bool pinned}) => titles.add(title);

  @override
  Future<void> showInMain(String threadId, String? profile) async =>
      calls.add('showInMain:$threadId:$profile');

  @override
  Future<void> showMain() async => calls.add('showMain');

  @override
  Future<void> present({
    required String frameName,
    required String title,
  }) async => calls.add('present:$title');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> share(String text, Rect anchor) async =>
      calls.add('share:$text');
}

const _args = ConversationWindowArgs(
  threadId: 's1',
  profile: 'work',
  title: 'Trip plan',
  baseUrl: 'https://hermes.test',
  authRequired: true,
);

void main() {
  late FakeHermesServer server;
  late _FakeLink link;
  late FakeChatTransport transport;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    link = _FakeLink();
    transport = FakeChatTransport();
    addTearDown(link.dispose);
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's2', title: 'Other', lastActive: 1780000100),
          sessionRow(id: 's1', title: 'Trip plan'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Where to?'),
          messageRow(id: 2, role: 'assistant', content: 'Lisbon'),
        ]),
      );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: ConversationWindowScreen(
          args: _args,
          link: link,
          chat: HermesChatRepository(server.client().raw),
          transport: transport,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only its chat, on its own profile', (tester) async {
    await pump(tester);

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    expect(find.text('work'), findsOneWidget);
    expect(find.byKey(chatComposerFieldKey), findsOneWidget);
    final sessions = server.requestsTo('GET', '/api/sessions').single;
    expect(sessions.queryParameters['profile'], 'work');
    expect(link.calls, contains('present:Trip plan'));
  });

  testWidgets('sends on the profile it was opened from', (tester) async {
    await pump(tester);

    await tester.enterText(composerField, 'And then?');
    await tester.pump();
    await tester.tap(findAppIcon(AppIcons.sendArrow));
    await tester.pump();

    final send = transport.sends.single;
    expect(send.threadId, 's1');
    expect(send.profile, 'work');
    send.emit(const ReplyCompleted('Porto next'));
    await tester.pumpAndSettle();
  });

  testWidgets('show in main window names the chat and its profile', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Show in Main Window'));

    expect(link.calls, contains('showInMain:s1:work'));
  });

  testWidgets('becoming key reads the chat again and tells the main window', (
    tester,
  ) async {
    await pump(tester);
    server.on('GET', '/api/sessions/s1', sessionRow(id: 's1', title: 'Porto'));

    link.keysIn.add(true);
    await tester.pumpAndSettle();

    expect(link.calls, contains('focus:true'));
    expect(find.text('Porto'), findsOneWidget);
    expect(link.titles, contains('Porto'));
  });

  testWidgets('closes when the main window says so', (tester) async {
    await pump(tester);

    link.commandsIn.add('close');
    await tester.pump();

    expect(link.calls, contains('close'));
  });

  testWidgets('the pin command pins the chat', (tester) async {
    await pump(tester);
    server.on(
      'PATCH',
      '/api/sessions/s1',
      sessionPatchBody(title: 'Trip plan', flags: {'pinned': true}),
    );

    link.commandsIn.add('pin');
    await tester.pumpAndSettle();

    expect(server.requestsTo('PATCH', '/api/sessions/s1'), hasLength(1));
    expect(find.byTooltip('Unpin ⇧⌘P'), findsOneWidget);
  });

  testWidgets('the archive command archives the chat and closes the window', (
    tester,
  ) async {
    await pump(tester);
    server.on(
      'PATCH',
      '/api/sessions/s1',
      sessionPatchBody(title: 'Trip plan', flags: {'archived': true}),
    );

    link.commandsIn.add('archive');
    await tester.pumpAndSettle();

    expect(link.calls, contains('close'));
  });

  testWidgets('a deleted chat closes its window', (tester) async {
    await pump(tester);
    server.on('DELETE', '/api/sessions/s1', {'ok': true});

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(server.requestsTo('DELETE', '/api/sessions/s1'), hasLength(1));
    expect(link.calls, contains('close'));
  });

  testWidgets('share hands the transcript to the share picker', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Share'));

    expect(
      link.calls,
      contains('share:## You\n\nWhere to?\n\n## Hermes\n\nLisbon'),
    );
  });
}
