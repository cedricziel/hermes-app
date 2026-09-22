import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart' show openSidebarMore, openThread;

/// The chat follows the selected Hermes profile. Each profile keeps its own
/// sessions, so two profiles can hold different sessions under one id.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  /// One session, id `shared` in every profile, as [profile] serves it.
  void seedProfile(String profile, String title, String greeting) {
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'shared', title: title)]),
        query: {'profile': profile},
      )
      ..on(
        'GET',
        '/api/sessions/shared/messages',
        messageListBody('shared', [
          messageRow(id: 1, role: 'user', content: greeting),
        ]),
        query: {'profile': profile},
      );
  }

  void activate(String active, {String? current}) => server.on(
    'GET',
    '/api/profiles/active',
    activeProfileBody(active: active, current: current),
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work', displayName: 'Work assistant'),
        ]),
      )
      ..on('POST', '/api/profiles/active', {'ok': true});
    activate('default');
    seedProfile('default', 'Personal notes', 'hello from default');
    seedProfile('work', 'Sprint planning', 'hello from work');
  });

  Future<void> pumpChat(WidgetTester tester) async {
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
            profiles: HermesProfilesRepository(server.client().raw),
            transport: transport,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  Future<void> switchProfile(WidgetTester tester, String name) async {
    activate(name);
    await openSidebarMore(tester);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name == 'work' ? 'Work assistant' : name));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testWidgets('lists the sessions of the active profile', (tester) async {
    activate('work', current: 'default');
    await pumpChat(tester);

    expect(find.text('Sprint planning'), findsWidgets);
    expect(find.text('Personal notes'), findsNothing);
    final request = server.requestsTo('GET', '/api/sessions').single;
    expect(request.queryParameters['profile'], 'work');
  });

  testWidgets('reads the open session from the active profile', (tester) async {
    activate('work', current: 'default');
    await pumpChat(tester);
    await openThread(tester, 'Sprint planning');

    final request = server
        .requestsTo('GET', '/api/sessions/shared/messages')
        .single;
    expect(request.queryParameters['profile'], 'work');
    expect(inTranscript('hello from work'), findsOneWidget);
  });

  testWidgets('a failed profile lookup lists nothing and offers a retry', (
    tester,
  ) async {
    server.on('GET', '/api/profiles/active', {'detail': 'x'}, status: 500);
    await pumpChat(tester);

    expect(find.text('Could not load your chats'), findsOneWidget);
    expect(server.requestsTo('GET', '/api/sessions'), isEmpty);

    activate('work', current: 'default');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Sprint planning'), findsWidgets);
    final request = server.requestsTo('GET', '/api/sessions').single;
    expect(request.queryParameters['profile'], 'work');
  });

  testWidgets('a server without the profiles route lists unscoped', (
    tester,
  ) async {
    server.on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404);
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 's1', title: 'Whatever')]),
    );
    await pumpChat(tester);

    expect(find.text('Whatever'), findsWidgets);
    final request = server.requestsTo('GET', '/api/sessions').single;
    expect(request.queryParameters.containsKey('profile'), isFalse);
  });

  testWidgets('switching profile reloads the threads of the new profile', (
    tester,
  ) async {
    await pumpChat(tester);
    expect(find.text('Personal notes'), findsWidgets);

    await switchProfile(tester, 'work');

    expect(find.text('Sprint planning'), findsWidgets);
    expect(find.text('Personal notes'), findsNothing);
    final lists = server.requestsTo('GET', '/api/sessions');
    expect(lists.map((r) => r.queryParameters['profile']), ['default', 'work']);
  });

  testWidgets('a session id shared by two profiles shows the new transcript', (
    tester,
  ) async {
    await pumpChat(tester);
    await openThread(tester, 'Personal notes');
    expect(inTranscript('hello from default'), findsOneWidget);

    await switchProfile(tester, 'work');
    await openThread(tester, 'Sprint planning');

    expect(inTranscript('hello from work'), findsOneWidget);
    expect(inTranscript('hello from default'), findsNothing);
    final reads = server.requestsTo('GET', '/api/sessions/shared/messages');
    expect(reads.map((r) => r.queryParameters['profile']), ['default', 'work']);
  });

  testWidgets('switching back to a profile loads its transcript again', (
    tester,
  ) async {
    await pumpChat(tester);
    await switchProfile(tester, 'work');
    await openThread(tester, 'Sprint planning');

    await switchProfile(tester, 'default');
    await openThread(tester, 'Personal notes');

    expect(inTranscript('hello from default'), findsOneWidget);
    expect(inTranscript('hello from work'), findsNothing);
  });

  Future<void> sendMessage(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  testWidgets('switching profile stops following the old profile\'s thread', (
    tester,
  ) async {
    await pumpChat(tester);
    await sendMessage(tester, 'first');
    transport.sends.single
      ..emit(const ThreadBound('shared'))
      ..emit(const ReplyCompleted('ok'))
      ..finish();
    await tester.pumpAndSettle();
    final follow = transport.followUpStreams['shared']!;
    expect(follow.hasListener, isTrue);

    await switchProfile(tester, 'work');

    expect(follow.hasListener, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a message goes to the gateway under the shown profile', (
    tester,
  ) async {
    activate('work', current: 'default');
    await pumpChat(tester);
    await openThread(tester, 'Sprint planning');

    await sendMessage(tester, 'plan the sprint');

    expect(transport.sends.single.profile, 'work');
    expect(transport.sends.single.threadId, 'shared');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('after switching profile a new message uses the new profile', (
    tester,
  ) async {
    await pumpChat(tester);
    await sendMessage(tester, 'first');
    transport.sends.single
      ..emit(const ReplyCompleted('ok'))
      ..finish();
    await tester.pumpAndSettle();
    await switchProfile(tester, 'work');

    await sendMessage(tester, 'second');

    expect(transport.sends.map((s) => s.profile), ['default', 'work']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a message is not sent unscoped after a failed profile lookup', (
    tester,
  ) async {
    server.on('GET', '/api/profiles/active', {'detail': 'x'}, status: 500);
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 's1', title: 'Whatever')]),
    );
    await pumpChat(tester);
    expect(find.byType(EditableText), findsNothing);

    activate('work', current: 'default');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await sendMessage(tester, 'hello');

    expect(transport.sends.single.profile, 'work');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a message goes unscoped when the server has no profiles', (
    tester,
  ) async {
    server.on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404);
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 's1', title: 'Whatever')]),
    );
    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', const []),
    );
    await pumpChat(tester);

    await sendMessage(tester, 'hello');

    expect(transport.sends.single.profile, isNull);
    await tester.pump(const Duration(seconds: 1));
  });
}
