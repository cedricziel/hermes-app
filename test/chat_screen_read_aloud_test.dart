import 'dart:io';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';
import 'support/pump_chat.dart';

/// Read aloud on the chat screen follows the profile's `voice-config`.
void main() {
  late FakeHermesServer server;
  late MediaStore store;
  late Directory cache;

  setUp(() {
    cache = tempDir('chat_read_aloud');
    server = FakeHermesServer()
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
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'A connection reset during upload.',
          ),
        ]),
      );
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: FakeMediaActions(),
    );
  });
  tearDown(() => store.dispose());

  Future<void> pump(WidgetTester tester, Map<String, Object?> tts) async {
    server.on('GET', '/api/audio/voice-config', {
      'ok': true,
      'stt': {'mode': 'relay', 'reason': 'stt disabled'},
      'tts': tts,
    });
    await pumpChatScreen(
      tester,
      server: server,
      providers: [Provider<MediaStore?>.value(value: store)],
    );
    await openThread(tester, 'Run failure');
  }

  testWidgets('a reply offers Read aloud when the profile can speak', (
    tester,
  ) async {
    await pump(tester, {'mode': 'relay', 'reason': 'local provider'});

    expect(find.byTooltip('Read aloud'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    // Nothing is spoken until the user asks.
    expect(server.requestsTo('POST', '/api/audio/speak'), isEmpty);
  });

  testWidgets('a failed check on resume keeps Read aloud', (tester) async {
    await pump(tester, {'mode': 'relay', 'reason': 'local provider'});
    server.on('GET', '/api/audio/voice-config', {
      'detail': 'down',
    }, status: 503);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Read aloud'), findsOneWidget);
  });

  testWidgets('no Read aloud when text to speech is off', (tester) async {
    await pump(tester, {'mode': 'relay', 'reason': 'tts disabled'});

    expect(find.text('A connection reset during upload.'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Read aloud'), findsNothing);
  });
}
