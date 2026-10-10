import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/composer_dictation.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';

void main() {
  late FakeHermesServer server;
  late TextEditingController field;
  String? profile;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/audio/voice-config', {
        'ok': true,
        'stt': {'mode': 'relay', 'reason': 'local provider'},
        'tts': {'mode': 'relay'},
      });
    field = TextEditingController();
    profile = 'work';
  });

  tearDown(() => field.dispose());

  ComposerDictation build({DictationSettings? settings}) {
    final dictation = ComposerDictation(
      repository: HermesChatRepository(server.client().raw),
      connect: ([_ = const {}]) => Future.error(StateError('no socket')),
      recorder: FakeVoiceRecorder(),
      field: field,
      profile: () => profile,
      settings: settings,
    );
    addTearDown(dictation.dispose);
    return dictation;
  }

  List<Object?> asked() => [
    for (final request in server.requestsTo('GET', '/api/audio/voice-config'))
      request.queryParameters['profile'],
  ];

  test('asks for the voice support of the profile it reads', () async {
    final dictation = build();

    await dictation.refresh();

    expect(asked(), ['work']);
    expect(dictation.controller.available, isTrue);
  });

  test('asks again only once the profile has changed', () async {
    final dictation = build();
    await dictation.refresh();

    dictation.followProfile();
    await pumpEventQueue();
    expect(asked(), ['work']);

    profile = 'home';
    dictation.followProfile();
    await pumpEventQueue();
    expect(asked(), ['work', 'home']);
  });

  test('waits for the Dictation setting before asking the server', () async {
    final settings = DictationSettings();
    build(settings: settings);

    await pumpEventQueue();
    expect(asked(), isEmpty);

    await settings.load();
    await pumpEventQueue();
    expect(asked(), ['work']);
  });
}
