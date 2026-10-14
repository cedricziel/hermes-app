import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_persistence.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_queue_keys.dart';
import '../support/fake_queue_transport.dart';
import '../support/fake_share_inbox.dart';
import '../support/pump_chat.dart';

class _Queues extends QueuePersistence {
  _Queues(PromptQueueStore store)
    : super(
        auth: AuthController(),
        lock: AppLockController(),
        factory: () async => store,
      );
  @override
  bool get visible => true;
  @override
  QueueScope? scopeFor(String conversationId, String? profile) =>
      profile == null
      ? null
      : QueueScope(
          serverKey: 'server',
          accountKey: 'account',
          profile: profile,
          conversationId: conversationId,
        );
  @override
  void dispose() {
    super.dispose();
    auth.dispose();
    lock.dispose();
  }
}

class _FixtureStore extends DurableQueueStore {
  _FixtureStore({
    required super.directory,
    required super.keys,
    super.beforeCommit,
  });
  Future<void>? settled;

  @override
  Future<QueueLoad> load(QueueScope scope) {
    final operation = super.load(scope);
    settled = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  @override
  Future<QueueRecord> commit(
    QueueScope scope,
    String text, {
    String? displayText,
    List<QueueAttachmentInput> files = const [],
  }) {
    final operation = super.commit(
      scope,
      text,
      displayText: displayText,
      files: files,
    );
    settled = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }
}

Future<void> _waitForDiskWork(
  WidgetTester tester,
  Future<void> operation,
) async {
  await tester.runAsync(() async {
    var done = false;
    Object? error;
    StackTrace? trace;
    final completed = operation
        .timeout(const Duration(seconds: 5))
        .then<void>(
          (_) => done = true,
          onError: (Object failure, StackTrace stack) {
            error = failure;
            trace = stack;
            done = true;
          },
        );
    // File completions can resume work in the widget test's fake zone.
    while (!done) {
      await tester.pump();
      await pumpEventQueue(times: 1);
    }
    await completed;
    if (error != null) Error.throwWithStackTrace(error!, trace!);
  });
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'composer waits for durable commit and retains attachments on failure $fail',
      (tester) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('queue-composer-test-'),
        ))!;
        final ioZone = (await tester.runAsync(() async => Zone.current))!;
        final entered = ioZone.run(Completer<void>.new);
        final release = ioZone.run(Completer<void>.new);
        final store = _FixtureStore(
          directory: directory,
          keys: FakeQueueKeys(),
          beforeCommit: (operation) async {
            if (operation != 'record') return;
            entered.complete();
            await release.future;
            if (fail) throw StateError('disk unavailable');
          },
        );
        final queues = _Queues(store);
        final inbox = FakeShareInbox();
        final share = ShareController(inbox);
        final transport = FakeQueueTransport();
        final server = FakeHermesServer()
          ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
          ..on('GET', '/api/sessions', sessionListBody([]));
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await tester.pumpWidget(const SizedBox());
          await _waitForDiskWork(tester, store.settled ?? Future<void>.value());
          queues.dispose();
          share.dispose();
          await tester.runAsync(() => directory.delete(recursive: true));
        });
        await share.start();
        await pumpChatScreen(
          tester,
          server: server,
          withProfiles: true,
          transport: transport,
          providers: [
            ChangeNotifierProvider<QueuePersistence>.value(value: queues),
            ChangeNotifierProvider<ShareController>.value(value: share),
          ],
        );
        await tester.enterText(composerField, 'opening');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();
        transport.sends.single.emit(const ThreadBound('stored'));
        await tester.pump();
        final source = File('${directory.path}/synthetic.txt');
        await tester.runAsync(
          () => source.writeAsString('synthetic attachment'),
        );
        inbox.emit([SharedFile(path: source.path, name: 'synthetic.txt')]);
        await tester.pump();
        await tester.enterText(composerField, 'retained draft');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();
        await _waitForDiskWork(tester, entered.future);
        await tester.pump();
        expect(
          tester.widget<EditableText>(composerField).controller.text,
          'retained draft',
        );
        expect(find.byTooltip('Remove synthetic.txt'), findsOneWidget);
        expect(transport.sends, hasLength(1));
        expect(find.text('Queueing…'), findsOneWidget);
        release.complete();
        await _waitForDiskWork(tester, store.settled!);
        await tester.pump();
        expect(
          tester.widget<EditableText>(composerField).controller.text,
          fail ? 'retained draft' : '',
        );
        expect(
          find.byTooltip('Remove synthetic.txt'),
          fail ? findsOneWidget : findsNothing,
        );
        expect(transport.sends, hasLength(1));
        const scope = QueueScope(
          serverKey: 'server',
          accountKey: 'account',
          profile: 'work',
          conversationId: 'stored',
        );
        final loaded = await tester.runAsync(() => store.load(scope));
        expect(loaded!.records, fail ? isEmpty : hasLength(1));
        if (fail) {
          expect(
            find.text('Could not queue this prompt. Your draft was kept.'),
            findsOneWidget,
          );
        }
      },
    );
  }
}
