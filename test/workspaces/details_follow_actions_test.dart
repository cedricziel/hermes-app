import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_flows.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/actions_chat_transport.dart';
import '../support/fake_hermes_server.dart';

final _hash = 'b' * 40;
const _reason = 'Wait for the restore or compression to finish.';

/// "Change folder…" in the details sheet follows a restore and a compression
/// of the chat: neither notifies the chat controller, only its own
/// controller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ActionsChatTransport source;
  late ChatController chat;
  late AttentionNotifier attention;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    source = ActionsChatTransport();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  Future<ChatThread> showDetails(WidgetTester tester) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First')]),
      )
      ..on('GET', '/api/sessions/stored-1', sessionRow(id: 'stored-1'))
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
          messageRow(id: 2, role: 'assistant', content: 'Done.'),
        ]),
      )
      ..on('GET', '/api/chat/workspaces', {
        'projects': <Object?>[],
        'repos': <Object?>[],
        'default_cwd': '/srv/a',
        'home': '/srv',
        'scan_enabled': false,
      });
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: source,
      workspaces: HermesWorkspacesRepository(
        server.client().raw,
        (method, params, {required timeout}) async => {},
      ),
      attention: attention,
      report: (_) {},
    );
    final opened = (await tester.runAsync(() async {
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.own('stored-1');
      source.fake.list = CheckpointsOn([
        Checkpoint(hash: _hash, reason: CheckpointReason.beforeEdit),
      ]);
      await chat.checkpointsIn(thread)!.panelOpened();
      return thread;
    }))!;
    opened.workingDirectory = '/srv/a';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showWorkingDirectoryDetails(
              context,
              chat: chat,
              thread: opened,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return opened;
  }

  testWidgets('a restore in flight shows why Change folder waits, and it '
      'clears afterwards', (tester) async {
    final opened = await showDetails(tester);
    final checkpoints = chat.checkpointsIn(opened)!;
    expect(find.text(_reason), findsNothing);
    source.fake.restoreGate = Completer<void>();

    final restoring = checkpoints.confirmRestore(
      checkpoints.beginRestore(_hash)!,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(_reason), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('working-directory-change')),
          )
          .onPressed,
      isNull,
    );

    source.fake.restoreGate!.complete();
    unawaited(restoring);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(_reason), findsNothing);
  });

  testWidgets('a compression that fails clears the reason too', (tester) async {
    final opened = await showDetails(tester);
    final context = chat.contextIn(opened)!;
    source.fake.compressGate = Completer<void>();

    final compressing = context.confirmCompress(context.beginCompress()!);
    await tester.pump();
    await tester.pump();
    expect(find.text(_reason), findsOneWidget);

    source.fake.compressGate!.completeError(StateError('failed'));
    unawaited(compressing.catchError((Object _) {}));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(_reason), findsNothing);
  });
}
