import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// Copy transcript: the chat's epoch refusals (a StateError) are not bugs and
/// are not reported; a real Error is. Either way the user sees the failure.
void main() {
  Future<void> run(WidgetTester tester, Never Function() fail) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final housekeeping = ThreadHousekeeping(
      repository: HermesChatRepository(FakeHermesServer().client().raw),
      threads: () => const [],
      profile: () => null,
      changed: () {},
      report: (_) {},
      removed: (_) {},
      history: (thread, {cancelled}) async => fail(),
      branch: (_) async {},
    );
    final thread = ChatThread(
      id: 's1',
      title: 'Release notes',
      updatedAt: DateTime(2026),
      remote: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runThreadAction(
                context,
                ThreadAction.copyTranscript,
                thread: thread,
                housekeeping: housekeeping,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a refusal from the chat is not reported as a bug', (
    tester,
  ) async {
    await run(tester, () => throw StateError('Chat activity suspended'));

    expect(tester.takeException(), isNull);
    expect(find.text('Could not copy the transcript'), findsOneWidget);
  });

  testWidgets('a real Error is reported and the failure still shows', (
    tester,
  ) async {
    await run(tester, () => throw TypeError());

    expect(tester.takeException(), isA<TypeError>());
    expect(find.text('Could not copy the transcript'), findsOneWidget);
  });

  testWidgets('a failed request is not reported', (tester) async {
    await run(tester, () => throw Exception('offline'));

    expect(tester.takeException(), isNull);
    expect(find.text('Could not copy the transcript'), findsOneWidget);
  });
}
