import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_options_state.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';

Map<String, Object?> _options(String model) => {
  'model': model,
  'provider': 'anthropic',
  'providers': [
    {
      'slug': 'anthropic',
      'name': 'Anthropic',
      'authenticated': true,
      'models': [model],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    activity = ValueNotifier(true);
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/model/options', _options('glm-5'));
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });
  tearDown(() => attention.dispose());

  ChatController controller() => ChatController(
    activity: activity,
    repository: HermesChatRepository(server.client().raw),
    models: HermesModelsRepository(server.client().raw),
    attention: attention,
    report: (_) {},
  );

  test('an answer that arrives after sign-out is dropped', () async {
    final chat = controller();
    addTearDown(chat.dispose);
    await chat.loadThreads();
    await pumpEventQueue();
    expect(chat.modelOptions?.current?.modelId, 'glm-5');

    final held = Completer<void>();
    server.onRequest('GET', '/api/model/options', (_) async {
      await held.future;
      return (status: 200, body: _options('deepseek-v3'));
    });
    final refresh = chat.refreshModelOptionsQuietly();
    activity.value = false;
    held.complete();
    await refresh;

    expect(chat.modelOptions?.current?.modelId, 'glm-5');
  });

  test('a read that fails keeps the options and the ready state', () async {
    final chat = controller();
    addTearDown(chat.dispose);
    await chat.loadThreads();
    await pumpEventQueue();
    server.on('GET', '/api/model/options', {'detail': 'boom'}, status: 500);

    await chat.refreshModelOptionsQuietly();

    expect(chat.modelOptions?.current?.modelId, 'glm-5');
    expect(chat.modelOptionsState, ModelOptionsState.ready);
  });

  test('a new chat while a read is out does not start another', () async {
    final chat = controller();
    addTearDown(chat.dispose);
    await chat.loadThreads();
    await pumpEventQueue();
    final held = Completer<void>();
    server.onRequest('GET', '/api/model/options', (_) async {
      await held.future;
      return (status: 200, body: _options('deepseek-v3'));
    });
    final before = server.requestsTo('GET', '/api/model/options').length;

    chat
      ..newThread()
      ..newThread()
      ..newThread();
    await pumpEventQueue();
    expect(server.requestsTo('GET', '/api/model/options').length, before + 1);
    held.complete();
    await chat.refreshModelOptionsQuietly();

    expect(chat.modelOptions?.current?.modelId, 'deepseek-v3');
  });

  group('on resume', () {
    late DateTime now;

    ChatController timed() => ChatController(
      activity: activity,
      repository: HermesChatRepository(server.client().raw),
      models: HermesModelsRepository(server.client().raw),
      attention: attention,
      report: (_) {},
      now: () => now,
    );

    test('two resumes within the interval read once', () async {
      now = DateTime(2026, 1, 1, 12);
      final chat = timed();
      addTearDown(chat.dispose);
      await chat.loadThreads();
      await pumpEventQueue();
      final before = server.requestsTo('GET', '/api/model/options').length;

      await chat.refreshModelOptionsOnResume();
      now = now.add(const Duration(seconds: 5));
      await chat.refreshModelOptionsOnResume();

      expect(server.requestsTo('GET', '/api/model/options').length, before + 1);
    });

    test('a resume after a profile switch is not skipped', () async {
      now = DateTime(2026, 1, 1, 12);
      final chat = timed();
      addTearDown(chat.dispose);
      await chat.loadThreads();
      await pumpEventQueue();
      await chat.refreshModelOptionsOnResume();
      await chat.loadThreads('other');
      await pumpEventQueue();
      final before = server.requestsTo('GET', '/api/model/options').length;

      now = now.add(const Duration(seconds: 5));
      await chat.refreshModelOptionsOnResume();

      expect(server.requestsTo('GET', '/api/model/options').length, before + 1);
    });

    test('a resume after the owner went away is not skipped', () async {
      now = DateTime(2026, 1, 1, 12);
      final chat = timed();
      addTearDown(chat.dispose);
      await chat.loadThreads();
      await pumpEventQueue();
      await chat.refreshModelOptionsOnResume();
      activity.value = false;
      await pumpEventQueue();
      activity.value = true;
      await pumpEventQueue();
      final before = server.requestsTo('GET', '/api/model/options').length;

      now = now.add(const Duration(seconds: 5));
      await chat.refreshModelOptionsOnResume();

      expect(
        server.requestsTo('GET', '/api/model/options').length,
        greaterThan(before),
      );
    });

    test('a resume after the interval reads again', () async {
      now = DateTime(2026, 1, 1, 12);
      final chat = timed();
      addTearDown(chat.dispose);
      await chat.loadThreads();
      await pumpEventQueue();
      await chat.refreshModelOptionsOnResume();
      final before = server.requestsTo('GET', '/api/model/options').length;

      now = now.add(ChatController.modelResumeInterval);
      await chat.refreshModelOptionsOnResume();

      expect(server.requestsTo('GET', '/api/model/options').length, before + 1);
    });
  });
}
