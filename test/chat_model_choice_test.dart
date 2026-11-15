import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
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
import 'support/pump_chat.dart' show composerField, openSidebarMore, openThread;

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
    await tester.enterText(composerField, text);
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
    expect(find.textContaining(' · High'), findsOneWidget);
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
      ['default', 'default', 'work', 'work'],
    );
  });

  testWidgets('a failed model read preserves the draft until Retry succeeds', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/model/options',
      {'detail': 'boom'},
      status: 500,
      query: {'profile': 'default'},
    );
    await pumpChat(tester);

    expect(pill, findsOneWidget);
    expect(find.text('Could not load models'), findsOneWidget);
    await tester.enterText(composerField, 'hi');
    await tester.pump();
    final sendButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendButton.onPressed, isNull);
    server.on(
      'GET',
      '/api/model/options',
      _options('claude-opus-4'),
      query: {'profile': 'default'},
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('claude-opus-4'), findsOneWidget);
    expect(tester.widget<EditableText>(composerField).controller.text, 'hi');
    expect(transport.sends, isEmpty);
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

    expect(find.text('Main model'), findsOneWidget);
    expect(
      find.textContaining('Main model is claude-sonnet-4-5.'),
      findsOneWidget,
    );
    expect(
      server.requestsTo('GET', '/api/model/auxiliary').single.queryParameters,
      {'profile': 'work'},
    );
  });

  group('follows the server default', () {
    void serverDefault(String model, {String profile = 'default'}) => server.on(
      'GET',
      '/api/model/options',
      _options(model),
      query: {'profile': profile},
    );

    int reads() => server.requestsTo('GET', '/api/model/options').length;

    Finder shows(String model) =>
        find.descendant(of: pill, matching: find.text(model));

    // One profile, so New chat starts a chat without asking who it is for.
    void onlyDefaultProfile() => server.on(
      'GET',
      '/api/profiles',
      profileListBody([profileRow(name: 'default', isDefault: true)]),
    );

    Future<void> newChat(WidgetTester tester, {bool settle = true}) async {
      await tester.tap(find.text('New chat').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RecipientPicker),
          matching: find.text('default'),
        ),
      );
      if (settle) await tester.pumpAndSettle();
      if (!settle) await tester.pump();
    }

    Future<void> background(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('a new chat shows the changed default and sends no model', (
      tester,
    ) async {
      onlyDefaultProfile();
      await pumpChat(tester);
      await openThread(tester, 'default');
      expect(shows('claude-opus-4'), findsOneWidget);

      serverDefault('deepseek-v3');
      await newChat(tester);

      expect(shows('deepseek-v3'), findsOneWidget);
      await send(tester, 'hi');
      expect(transport.sends.single.model, isNull);
      finishReply();
      await tester.pumpAndSettle();
    });

    testWidgets('returning from the background shows the changed default', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await pumpChat(tester);
      expect(shows('claude-opus-4'), findsOneWidget);

      serverDefault('deepseek-v3');
      await background(tester);

      expect(shows('deepseek-v3'), findsOneWidget);
    });

    testWidgets('an explicit pick survives a new chat and a resume', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      onlyDefaultProfile();
      await pumpChat(tester);
      await pick(tester, ['model-anthropic-claude-haiku-4-5']);

      serverDefault('deepseek-v3');
      await newChat(tester);
      await background(tester);

      expect(shows('claude-haiku-4-5'), findsOneWidget);
      await send(tester, 'hi');
      expect(
        transport.sends.single.model,
        const ModelChoice('anthropic', 'claude-haiku-4-5'),
      );
      finishReply();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed refresh keeps the last options and shows no error', (
      tester,
    ) async {
      onlyDefaultProfile();
      await pumpChat(tester);
      await openThread(tester, 'default');

      server.on(
        'GET',
        '/api/model/options',
        {'detail': 'boom'},
        status: 500,
        query: {'profile': 'default'},
      );
      final before = reads();
      await newChat(tester);

      expect(reads(), before + 1);
      expect(shows('claude-opus-4'), findsOneWidget);
      expect(find.text('Could not load models'), findsNothing);
      expect(find.text('Loading models'), findsNothing);
    });

    testWidgets('an answer that arrives after a profile switch is dropped', (
      tester,
    ) async {
      await pumpChat(tester);
      await openThread(tester, 'default');
      final held = Completer<void>();
      server.onRequest('GET', '/api/model/options', (_) async {
        await held.future;
        return (status: 200, body: _options('deepseek-v3'));
      }, query: {'profile': 'default'});

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      activate('work');
      await openSidebarMore(tester);
      await tester.tap(find.text('Profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      held.complete();
      await tester.pumpAndSettle();

      expect(shows('claude-sonnet-4-5'), findsOneWidget);
      expect(find.text('deepseek-v3'), findsNothing);
    });

    testWidgets('rapid new chats read the options once at a time', (
      tester,
    ) async {
      onlyDefaultProfile();
      await pumpChat(tester);
      await openThread(tester, 'default');
      final held = Completer<void>();
      server.onRequest('GET', '/api/model/options', (_) async {
        await held.future;
        return (status: 200, body: _options('deepseek-v3'));
      }, query: {'profile': 'default'});
      final before = reads();

      for (var i = 0; i < 3; i++) {
        await newChat(tester, settle: false);
      }
      expect(reads(), before + 1);
      held.complete();
      await tester.pumpAndSettle();

      expect(shows('deepseek-v3'), findsOneWidget);
    });

    testWidgets('opening the picker reads again and shows a new model '
        'without closing it', (tester) async {
      await pumpChat(tester);
      final before = reads();
      server.on(
        'GET',
        '/api/model/options',
        _options('claude-opus-4')
          ..['providers'] = [
            {
              'slug': 'anthropic',
              'name': 'Anthropic',
              'authenticated': true,
              'models': ['claude-opus-4', 'claude-haiku-4-5', 'deepseek-v3'],
            },
          ],
        query: {'profile': 'default'},
      );
      await tester.tap(pill);
      await tester.pump();
      expect(find.text('Model'), findsOneWidget);
      expect(
        find.byKey(const Key('model-anthropic-deepseek-v3')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(reads(), before + 1);

      expect(find.text('Model'), findsOneWidget);
      expect(
        find.byKey(const Key('model-anthropic-deepseek-v3')),
        findsOneWidget,
      );
    });
  });
}
