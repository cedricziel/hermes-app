import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart'
    show GatewayConnectionClosed;
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_gateway.dart';
import '../support/fake_notification_service.dart';

/// What a stream has delivered so far, readable while fake time runs.
class _Seen {
  final events = <ChatEvent>[];
  Object? error;
  var done = false;
}

_Seen _listen(Stream<ChatEvent> stream) {
  final seen = _Seen();
  stream.listen(
    seen.events.add,
    onError: (Object error) => seen.error = error,
    onDone: () => seen.done = true,
  );
  return seen;
}

/// A controller on the real gateway transport and a fake gateway: the
/// transport, the reducer and the controller all run for real.
class _Live {
  _Live() : gateway = FakeGateway() {
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
    attention = AttentionNotifier(
      service: service,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: reports.add,
    );
  }

  final FakeGateway gateway;
  late final HermesGatewayTransport transport;
  late final AttentionNotifier attention;
  final service = FakeNotificationService();
  late final ChatController chat;
  final reports = <String>[];

  /// Sends [text] in a new thread and lets the gateway answer.
  Future<ChatThread> start(String text) async {
    chat.newThread();
    chat.submit(text, const []);
    await settle();
    return chat.selectedThread!;
  }

  Future<void> settle() => pumpEventQueue(times: 200);

  /// How many `prompt.submit` calls the gateway got.
  int get submits => gateway.methods.where((m) => m == 'prompt.submit').length;

  Future<void> dispose() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  }
}

/// A controller with a fake transport driven by hand.
class _Rig {
  _Rig() : transport = FakeChatTransport() {
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: reports.add,
    );
  }

  final reports = <String>[];
  late final ChatController chat;
  late final AttentionNotifier attention;
  final FakeChatTransport transport;

  (ChatThread, FakeSend) start(String text, {String id = 's1'}) {
    chat.newThread();
    chat.submit(text, const []);
    final send = transport.sends.last..emit(ThreadBound(id));
    return (chat.selectedThread!, send);
  }

  FakeFollowUps followUp([String id = 's1']) => transport.followUpStreams[id]!;

  List<String> get sentTexts => [for (final s in transport.sends) s.text];

  void dispose() {
    chat.dispose();
    attention.dispose();
  }
}

Iterable<ChatMessage> _replies(ChatThread thread) =>
    thread.messages.where((m) => m.role == ChatRole.assistant);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Early running false (finding 1)', () {
    late _Live live;
    setUp(() => live = _Live());
    tearDown(() => live.dispose());

    test('Stale report before the turn began: through the controller the reply '
        'stays pending and a queued message is not sent', () async {
      live.gateway.turn = (g, sid) => g.event('session.info', sid, {
        'running': false,
        'stored_session_id': 'stored-1',
      });
      final thread = await live.start('One');
      live.chat.submit('Two', const []);
      await live.settle();

      expect(thread.isReplying, isTrue);
      expect(thread.messages.last.status, MessageStatus.thinking);
      expect(live.submits, 1);
      expect(live.chat.queuedIn(thread), hasLength(1));

      // The turn then runs and ends as usual, and the queue goes on.
      live.gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.complete', sid, {'text': 'Two', 'status': 'complete'});
      };
      live.gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'Hi'})
        ..event('message.complete', 'rt-1', {
          'text': 'Hi',
          'status': 'complete',
        })
        ..event('session.info', 'rt-1', {'running': false});
      await live.settle();

      expect(_replies(thread).first.content, 'Hi');
      expect(live.submits, 2);
      expect(
        live.gateway.requests.lastWhere(
          (r) => r['method'] == 'prompt.submit',
        )['params'],
        containsPair('queued', true),
      );
    });
  });

  group('Error before the turn began (findings 2 and 3)', () {
    late _Live live;
    setUp(() {
      live = _Live();
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
    });
    tearDown(() async {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await live.dispose();
    });

    test(
      'Error event without a completion: an error then a settle inside the '
      'grace ends the reply as an error, pauses the queue and announces it',
      () async {
        final thread = await live.start('One');
        live.chat.submit('Two', const []);
        await live.settle();

        live.gateway
          ..event('error', 'rt-1', {'message': 'boom'})
          ..event('session.info', 'rt-1', {'running': false});
        await live.settle();

        final reply = _replies(thread).single;
        expect(reply.status, MessageStatus.error);
        expect(reply.error, 'boom');
        expect(thread.isReplying, isFalse);
        expect(live.chat.queuePaused(thread), isTrue);
        expect(live.submits, 1);
        expect(live.service.shown.map((n) => n.body), [kReplyFailedBody]);
      },
    );

    test(
      'Settled without a completion: a reply that ends by settle is announced',
      () async {
        final thread = await live.start('One');

        live.gateway
          ..event('message.start', 'rt-1')
          ..event('message.delta', 'rt-1', {'text': 'Partial answer'})
          ..event('session.info', 'rt-1', {'running': false});
        await live.settle();

        expect(_replies(thread).single.content, 'Partial answer');
        expect(live.service.shown.map((n) => n.body), ['Partial answer']);
      },
    );
  });

  test('Stream drops or ends without completion: a held error explains the '
      'failure better than the generic message', () {
    final reply = ChatMessage(
      id: 'a',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2026),
      status: MessageStatus.thinking,
    );
    applyReplyEvent(reply, const ReplyErrored('rate limited'));

    failReply(reply, const GatewayConnectionClosed());

    expect(reply.error, 'rate limited');
    expect(reply.pendingError, isNull);
    expect(reply.status, MessageStatus.error);
  });

  group('Follow-up turn settled without a completion (finding 4)', () {
    test(
      'Missed start of a chained turn: a follow-up that settles is closed, so '
      'the next chained turn gets its own reply',
      () async {
        final rig = _Rig();
        final (thread, first) = rig.start('One');
        await pumpEventQueue();
        first
          ..emit(const ReplyCompleted('Done.'))
          ..finish();
        await pumpEventQueue();

        rig.followUp()
          ..emit(const ReplyStarted())
          ..emit(const ReplyDelta('first'))
          ..emit(const SessionInfo(running: false))
          ..emit(const ReplyStarted())
          ..emit(const ReplyDelta('second'))
          ..emit(const ReplyCompleted('second'));
        await pumpEventQueue();

        expect(
          [for (final r in _replies(thread)) r.content],
          ['Done.', 'first', 'second'],
        );
        expect(thread.isReplying, isFalse);
        rig.dispose();
      },
    );

    test(
      'Sent only once the session settled: a follow-up that settles sends the '
      'queued message',
      () async {
        final rig = _Rig();
        final (thread, first) = rig.start('One');
        await pumpEventQueue();
        first
          ..emit(const ReplyCompleted('Done.'))
          ..finish();
        await pumpEventQueue();
        rig.followUp().emit(const ReplyDelta('chained'));
        await pumpEventQueue();
        rig.chat.submit('Two', const []);
        expect(rig.sentTexts, ['One']);

        rig.followUp().emit(const SessionInfo(running: false));
        await pumpEventQueue();

        expect(rig.sentTexts, ['One', 'Two']);
        expect(thread.isReplying, isTrue);
        rig.dispose();
      },
    );

    test(
      'Missed start of a chained turn: the transport ends a settled turn, so '
      'the next start is not taken for a replay of it',
      () async {
        final gateway = FakeGateway();
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Hi',
          'status': 'complete',
        });
        await transport.send(text: 'hi').toList();
        final seen = _listen(transport.followUps('stored-1'));

        gateway
          ..event('message.start', 'rt-1')
          ..event('message.delta', 'rt-1', {'text': 'a'})
          ..event('session.info', 'rt-1', {'running': false})
          ..event('message.start', 'rt-1')
          ..event('message.delta', 'rt-1', {'text': 'b'})
          ..event('message.complete', 'rt-1', {
            'text': 'b',
            'status': 'complete',
          });
        await pumpEventQueue();

        expect(seen.events.map((e) => e.runtimeType), [
          ReplyStarted,
          ReplyDelta,
          SessionInfo,
          ReplyStarted,
          ReplyDelta,
          ReplyCompleted,
        ]);
        await transport.close();
      },
    );
  });

  group('Compression rotates the stored id (findings 5 and 6)', () {
    late FakeGateway gateway;
    late HermesGatewayTransport transport;

    setUp(() {
      gateway = FakeGateway();
      transport = HermesGatewayTransport(connect: () async => gateway.channel);
    });
    tearDown(() => transport.close());

    void rotateMidReply(FakeGateway g, String sid) {
      g.event('message.start', sid);
      g.event('session.info', sid, {
        'running': true,
        'stored_session_id': 'stored-2',
      });
      g.event('message.delta', sid, {'text': 'Hi'});
      g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
    }

    test(
      'Compression rotates the stored id: the parked watch is found under the '
      'new id, without resuming the session again',
      () async {
        gateway.turn = rotateMidReply;
        await transport.send(text: 'hi').toList();

        final seen = _listen(transport.followUps('stored-2'));
        gateway
          ..event('message.start', 'rt-1')
          ..event('message.delta', 'rt-1', {'text': 'chained'});
        await pumpEventQueue();

        expect(seen.events.map((e) => e.runtimeType), [
          ReplyStarted,
          ReplyDelta,
        ]);
        expect(gateway.methods, isNot(contains('session.resume')));
      },
    );

    test(
      'Compression rotates the stored id: a stop under the new id reaches the '
      'reply still running',
      () async {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('session.info', sid, {
            'running': true,
            'stored_session_id': 'stored-2',
          });
        };
        final seen = _listen(transport.send(text: 'hi'));
        await pumpEventQueue();
        expect(seen.events.last, isA<SessionInfo>());

        final stopped = await transport.stopReply('stored-2');

        expect(stopped, isTrue);
        expect(gateway.requestOf('session.interrupt')['params'], {
          'session_id': 'rt-1',
        });
      },
    );

    test('Compression rotates the stored id: the model last set is remembered '
        'under the new id', () async {
      const model = ModelChoice('anthropic', 'claude');
      gateway.turn = rotateMidReply;
      await transport.send(text: 'hi', model: model).toList();

      await transport
          .send(threadId: 'stored-2', text: 'again', model: model)
          .toList();

      expect(gateway.methods, isNot(contains('config.set')));
    });

    test('Compression rotates the stored id: through the controller the next '
        'chained turn shows once, in one new reply', () async {
      final live = _Live();
      live.gateway.turn = rotateMidReply;
      final thread = await live.start('One');
      expect(thread.id, 'stored-2');

      live.gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'chained'})
        ..event('message.complete', 'rt-1', {
          'text': 'chained',
          'status': 'complete',
        });
      await live.settle();

      expect([for (final r in _replies(thread)) r.content], ['Hi', 'chained']);
      expect(live.gateway.methods, isNot(contains('session.resume')));
      await live.dispose();
    });

    test(
      'A silent live turn: after a rotation the probe asks about the new id',
      () {
        fakeAsync((async) {
          final gateway = FakeGateway()
            ..activeSessions = {'stored-2': 'working'};
          final transport = HermesGatewayTransport(
            connect: () async => gateway.channel,
          );
          gateway.turn = (g, sid) {
            g.event('message.start', sid);
            g.event('session.info', sid, {
              'running': true,
              'stored_session_id': 'stored-2',
            });
          };
          final seen = _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 45));
          async.flushMicrotasks();

          expect(
            gateway.methods.where((m) => m == 'session.active_list'),
            hasLength(1),
          );
          expect(seen.error, isNull);
          expect(seen.done, isFalse);
        });
      },
    );
  });

  group('Queued by the server (finding 7)', () {
    late FakeGateway gateway;
    late HermesGatewayTransport transport;

    setUp(() {
      gateway = FakeGateway()..submitStatus = 'queued';
      transport = HermesGatewayTransport(connect: () async => gateway.channel);
    });
    tearDown(() => transport.close());

    Future<List<ChatEvent>> reply() => transport
        .send(text: 'next', queued: true)
        .toList()
        .timeout(const Duration(seconds: 5));

    test('Queued by the server: the running turn does not land in the queued '
        "prompt's reply", () async {
      gateway.turn = (g, sid) {
        g.event('message.delta', sid, {'text': 'old'});
        g.event('message.complete', sid, {
          'text': 'old done',
          'status': 'complete',
        });
        g.event('session.info', sid, {'running': false});
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'new'});
        g.event('message.complete', sid, {
          'text': 'new done',
          'status': 'complete',
        });
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ThreadNeedsRefetch,
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
      expect((events[3] as ReplyDelta).text, 'new');
      expect((events.last as ReplyCompleted).text, 'new done');
    });

    test('Queued by the server: a running turn that ends with a settle report '
        'and not a completion is left out too', () async {
      gateway.turn = (g, sid) {
        g.event('message.delta', sid, {'text': 'old'});
        g.event('session.info', sid, {'running': false});
        g.event('message.start', sid);
        g.event('message.complete', sid, {
          'text': 'new done',
          'status': 'complete',
        });
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ThreadNeedsRefetch,
        ReplyStarted,
        ReplyCompleted,
      ]);
    });

    test('Queued by the server: what the running turn asks of the user still '
        'reaches the screen', () async {
      gateway.turn = (g, sid) {
        g.event('message.delta', sid, {'text': 'old'});
        g.event('approval.request', sid, {
          'request_id': 'r1',
          'command': 'ls',
          'description': 'list',
        });
        g.event('message.complete', sid, {
          'text': 'old done',
          'status': 'complete',
        });
        g.event('message.start', sid);
        g.event('message.complete', sid, {'text': 'new', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<ApprovalRequested>(), hasLength(1));
      expect(events.whereType<ReplyDelta>(), isEmpty);
      expect(events.whereType<ReplyCompleted>().single.text, 'new');
    });

    test('Queued by the server: a start with no running turn before it begins '
        'the reply at once', () async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'Hi'});
        g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
    });
  });

  group('Folded into the running turn (finding 8)', () {
    test(
      'Folded into the running turn: the running turn reaches the follow-ups '
      'through the watch the send parked',
      () async {
        final gateway = FakeGateway()..submitStatus = 'steered';
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) => g.event('message.delta', sid, {'text': 'x'});

        final events = await transport
            .send(threadId: 'stored-2', text: 'hi')
            .toList();
        expect(events.single, isA<PromptFolded>());
        gateway.event('message.delta', 'rt-2', {'text': 'y'});
        final seen = _listen(transport.followUps('stored-2'));
        await pumpEventQueue();

        expect(seen.events.map((e) => (e as ReplyDelta).text), ['x', 'y']);
        expect(
          gateway.methods.where((m) => m == 'session.resume'),
          hasLength(1),
        );
        await transport.close();
      },
    );

    test(
      'Queued messages: a folded send starts the wait that sends the queue',
      () {
        fakeAsync((async) {
          final rig = _Rig();
          final (_, first) = rig.start('One');
          async.flushMicrotasks();
          rig.chat.submit('Two', const []);
          rig.chat.submit('Three', const []);
          first
            ..emit(const ReplyCompleted('Done.'))
            ..finish();
          async.flushMicrotasks();
          rig.followUp().emit(const SessionInfo(running: false));
          async.flushMicrotasks();
          expect(rig.sentTexts, ['One', 'Two']);

          rig.transport.sends.last
            ..emit(const PromptFolded())
            ..finish();
          async.flushMicrotasks();
          expect(rig.sentTexts, ['One', 'Two']);

          async.elapse(const Duration(seconds: 2));

          expect(rig.sentTexts, ['One', 'Two', 'Three']);
          rig.dispose();
        });
      },
    );
  });

  test('Prompt is rejected: a malformed resume answer fails the send, and the '
      'next send goes through', () async {
    final gateway = FakeGateway()..resumeResult = {'stored_session_id': 'x'};
    final transport = HermesGatewayTransport(
      connect: () async => gateway.channel,
    );

    await expectLater(
      transport.send(threadId: 'stored-1', text: 'hi').toList(),
      throwsA(isA<TypeError>()),
    );
    gateway.resumeResult = {'session_id': 'rt-2'};
    gateway.turn = (g, sid) =>
        g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
    final events = await transport
        .send(threadId: 'stored-1', text: 'hi')
        .toList();

    expect(events.single, isA<ReplyCompleted>());
    await transport.close();
  });

  group('A late completion (finding 10)', () {
    test(
      'Settled without a completion: a completion that comes after a new turn '
      'started does not overwrite the older reply',
      () async {
        final rig = _Rig();
        final (thread, first) = rig.start('One');
        await pumpEventQueue();
        first
          ..emit(const ReplyDelta('partial'))
          ..emit(const SessionInfo(running: false))
          ..finish();
        await pumpEventQueue();
        final old = _replies(thread).single;
        expect(old.settledWithoutCompletion, isTrue);

        rig.chat.submit('Two', const []);
        rig.transport.sends.last
          ..emit(const ReplyCompleted('Answer two'))
          ..finish();
        await pumpEventQueue();
        rig.followUp().emit(const ReplyCompleted('stale'));
        await pumpEventQueue();

        expect(
          [for (final r in _replies(thread)) r.content],
          ['partial', 'Answer two'],
        );
        expect(old.settledWithoutCompletion, isFalse);
        rig.dispose();
      },
    );

    test('Settled without a completion: a completion right after the settle '
        'still lands on the same reply', () async {
      final rig = _Rig();
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      first
        ..emit(const ReplyDelta('partial'))
        ..emit(const SessionInfo(running: false))
        ..finish();
      await pumpEventQueue();

      rig.followUp().emit(const ReplyCompleted('final'));
      await pumpEventQueue();

      expect([for (final r in _replies(thread)) r.content], ['final']);
      rig.dispose();
    });
  });

  group('One predicate for a turn that began (finding 11)', () {
    test('beginsTurn counts every event that shows a turn at work', () {
      final begins = <ChatEvent>[
        const ReplyStarted(),
        const ReplyDelta('a'),
        const ReasoningUpdated('r'),
        const ToolPreparing('t'),
        const ToolStarted(name: 't'),
        const ToolFinished(name: 't'),
        const ReplyErrored('boom'),
      ];
      final reports = <ChatEvent>[
        const SessionInfo(running: false),
        const ReplyCompleted('a'),
        const ReplyStatus('s'),
        const ThreadTitled('t'),
        const ThreadNeedsRefetch(),
        const PromptFolded(),
      ];

      expect(begins.every(beginsTurn), isTrue);
      expect(reports.any(beginsTurn), isFalse);
    });

    test(
      'Stale report before the turn began: reasoning counts as the turn '
      'having begun, so an idle report right after it ends the reply',
      () async {
        final gateway = FakeGateway();
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) {
          g.event('reasoning.delta', sid, {'text': 'hm'});
          g.event('session.info', sid, {'running': false});
        };

        final events = await transport
            .send(text: 'hi')
            .toList()
            .timeout(const Duration(seconds: 5));

        expect(events.map((e) => e.runtimeType), [
          ThreadBound,
          ReasoningUpdated,
          SessionInfo,
        ]);
        await transport.close();
      },
    );
  });

  group('Queued gate: sequences of the second review', () {
    late FakeGateway gateway;
    late HermesGatewayTransport transport;

    setUp(() {
      gateway = FakeGateway()..submitStatus = 'queued';
      transport = HermesGatewayTransport(connect: () async => gateway.channel);
    });
    tearDown(() => transport.close());

    Future<List<ChatEvent>> reply() => transport
        .send(text: 'next', queued: true)
        .toList()
        .timeout(const Duration(seconds: 5));

    test('Queued by the server: a queued turn that is only a failed completion '
        'after the running turn ended reaches the reply', () async {
      gateway.turn = (g, sid) {
        g.event('message.delta', sid, {'text': 'old'});
        g.event('message.complete', sid, {'text': 'old', 'status': 'complete'});
        g.event('session.info', sid, {'running': false});
        g.event('message.complete', sid, {'text': 'boom', 'status': 'error'});
        g.event('session.info', sid, {'running': false});
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ThreadNeedsRefetch,
        ReplyCompleted,
      ]);
      expect((events.last as ReplyCompleted).failed, isTrue);
    });

    test(
      'Queued by the server: a queued turn that is only an error event and a '
      'settle ends as an error',
      () async {
        gateway.turn = (g, sid) {
          g.event('message.delta', sid, {'text': 'old'});
          g.event('message.complete', sid, {
            'text': 'old',
            'status': 'complete',
          });
          g.event('error', sid, {'message': 'boom'});
          g.event('session.info', sid, {'running': false});
        };

        final events = await reply();

        expect(events.map((e) => e.runtimeType), [
          ThreadBound,
          ThreadNeedsRefetch,
          ReplyErrored,
          SessionInfo,
        ]);
      },
    );

    test(
      'Queued by the server: the previous turn already completed, so its '
      'idle report is followed by the queued turn opening with a delta',
      () async {
        gateway.turn = (g, sid) {
          g.event('session.info', sid, {'running': false});
          g.event('message.delta', sid, {'text': 'q'});
          g.event('message.complete', sid, {'text': 'q', 'status': 'complete'});
        };

        final events = await reply();

        expect(events.map((e) => e.runtimeType), [
          ThreadBound,
          ReplyDelta,
          ReplyCompleted,
        ]);
      },
    );

    test('Queued by the server: a goal continuation that starts twice does not '
        'begin the queued reply', () async {
      gateway.turn = (g, sid) {
        g.event('message.delta', sid, {'text': 'goal'});
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'goal again'});
        g.event('message.complete', sid, {
          'text': 'goal again',
          'status': 'complete',
        });
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'q'});
        g.event('message.complete', sid, {'text': 'q', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ThreadNeedsRefetch,
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
      expect((events[3] as ReplyDelta).text, 'q');
    });
  });

  group('Second review: controller and transport', () {
    test('Settled without a completion: a late completion is applied without a '
        'second notification', () async {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      final live = _Live();
      final thread = await live.start('One');
      live.gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'Partial'})
        ..event('session.info', 'rt-1', {'running': false});
      await live.settle();
      expect(live.service.shown, hasLength(1));

      live.gateway.event('message.complete', 'rt-1', {
        'text': 'Final',
        'status': 'complete',
      });
      await live.settle();

      expect(_replies(thread).single.content, 'Final');
      expect(live.service.shown, hasLength(1));
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await live.dispose();
    });

    test('Error event without a completion: a chained turn that errors and '
        'settles while the queue waits does not send the queue', () async {
      final rig = _Rig();
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      rig.chat.submit('Two', const []);
      first
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();

      rig.followUp()
        ..emit(const ReplyDelta('chained'))
        ..emit(const ReplyErrored('boom'))
        ..emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(rig.sentTexts, ['One']);
      expect(rig.chat.queuePaused(thread), isTrue);
      expect(_replies(thread).last.status, MessageStatus.error);
      rig.dispose();
    });

    test('Paused by a failure: after error-then-settle on the send, a chained '
        'turn is still shown and the queue stays paused', () async {
      final live = _Live();
      final thread = await live.start('One');
      live.chat.submit('Two', const []);
      await live.settle();

      live.gateway
        ..event('error', 'rt-1', {'message': 'boom'})
        ..event('session.info', 'rt-1', {'running': false});
      await live.settle();
      live.gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'chained'})
        ..event('message.complete', 'rt-1', {
          'text': 'chained',
          'status': 'complete',
        });
      await live.settle();

      expect(_replies(thread).map((r) => r.status), [
        MessageStatus.error,
        MessageStatus.sent,
      ]);
      expect(_replies(thread).last.content, 'chained');
      expect(live.chat.queuePaused(thread), isTrue);
      expect(live.submits, 1);
      await live.dispose();
    });

    test(
      'Paused by stop: a stop answered with only an idle report does not send '
      'the queue',
      () async {
        final rig = _Rig();
        final (thread, send) = rig.start('One');
        await pumpEventQueue();
        rig.chat.submit('Two', const []);

        await rig.chat.stopReply(thread);
        send
          ..emit(const ReplyDelta('part'))
          ..emit(const SessionInfo(running: false))
          ..finish();
        await pumpEventQueue();

        expect(rig.sentTexts, ['One']);
        expect(rig.chat.queuePaused(thread), isTrue);
        rig.dispose();
      },
    );

    test('Missed start of a chained turn: a stray error or a late tool result '
        'on the follow-ups opens no reply', () async {
      final rig = _Rig();
      final (thread, first) = rig.start('One');
      await pumpEventQueue();
      first
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();

      rig.followUp()
        ..emit(const ReplyErrored('late'))
        ..emit(const ToolFinished(name: 'terminal'));
      await pumpEventQueue();

      expect(thread.messages, hasLength(2));
      expect(thread.isReplying, isFalse);
      rig.dispose();
    });

    test('Compression rotates the stored id: a pick-up that is cancelled after '
        'a re-key leaves no closed watch parked', () async {
      final gateway = FakeGateway()
        ..resumeResult = {'session_id': 'rt-9', 'running': true};
      final transport = HermesGatewayTransport(
        connect: () async => gateway.channel,
      );
      final subscription = transport.followUps('stored-1').listen((_) {});
      await pumpEventQueue();
      gateway.event('session.info', 'rt-9', {
        'running': true,
        'stored_session_id': 'stored-2',
      });
      await pumpEventQueue();
      await subscription.cancel();
      await pumpEventQueue();

      int resumes() =>
          gateway.methods.where((m) => m == 'session.resume').length;
      final before = resumes();
      final seen = _listen(transport.followUps('stored-2'));
      await pumpEventQueue();

      // A closed watch left parked would be served instead of asking again.
      expect(resumes(), greaterThan(before));
      expect(seen.done, isFalse);
      await transport.close();
    });

    test(
      'Compression rotates the stored id: a send under the old id before the '
      'caller re-keyed does not show the turn twice',
      () async {
        final gateway = FakeGateway();
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Hi',
          'status': 'complete',
        });
        await transport.send(text: 'hi').toList();
        final follow = _listen(transport.followUps('stored-1'));
        await pumpEventQueue();
        gateway.event('session.info', 'rt-1', {
          'running': true,
          'stored_session_id': 'stored-2',
        });
        await pumpEventQueue();

        gateway.resumeResult = {'session_id': 'rt-1'};
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'again'});
          g.event('message.complete', sid, {
            'text': 'again',
            'status': 'complete',
          });
        };
        final events = await transport
            .send(threadId: 'stored-1', text: 'more')
            .toList();
        await pumpEventQueue();

        expect(events.whereType<ReplyDelta>(), hasLength(1));
        expect(follow.events.whereType<ReplyDelta>(), isEmpty);
        await transport.close();
      },
    );
  });

  group('Third review', () {
    test(
      'Queued by the server: a running turn that took over 15 s does not make '
      'its own idle report settle the queued reply',
      () {
        fakeAsync((async) {
          final gateway = FakeGateway()..submitStatus = 'queued';
          final transport = HermesGatewayTransport(
            connect: () async => gateway.channel,
          );
          gateway.turn = (g, sid) =>
              g.event('message.delta', sid, {'text': 'old'});
          final seen = _listen(transport.send(text: 'next', queued: true));
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 20));
          gateway
            ..event('message.complete', 'rt-1', {
              'text': 'old',
              'status': 'complete',
            })
            ..event('session.info', 'rt-1', {'running': false});
          async.flushMicrotasks();
          expect(seen.done, isFalse);

          gateway
            ..event('message.start', 'rt-1')
            ..event('message.complete', 'rt-1', {
              'text': 'new',
              'status': 'complete',
            });
          async.flushMicrotasks();

          expect(seen.done, isTrue);
          expect(seen.events.whereType<ReplyCompleted>().single.text, 'new');
        });
      },
    );

    test(
      'Error event without a completion: a chained turn that is only an error '
      'and a settle pauses the queue and says why',
      () async {
        final rig = _Rig();
        final (thread, first) = rig.start('One');
        await pumpEventQueue();
        rig.chat.submit('Two', const []);
        first
          ..emit(const ReplyCompleted('Done.'))
          ..finish();
        await pumpEventQueue();

        rig.followUp()
          ..emit(const ReplyErrored('boom'))
          ..emit(const SessionInfo(running: false));
        await pumpEventQueue();

        expect(rig.sentTexts, ['One']);
        expect(rig.chat.queuePaused(thread), isTrue);
        expect(rig.reports, ['boom']);
        expect(thread.messages, hasLength(2));
        rig.dispose();
      },
    );

    test('Paused by stop: a stop answered with only an idle report is not '
        'announced as a finished reply', () async {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      final live = _Live();
      final thread = await live.start('One');
      live.gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'part'});
      await live.settle();

      await live.chat.stopReply(thread);
      live.gateway.event('session.info', 'rt-1', {'running': false});
      await live.settle();

      expect(thread.isReplying, isFalse);
      expect(live.service.shown, isEmpty);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await live.dispose();
    });
  });
}
