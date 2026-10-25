import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

void main() {
  final unavailable = isA<SessionTransportUnavailable>();

  test(
    'suspension rejects a pending RPC and blocks new work immediately',
    () async {
      final delegate = _Delegate();
      final transport = SessionChatTransport(() => delegate);
      final pending = transport.request('groups.send', {'room_id': 'room'});
      final rejected = expectLater(pending, throwsA(unavailable));

      final suspension = transport.suspend();
      await expectLater(transport.request('groups.list'), throwsA(unavailable));
      delegate.response.complete({'accepted': true});

      await rejected;
      await suspension;
      expect(delegate.requests.single.$1, 'groups.send');
      expect(delegate.requests.single.$2, {'room_id': 'room'});
      await transport.close();
    },
  );

  test('requestKeepingConnection reaches the delegate with its timeout and '
      'is refused once suspended', () async {
    final delegate = _Delegate();
    final transport = SessionChatTransport(() => delegate);
    final answer = transport.requestKeepingConnection('display.thumbnail', {
      'profile': 'work',
    }, timeout: const Duration(seconds: 10));
    delegate.response.complete({'data_url': null});

    expect(await answer, {'data_url': null});
    expect(delegate.requests.single.$1, 'display.thumbnail');
    expect(delegate.requests.single.$2, {'profile': 'work'});
    expect(delegate.timeouts.single, const Duration(seconds: 10));

    await transport.suspend();
    await expectLater(
      transport.requestKeepingConnection(
        'display.thumbnail',
        const {},
        timeout: const Duration(seconds: 10),
      ),
      throwsA(unavailable),
    );
    expect(delegate.timeouts, hasLength(1));
    await transport.close();
  });

  test(
    'late delegate errors are replaced with the suspension result',
    () async {
      final delegate = _Delegate();
      final transport = SessionChatTransport(() => delegate);
      final rejected = expectLater(
        transport.activeStatuses(),
        throwsA(unavailable),
      );

      await transport.suspend();
      delegate.statuses.completeError(StateError('old connection'));

      await rejected;
      await transport.close();
    },
  );

  test(
    'a stream created before suspension cannot attach after renewal',
    () async {
      final old = _Delegate();
      final fresh = _Delegate();
      var delegate = old;
      final transport = SessionChatTransport(() => delegate);
      final stream = transport.send(text: 'hello');

      await transport.suspend();
      delegate = fresh;
      transport.resume();

      await expectLater(stream, emitsError(unavailable));
      expect(old.sendListened, isFalse);
      expect(fresh.sendListened, isFalse);
      await transport.close();
    },
  );

  test(
    'send and follow-up subscriptions cancel before delegate close',
    () async {
      final delegate = _Delegate()..holdCancellation = Completer<void>();
      final transport = SessionChatTransport(() => delegate);
      final send = transport.send(text: 'hello').toList();
      final follow = transport.followUps('thread').toList();
      final sendRejected = expectLater(send, throwsA(unavailable));
      final followRejected = expectLater(follow, throwsA(unavailable));

      final suspension = transport.suspend();
      expect(delegate.sendCancelled, isTrue);
      expect(delegate.followCancelled, isTrue);
      expect(delegate.closed, isFalse);
      delegate.holdCancellation!.complete();

      await suspension;
      await sendRejected;
      await followRejected;
      expect(delegate.closed, isTrue);
      await transport.close();
    },
  );

  test('paused streams discard queued frames after suspension', () async {
    final delegate = _Delegate();
    final transport = SessionChatTransport(() => delegate);
    final events = <ChatEvent>[];
    final errors = <Object>[];
    final done = Completer<void>();
    final subscription = transport
        .followUps('thread')
        .listen(events.add, onError: errors.add, onDone: done.complete);
    subscription.pause();
    delegate.followController.add(const ReplyDelta('stale'));

    await transport.suspend();
    subscription.resume();
    await done.future;

    expect(events, isEmpty);
    expect(errors, [unavailable]);
    await subscription.cancel();
    await transport.close();
  });

  test(
    'reentrant suspension waits for the subscription returned by listen',
    () async {
      final delegate = _Delegate()..holdCancellation = Completer<void>();
      final transport = SessionChatTransport(() => delegate);
      late Future<void> suspension;
      delegate.sendStream = _ReentrantStream(
        delegate.sendController.stream,
        () => suspension = transport.suspend(),
      );
      final rejected = expectLater(
        transport.send(text: 'hello').toList(),
        throwsA(unavailable),
      );
      await Future<void>.value();

      expect(delegate.sendCancelled, isTrue);
      expect(delegate.closed, isFalse);
      delegate.holdCancellation!.complete();

      await suspension;
      await rejected;
      expect(delegate.closed, isTrue);
      await transport.close();
    },
  );

  test(
    'old RPC and close completion cannot clear the resumed delegate',
    () async {
      final old = _Delegate()
        ..holdClose = Completer<void>()
        ..promptAccepted = true;
      final fresh = _Delegate();
      var delegate = old;
      final transport = SessionChatTransport(() => delegate);
      final rejected = expectLater(
        transport.request('old'),
        throwsA(unavailable),
      );

      final suspension = transport.suspend();
      expect(transport.promptAccepted, isTrue);
      delegate = fresh;
      transport.resume();
      old.response.complete({'old': true});
      old.holdClose!.complete();
      await suspension;
      await rejected;
      final result = transport.request('groups.list');
      fresh.response.complete({'rooms': <Object>[]});

      expect(await result, {'rooms': <Object>[]});
      expect(transport.promptAccepted, isTrue);
      expect(fresh.closed, isFalse);
      final next = expectLater(
        transport.send(text: 'next'),
        emitsInOrder([isA<ReplyDelta>(), emitsDone]),
      );
      expect(transport.promptAccepted, isFalse);
      fresh.sendController.add(const ReplyDelta('fresh'));
      await fresh.sendController.close();
      await next;
      await transport.close();
    },
  );

  test('acknowledges a prompt accepted during cancellation', () async {
    final delegate = _Delegate()..holdCancellation = Completer<void>();
    final transport = SessionChatTransport(() => delegate);
    final rejected = expectLater(
      transport.send(text: 'hello').toList(),
      throwsA(unavailable),
    );

    final suspension = transport.suspend();
    expect(transport.promptAccepted, isFalse);
    delegate.promptAccepted = true;
    delegate.holdCancellation!.complete();
    await suspension;
    await rejected;

    expect(transport.promptAccepted, isTrue);
    await transport.close();
  });

  test('retirement prevents resume and all future transport work', () async {
    final delegate = _Delegate()..promptAccepted = true;
    final transport = SessionChatTransport(() => delegate);

    final closing = transport.close();
    final retired = isA<SessionTransportUnavailable>().having(
      (error) => error.retired,
      'retired',
      isTrue,
    );

    expect(transport.resume, throwsA(retired));
    expect(transport.promptAccepted, isTrue);
    await expectLater(transport.checkConnection(), throwsA(retired));
    await expectLater(transport.followUps('thread'), emitsError(retired));
    await closing;
    expect(delegate.closed, isTrue);
  });
}

class _Delegate
    implements ChatTransport, PromptAcknowledgement, GatewayRequester {
  final response = Completer<Map<String, Object?>>();
  final statuses = Completer<Map<String, String>>();
  final requests = <(String, Map<String, Object?>)>[];
  final timeouts = <Duration>[];
  Completer<void>? holdCancellation;
  Completer<void>? holdClose;
  var sendListened = false;
  var sendCancelled = false;
  var followCancelled = false;
  var closed = false;
  Stream<ChatEvent>? sendStream;

  late final sendController = StreamController<ChatEvent>(
    onListen: () => sendListened = true,
    onCancel: () {
      sendCancelled = true;
      return holdCancellation?.future;
    },
  );
  late final followController = StreamController<ChatEvent>(
    onCancel: () {
      followCancelled = true;
      return holdCancellation?.future;
    },
  );

  @override
  bool promptAccepted = false;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    requests.add((method, params));
    return response.future;
  }

  @override
  Future<Map<String, Object?>> requestKeepingConnection(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) {
    timeouts.add(timeout);
    return request(method, params);
  }

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) =>
      statuses.future;

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  }) => sendStream ?? sendController.stream;

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) =>
      followController.stream;

  @override
  Future<void> close() async {
    closed = true;
    await holdClose?.future;
    unawaited(sendController.close());
    unawaited(followController.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReentrantStream extends Stream<ChatEvent> {
  _ReentrantStream(this.source, this.beforeListenReturns);

  final Stream<ChatEvent> source;
  final void Function() beforeListenReturns;

  @override
  StreamSubscription<ChatEvent> listen(
    void Function(ChatEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = source.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    beforeListenReturns();
    return subscription;
  }
}
