import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:provider/provider.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

class _QuietLink implements ConversationWindowLink {
  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};

  @override
  Stream<String> get commands => const Stream.empty();

  @override
  Stream<bool> get keyChanges => const Stream.empty();

  @override
  void reportFocus(bool focused) {}

  @override
  void reportThread(String title, {required bool pinned}) {}

  @override
  Future<void> showInMain(String threadId, String? profile) async {}

  @override
  Future<void> showMain() async {}

  @override
  Future<void> present({
    required String frameName,
    required String title,
  }) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> share(String text, Rect anchor) async {}
}

const _windowSize = Size(760, 760);

/// A chat in a conversation window of its own (macOS): one chat, on the
/// profile it was opened from, with no sidebar.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Plan the Lisbon trip', pinned: true),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(
            id: 1,
            role: 'user',
            content: 'Which neighbourhoods should we stay in for four days?',
          ),
          messageRow(
            id: 2,
            role: 'assistant',
            content:
                'Alfama for the old town and the views, Príncipe Real if you '
                'want it quieter, and Cais do Sodré to be near the river and '
                'the trains to Belém and Cascais.',
          ),
        ]),
      )
      ..on('GET', '/api/model/options', {
        'model': 'claude-sonnet-4-5',
        'provider': 'anthropic',
        'providers': [
          {
            'slug': 'anthropic',
            'name': 'Anthropic',
            'models': ['claude-sonnet-4-5'],
          },
        ],
      });
  });

  for (final brightness in Brightness.values) {
    testWidgets('a conversation window, ${brightness.name}', (tester) async {
      final shots = ScreenshotRecorder(
        'conversation_window_${brightness.name}',
      );
      await pumpScreen(
        tester,
        shots,
        ConversationWindowScreen(
          args: const ConversationWindowArgs(
            threadId: 's1',
            profile: 'travel',
            title: 'Plan the Lisbon trip',
            baseUrl: 'https://hermes.test',
            authRequired: true,
          ),
          link: _QuietLink(),
          chat: HermesChatRepository(server.client().raw),
          models: HermesModelsRepository(server.client().raw),
          transport: FakeChatTransport(),
        ),
        size: _windowSize,
        brightness: brightness,
        providers: [Provider<MediaStore?>.value(value: null)],
      );
      await shots.capture(tester, 'chat');

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'more-menu');
    });
  }
}
