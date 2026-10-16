import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_options_state.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

Map<String, Object?> options(String model) => {
  'provider': 'nous',
  'model': model,
  'providers': [
    {
      'slug': 'nous',
      'authenticated': true,
      'models': [model],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late ChatController chat;
  late FakeChatTransport transport;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]));
    transport = FakeChatTransport();
    final notifications = FakeNotificationService();
    final attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    final api = server.client().raw;
    chat = ChatController(
      repository: HermesChatRepository(api),
      models: HermesModelsRepository(api),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(chat.dispose);
    addTearDown(attention.dispose);
    addTearDown(notifications.dispose);
  });

  testWidgets(
    'a model selector without a setup callback offers scoped guidance and refresh',
    (tester) async {
      server.on('GET', '/api/model/options', {'providers': []});
      await tester.runAsync(() async {
        await chat.loadThreads('work');
        await pumpEventQueue();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (_, _) => composerModelPill(chat),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reads = server.requestsTo('GET', '/api/model/options').length;

      await tester.tap(find.text('Set up a model'));
      await tester.pumpAndSettle();
      expect(find.text('hermes -p work model'), findsOneWidget);
      expect(server.requestsTo('GET', '/api/model/options'), hasLength(reads));
      server.on('GET', '/api/model/options', options('hermes-4'));
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      expect(find.text('hermes-4'), findsOneWidget);
      expect(chat.modelSendAllowed, isTrue);
      expect(
        server.requests.where((request) => request.method != 'GET'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'a picker opened for another profile cannot change the new recipient model',
    (tester) async {
      server.on('GET', '/api/model/options', options('hermes-4'));
      await tester.runAsync(() async {
        await chat.loadThreads('work');
        await pumpEventQueue();
      });
      chat.newThread();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (_, _) => composerModelPill(chat),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('composer-model-pill')));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await chat.loadThreads('home');
        await pumpEventQueue();
      });
      chat.newThread();
      final current = chat.selectedThread!;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model-nous-hermes-4')));
      await tester.pumpAndSettle();

      expect(chat.profile, 'home');
      expect(chat.selectedThread, same(current));
      expect(current.modelChoice, isNull);
      expect(transport.sends, isEmpty);
    },
  );

  testWidgets(
    'a picker opened for another conversation cannot change its successor model',
    (tester) async {
      server.on('GET', '/api/model/options', options('hermes-4'));
      await tester.runAsync(() async {
        await chat.loadThreads('work');
        await pumpEventQueue();
      });
      chat.newThread();
      final original = chat.selectedThread!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: chat,
              builder: (_, _) => composerModelPill(chat),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('composer-model-pill')));
      await tester.pumpAndSettle();

      chat.newThread();
      final current = chat.selectedThread!;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('model-nous-hermes-4')));
      await tester.pumpAndSettle();

      expect(current.modelChoice, isNull);
      expect(original.modelChoice, isNull);
      expect(chat.selectedThread, same(current));
      expect(transport.sends, isEmpty);
    },
  );

  test(
    'pending model discovery blocks sends without creating a conversation',
    () async {
      final held = Completer<FakeResponse>();
      server.onRequest('GET', '/api/model/options', (_) => held.future);
      await chat.loadThreads('work');

      expect(chat.modelOptionsState, ModelOptionsState.loading);
      expect(await chat.submit('Keep this draft', const []), isFalse);
      expect(chat.threads, isEmpty);
      expect(transport.sends, isEmpty);

      held.complete((status: 200, body: options('hermes-4')));
      await pumpEventQueue();
      expect(chat.modelOptionsState, ModelOptionsState.ready);
      expect(chat.modelSendAllowed, isTrue);
    },
  );

  test(
    'successful empty discovery differs from failure and retries independently',
    () async {
      server.on('GET', '/api/model/options', {'providers': []});
      await chat.loadThreads('work');
      await pumpEventQueue();
      expect(chat.modelOptionsState, ModelOptionsState.incomplete);
      expect(chat.modelSendAllowed, isFalse);
      expect(await chat.submit('Keep this draft', const []), isFalse);

      server.on('GET', '/api/model/options', {
        'detail': 'offline',
      }, status: 503);
      await chat.refreshModelOptions();
      expect(chat.modelOptionsState, ModelOptionsState.failed);
      expect(chat.modelSendAllowed, isFalse);

      server.on('GET', '/api/model/options', options('hermes-4'));
      await chat.refreshModelOptions();
      expect(chat.modelOptionsState, ModelOptionsState.ready);
      expect(chat.modelSendAllowed, isTrue);
      expect(chat.profile, 'work');
      expect(chat.threads, isEmpty);
      expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  test(
    'unsupported discovery retains legacy profile-default sending',
    () async {
      await chat.loadThreads('work');
      await pumpEventQueue();

      expect(chat.modelOptionsState, ModelOptionsState.unsupported);
      expect(chat.modelSendAllowed, isTrue);
      expect(await chat.submit('Use the profile default', const []), isTrue);
      expect(transport.sends.single.profile, 'work');
      expect(transport.sends.single.model, isNull);
    },
  );

  test('a known usable default survives a failed discovery refresh', () async {
    server.on('GET', '/api/model/options', options('hermes-4'));
    await chat.loadThreads('work');
    await pumpEventQueue();
    server.on('GET', '/api/model/options', {'detail': 'offline'}, status: 503);

    await chat.refreshModelOptions();

    expect(chat.modelOptionsState, ModelOptionsState.failed);
    expect(chat.modelSendAllowed, isTrue);
    expect(chat.modelOptions!.current, const ModelChoice('nous', 'hermes-4'));
  });

  test('a late model retry cannot overwrite a newer discovery', () async {
    server.on('GET', '/api/model/options', options('hermes-4'));
    await chat.loadThreads('work');
    await pumpEventQueue();
    final started = Completer<void>();
    final held = Completer<FakeResponse>();
    server.onRequest('GET', '/api/model/options', (_) {
      started.complete();
      return held.future;
    });
    final old = chat.refreshModelOptions();
    await started.future;
    server.on('GET', '/api/model/options', options('hermes-5'));

    await chat.refreshModelOptions();
    held.complete((status: 200, body: options('hermes-4')));
    await old;

    expect(chat.modelOptions!.current, const ModelChoice('nous', 'hermes-5'));
    expect(chat.modelOptionsState, ModelOptionsState.ready);
  });

  test(
    'a previous profile discovery cannot replace the current model state',
    () async {
      final held = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/model/options',
        (_) => held.future,
        query: {'profile': 'work'},
      );
      server.on(
        'GET',
        '/api/model/options',
        options('hermes-5'),
        query: {'profile': 'home'},
      );
      await chat.loadThreads('work');

      await chat.loadThreads('home');
      await pumpEventQueue();
      held.complete((status: 200, body: {'providers': []}));
      await pumpEventQueue();

      expect(chat.profile, 'home');
      expect(chat.modelOptions!.current, const ModelChoice('nous', 'hermes-5'));
      expect(chat.modelOptionsState, ModelOptionsState.ready);
      expect(chat.modelSendAllowed, isTrue);
    },
  );
}
