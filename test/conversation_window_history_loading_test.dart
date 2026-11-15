import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

class _Link implements ConversationWindowLink {
  // ignore: close_sinks
  final _c = StreamController<String>.broadcast(sync: true);
  // ignore: close_sinks
  final _k = StreamController<bool>.broadcast(sync: true);
  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};
  @override
  Stream<String> get commands => _c.stream;
  @override
  Stream<bool> get keyChanges => _k.stream;
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

void main() {
  testWidgets(
    'a conversation window shows loading, then failure with Retry, never the welcome view',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      Completer<void>? gate;
      var failing = true;
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Trip plan')]),
        )
        ..onRequest('GET', '/api/sessions/s1/messages', (_) async {
          await (gate ??= Completer<void>()).future;
          return failing
              ? (status: 500, body: {'detail': 'boom'})
              : (
                  status: 200,
                  body: messageListBody('s1', [
                    messageRow(id: 1, role: 'user', content: 'Where to?'),
                  ]),
                );
        });
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: ConversationWindowScreen(
            args: const ConversationWindowArgs(
              threadId: 's1',
              profile: 'work',
              title: 'Trip plan',
              baseUrl: 'https://hermes.test',
              authRequired: true,
            ),
            link: _Link(),
            chat: HermesChatRepository(server.client().raw),
            transport: FakeChatTransport(),
          ),
        ),
      );
      Future<void> frames() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await frames();
      expect(find.byType(LoadingSkeleton), findsOneWidget);
      expect(find.text(kStarterPrompts.first), findsNothing);
      gate!.complete();
      await frames();
      expect(find.text('Could not load the messages'), findsOneWidget);
      expect(find.text(kStarterPrompts.first), findsNothing);
      failing = false;
      await tester.tap(find.text('Retry'));
      await frames();
      expect(find.text('Where to?', findRichText: true), findsOneWidget);
      expect(find.text('Could not load the messages'), findsNothing);
    },
  );
}
