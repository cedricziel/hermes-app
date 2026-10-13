import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:hermes_app/src/watch/watch_send_journal.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'watch_send_journal_test.dart' show MemoryJournalStore;

void main() {
  final now = DateTime.utc(2026);
  const scope = WatchContext('owned', 1);
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late MemoryJournalStore storage;
  late WatchSendJournal journal;
  late WatchRequestHandler handler;
  var signedOut = false;
  WatchRequestHandler makeHandler() => WatchRequestHandler(
    context: () => scope,
    journal: journal,
    repository: () =>
        signedOut ? null : HermesChatRepository(server.client().raw),
    transport: () => transport,
    activeProfile: () async => 'profile',
    announce: (_) async => true,
    waitingHold: Duration.zero,
  );
  Map<Object?, Object?> request({
    bool retry = false,
    String text = 'original',
  }) => {
    'op': 'send',
    ...scope.fields,
    'sendId': 'id',
    'createdAt': now.millisecondsSinceEpoch,
    'text': text,
    'retry': retry,
  };
  setUp(() {
    server = FakeHermesServer();
    transport = FakeChatTransport();
    storage = MemoryJournalStore();
    journal = WatchSendJournal(store: storage, now: () => now);
    signedOut = false;
    handler = makeHandler();
  });
  test('identical live requests join one dispatch', () async {
    final first = handler.handle(request());
    final duplicate = handler.handle(request());
    await pumpEventQueue();
    expect(transport.sends, hasLength(1));
    transport.sends.single.emit(const ReplyCompleted('owned result'));
    expect((await first)['text'], 'owned result');
    expect((await duplicate)['text'], 'owned result');
  });
  test(
    'changed payload is rejected while original attempt stays live',
    () async {
      final first = handler.handle(request());
      await pumpEventQueue();
      expect(
        (await handler.handle(request(text: 'changed')))['error'],
        'bad_request',
      );
      transport.sends.single.emit(const ReplyCompleted('owned result'));
      await first;
      expect(transport.sends, hasLength(1));
    },
  );
  test('unknown status never reads history or dispatches', () async {
    final reply = await handler.handle(request(retry: true));
    expect(reply['recoveryState'], 'uncertain');
    expect(reply.containsKey('text'), isFalse);
    expect(transport.sends, isEmpty);
    expect(server.requests, isEmpty);
  });
  test('saved completion survives handler restart without dispatch', () async {
    final sent = handler.handle(request());
    await pumpEventQueue();
    transport.sends.single.emit(const ReplyCompleted('owned result'));
    await sent;
    journal = WatchSendJournal(store: storage, now: () => now);
    handler = makeHandler();
    expect(
      (await handler.handle(request(retry: true)))['text'],
      'owned result',
    );
    expect(transport.sends, hasLength(1));
  });
  test('write failure before marker prevents gateway submission', () async {
    storage.failWrites = true;
    expect((await handler.handle(request()))['ok'], isFalse);
    expect(transport.sends, isEmpty);
  });
  test('logout racing completion cannot resurrect private recovery', () async {
    final sent = handler.handle(request());
    await pumpEventQueue();
    signedOut = true;
    handler.invalidateSession();
    transport.sends.single.emit(const ReplyCompleted('late private result'));
    expect((await sent)['ok'], isFalse);
    await pumpEventQueue();
    expect(
      storage.values.values.any(
        (value) => value.contains('late private result'),
      ),
      isFalse,
    );
  });
  test('recovered dispatch marker never submits again', () async {
    await journal.reserve(
      scope,
      WatchSendIdentity(
        'id',
        now.millisecondsSinceEpoch,
        'profile',
        null,
        'original',
      ),
    );
    await journal.markDispatched(scope, 'id');
    journal = WatchSendJournal(store: storage, now: () => now);
    handler = makeHandler();
    expect((await handler.handle(request()))['recoveryState'], 'uncertain');
    expect(transport.sends, isEmpty);
  });
  test('missing immutable timestamp rejects first dispatch', () async {
    final malformed = request()..remove('createdAt');
    expect((await handler.handle(malformed))['error'], 'bad_request');
    expect(transport.sends, isEmpty);
  });
  test(
    'status queries are valid after the original timestamp expires',
    () async {
      final old = request(retry: true)
        ..['createdAt'] = now
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch;
      expect((await handler.handle(old))['recoveryState'], 'uncertain');
      expect(transport.sends, isEmpty);
    },
  );
  test('active Forget leaves the server stream running', () async {
    final sent = handler.handle(request());
    await pumpEventQueue();
    expect(
      (await handler.handle({
        'op': 'forgetSend',
        ...scope.fields,
        'sendId': 'id',
      }))['ok'],
      isTrue,
    );
    expect(
      (await handler.handle(request(retry: true)))['recoveryState'],
      'pending',
    );
    transport.sends.single.emit(const ReplyCompleted('owned result'));
    expect((await sent)['text'], 'owned result');
  });
  test('failed durable invalidation blocks subsequent context use', () async {
    storage.failWrites = true;
    handler.invalidateSession();
    expect((await handler.handle(request()))['ok'], isFalse);
    expect(transport.sends, isEmpty);
  });
  test('modern send capability is false while protected persistence is unavailable', () async {
    storage.failWrites = true;
    expect((await handler.handle({'op': 'session'}))['sendState'], isFalse);
    storage.failWrites = false;
    expect((await handler.handle({'op': 'session'}))['sendState'], isTrue);
  });
  test(
    'resolved approval keeps working polling until saved final result',
    () async {
      final first = handler.handle(request()..['waits'] = true);
      await pumpEventQueue();
      transport.sends.single.emit(const ThreadBound('thread'));
      transport.sends.single.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'approval',
            command: 'command',
            description: 'description',
            choices: ['once', 'deny'],
          ),
        ),
      );
      expect((await first)['waiting'], 'approval');
      transport.sends.single.emit(const InputRequestExpired('approval'));
      await pumpEventQueue();
      final working = await handler.handle(request(retry: true));
      expect(working['waiting'], 'working');
      expect(working.containsKey('recoveryState'), isFalse);
      transport.sends.single.emit(const ReplyCompleted('owned result'));
      await pumpEventQueue();
      expect(
        (await handler.handle(request(retry: true)))['text'],
        'owned result',
      );
    },
  );
  test('close failure preserves owned completion after restart', () async {
    transport = CloseThrowingTransport();
    handler = makeHandler();
    final sent = handler.handle(request());
    await pumpEventQueue();
    transport.sends.single.emit(const ReplyCompleted('exact owned reply'));
    expect((await sent)['text'], 'exact owned reply');
    journal = WatchSendJournal(store: storage, now: () => now);
    handler = makeHandler();
    expect(
      (await handler.handle(request(retry: true)))['text'],
      'exact owned reply',
    );
    expect(transport.sends, hasLength(1));
  });
  test(
    'read failure explicitly disables modern send state and dispatch',
    () async {
      storage.beforeRead = (_) async => throw StateError('storage unavailable');
      final session = await handler.handle({'op': 'session'});
      expect(session['sendState'], isFalse);
      expect((await handler.handle(request()))['ok'], isFalse);
      expect(transport.sends, isEmpty);
    },
  );
}

class CloseThrowingTransport extends FakeChatTransport {
  @override
  Future<void> close() async {
    await super.close();
    throw StateError('close unavailable');
  }
}
