import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
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

Map<String, Object?> _options(String model) => {
  'model': model,
  'provider': 'anthropic',
  'providers': [
    {
      'slug': 'anthropic',
      'name': 'Anthropic',
      'authenticated': true,
      'models': [model, 'claude-haiku-4-5'],
      'capabilities': {
        model: {'reasoning': true},
        'claude-haiku-4-5': {'reasoning': false},
      },
    },
  ],
};

/// The composer's model pill: which model and effort a chat runs on.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  void activate(String active) => server.on(
    'GET',
    '/api/profiles/active',
    activeProfileBody(active: active),
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
    for (final (profile, model) in [
      ('default', 'claude-opus-4'),
      ('work', 'claude-sonnet-4-5'),
    ]) {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's-$profile', title: profile)]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/s-$profile/messages',
          messageListBody('s-$profile', []),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/model/options',
          _options(model),
          query: {'profile': profile},
        );
    }
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
            models: HermesModelsRepository(server.client().raw),
            transport: transport,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final pill = find.byKey(const Key('composer-model-pill'));

  Future<void> pick(WidgetTester tester, List<String> keys) async {
    await tester.tap(pill);
    await tester.pumpAndSettle();
    for (final key in keys) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  void finishReply() {
    transport.sends.last
      ..emit(const ReplyCompleted('ok'))
      ..finish();
  }

  testWidgets('names the profile\'s model and sends none until one is '
      'picked', (tester) async {
    await pumpChat(tester);

    expect(
      find.descendant(of: pill, matching: find.text('claude-opus-4')),
      findsOneWidget,
    );
    await send(tester, 'hi');

    expect(transport.sends.single.model, isNull);
  });

  testWidgets('a new chat is sent with the model and effort picked', (
    tester,
  ) async {
    await pumpChat(tester);

    await pick(tester, ['effort-high']);
    expect(find.text(' · High'), findsOneWidget);
    await send(tester, 'hi');

    expect(
      transport.sends.single.model,
      const ModelChoice('anthropic', 'claude-opus-4', effort: 'high'),
    );
  });

  testWidgets('an open chat keeps its own choice', (tester) async {
    await pumpChat(tester);
    await openThread(tester, 'default');

    await pick(tester, ['model-anthropic-claude-haiku-4-5']);
    await send(tester, 'first');
    finishReply();
    await tester.pumpAndSettle();
    await send(tester, 'second');

    expect(transport.sends.map((s) => s.model), [
      const ModelChoice('anthropic', 'claude-haiku-4-5'),
      const ModelChoice('anthropic', 'claude-haiku-4-5'),
    ]);
    expect(
      find.descendant(of: pill, matching: find.text('claude-haiku-4-5')),
      findsOneWidget,
    );
    transport.sends.last
      ..emit(const ReplyCompleted('', failed: true))
      ..finish();
    await tester.pumpAndSettle();
  });

  testWidgets('switching profile loads its models and drops the choice', (
    tester,
  ) async {
    await pumpChat(tester);
    await pick(tester, ['effort-low']);

    activate('work');
    await openSidebarMore(tester);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work assistant'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: pill, matching: find.text('claude-sonnet-4-5')),
      findsOneWidget,
    );
    expect(find.textContaining(' · '), findsNothing);
    expect(
      server
          .requestsTo('GET', '/api/model/options')
          .map((r) => r.queryParameters['profile']),
      ['default', 'work'],
    );
  });

  testWidgets('no pill when the options cannot be read', (tester) async {
    server.on(
      'GET',
      '/api/model/options',
      {'detail': 'boom'},
      status: 500,
      query: {'profile': 'default'},
    );
    await pumpChat(tester);

    expect(pill, findsNothing);
    await send(tester, 'hi');
    expect(transport.sends.single.model, isNull);
  });

  testWidgets('the sidebar opens the helper models of the chat\'s profile', (
    tester,
  ) async {
    activate('work');
    server.on('GET', '/api/model/auxiliary', {
      'tasks': [
        {'task': 'vision', 'provider': 'auto', 'model': ''},
      ],
      'main': {'provider': 'anthropic', 'model': 'claude-sonnet-4-5'},
    });
    await pumpChat(tester);

    await openSidebarMore(tester);
    await tester.tap(find.text('Helper models'));
    await tester.pumpAndSettle();

    expect(find.text('Same as main model (claude-sonnet-4-5)'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/model/auxiliary').single.queryParameters,
      {'profile': 'work'},
    );
  });
}
