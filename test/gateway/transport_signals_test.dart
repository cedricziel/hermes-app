import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

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

List<Type> _types(Iterable<ChatEvent> events) =>
    events.map((e) => e.runtimeType).toList();

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  /// The events of a whole reply. Fails instead of hanging when the stream
  /// never ends.
  Future<List<ChatEvent>> reply({String? threadId, String text = 'hi'}) =>
      transport
          .send(threadId: threadId, text: text)
          .toList()
          .timeout(const Duration(seconds: 5));

  /// A reply that ended, so the transport listens on for the next turn.
  Future<void> finishedReply() async {
    gateway.turn = (g, sid) =>
        g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
    await reply();
  }

  group('approvals cancelled by an interrupt (9.1)', () {
    const approval = {
      'request_id': 'r1',
      'command': 'rm -rf build',
      'description': 'delete files',
      'choices': ['once', 'deny'],
      'tool_name': 'terminal',
    };

    /// A reply with two approvals open, still streaming.
    Future<_Seen> twoOpenApprovals() async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('approval.request', sid, approval);
        g.event('approval.request', sid, {...approval, 'request_id': 'r2'});
      };
      final seen = _listen(transport.send(text: 'hi'));
      await pumpEventQueue();
      expect(seen.events.whereType<ApprovalRequested>(), hasLength(2));
      return seen;
    }

    test('Approvals cancelled by an interrupt: the broadcast reaches the '
        'reply and the listed ids can no longer be answered', () async {
      final seen = await twoOpenApprovals();

      gateway.event('approval.cancelled', '', {
        'session_id': 'rt-1',
        'request_ids': ['r1'],
      });
      await pumpEventQueue();

      final cancelled = seen.events.whereType<InputRequestsCancelled>().single;
      expect(cancelled.requestIds, ['r1']);
      expect(await transport.answerApproval('r1', 'once'), isFalse);
      expect(await transport.answerApproval('r2', 'once'), isTrue);
    });

    test('Approvals cancelled by an interrupt: no ids withdraws every open '
        'request of the reply', () async {
      final seen = await twoOpenApprovals();

      gateway.event('approval.cancelled', '', {'session_id': 'rt-1'});
      await pumpEventQueue();

      expect(
        seen.events.whereType<InputRequestsCancelled>().single.requestIds,
        isEmpty,
      );
      expect(await transport.answerApproval('r1', 'once'), isFalse);
      expect(await transport.answerApproval('r2', 'once'), isFalse);
    });

    test('Another session: its broadcast changes nothing here', () async {
      final seen = await twoOpenApprovals();

      gateway.event('approval.cancelled', '', {
        'session_id': 'rt-other',
        'request_ids': ['r1'],
      });
      await pumpEventQueue();

      expect(seen.events.whereType<InputRequestsCancelled>(), isEmpty);
      expect(await transport.answerApproval('r1', 'once'), isTrue);
    });

    test('Approvals cancelled by an interrupt: a thread that is only '
        'listened to drops the ids too', () async {
      await finishedReply();
      final seen = _listen(transport.followUps('stored-1'));
      gateway
        ..event('message.start', 'rt-1')
        ..event('approval.request', 'rt-1', approval);
      await pumpEventQueue();

      gateway.event('approval.cancelled', '', {
        'session_id': 'rt-1',
        'request_ids': ['r1'],
      });
      await pumpEventQueue();

      expect(_types(seen.events), [
        ReplyStarted,
        ApprovalRequested,
        InputRequestsCancelled,
      ]);
      expect(await transport.answerApproval('r1', 'once'), isFalse);
    });
  });

  group('a chained turn that nobody started (9.2)', () {
    test(
      'Two starts for one continuation: followUps shows one start',
      () async {
        await finishedReply();
        final seen = _listen(transport.followUps('stored-1'));

        gateway
          ..event('message.start', 'rt-1')
          ..event('message.start', 'rt-1')
          ..event('message.delta', 'rt-1', {'text': 'goal'})
          ..event('message.complete', 'rt-1', {
            'text': 'goal',
            'status': 'complete',
          });
        await pumpEventQueue();

        expect(_types(seen.events), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      },
    );

    for (final (label, type, payload, expected)
        in <(String, String, Map<String, Object?>, Type)>[
          ('a delta', 'message.delta', {'text': 'x'}, ReplyDelta),
          (
            'a tool being prepared',
            'tool.generating',
            {'name': 't'},
            ToolPreparing,
          ),
          (
            'a tool start',
            'tool.start',
            {'tool_id': 't1', 'name': 'terminal'},
            ToolStarted,
          ),
          ('reasoning', 'reasoning.delta', {'text': 'hm'}, ReasoningUpdated),
        ]) {
      test('Missed start of a chained turn: $label opens the turn, so the '
          'start that follows is not a second one', () async {
        await finishedReply();
        final seen = _listen(transport.followUps('stored-1'));

        gateway
          ..event(type, 'rt-1', payload)
          ..event('message.start', 'rt-1')
          ..event('message.complete', 'rt-1', {
            'text': 'x',
            'status': 'complete',
          });
        await pumpEventQueue();

        expect(_types(seen.events), [expected, ReplyCompleted]);
      });
    }
  });

  group('a turn nobody submitted, after a resume (9.3)', () {
    final autoContinue = {
      'session_id': 'rt-2',
      'session_key': 'stored-2',
      'auto_continue': {'attempt': 1},
    };

    void unsolicitedTurn(FakeGateway g, {String text = 'resumed work'}) {
      g.event('message.start', 'rt-2');
      g.event('message.delta', 'rt-2', {'text': text});
    }

    void unsolicitedEnd(FakeGateway g, {String text = 'resumed work'}) =>
        g.event('message.complete', 'rt-2', {
          'text': text,
          'status': 'complete',
        });

    void submittedTurn(FakeGateway g, String sid) {
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'mine'});
      g.event('message.complete', sid, {'text': 'mine', 'status': 'complete'});
    }

    Future<List<ChatEvent>> followed(int count) => transport
        .followUps('stored-2')
        .take(count)
        .toList()
        .timeout(const Duration(seconds: 5));

    setUp(() => gateway.resumeResult = autoContinue);

    test('Auto-continue after resume: a turn that ended before the submit was '
        'answered reaches the follow-ups, and the prompt still gets its own '
        'turn', () async {
      gateway.beforeSubmitAnswer = (g) {
        unsolicitedTurn(g);
        unsolicitedEnd(g);
      };
      gateway.turn = submittedTurn;

      final sent = await reply(threadId: 'stored-2');
      final later = await followed(3);

      expect(_types(sent), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      expect((sent[1] as ReplyDelta).text, 'mine');
      expect(_types(later), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      expect((later[1] as ReplyDelta).text, 'resumed work');
    });

    test('Auto-continue after resume: a turn that failed at once is set aside '
        'with its error and its idle report', () async {
      gateway.beforeSubmitAnswer = (g) {
        g.event('message.start', 'rt-2');
        g.event('error', 'rt-2', {'message': 'provider down'});
        g.event('message.complete', 'rt-2', {'text': '', 'status': 'error'});
        g.event('session.info', 'rt-2', {'running': false});
      };
      gateway.turn = submittedTurn;

      final sent = await reply(threadId: 'stored-2');
      final later = await followed(4);

      expect(_types(sent), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      expect((sent.last as ReplyCompleted).failed, isFalse);
      expect(_types(later), [
        ReplyStarted,
        ReplyErrored,
        ReplyCompleted,
        SessionInfo,
      ]);
    });

    test('Auto-continue after resume: an approval of a turn that is already '
        'over is not a live card, and the send shows no status', () async {
      gateway.beforeSubmitAnswer = (g) {
        unsolicitedTurn(g);
        g.serverRequest('srq-old', 'approval', 'rt-2', {
          'command': 'rm -rf build',
          'description': 'delete files',
          'choices': ['once', 'deny'],
          'tool_name': 'terminal',
        });
        unsolicitedEnd(g);
      };
      gateway.turn = submittedTurn;

      final sent = await reply(threadId: 'stored-2');

      expect(_types(sent), [ReplyStarted, ReplyDelta, ReplyCompleted]);
    });

    test('Auto-continue after resume: a request of a turn that is already over '
        'cannot be answered while the send runs', () async {
      gateway.beforeSubmitAnswer = (g) {
        unsolicitedTurn(g);
        g.serverRequest('srq-old', 'approval', 'rt-2', {
          'command': 'ls build',
          'description': 'list files',
          'choices': ['once', 'deny'],
          'tool_name': 'terminal',
        });
        unsolicitedEnd(g);
      };
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'mine'});
      };

      final seen = _listen(transport.send(threadId: 'stored-2', text: 'hi'));
      await pumpEventQueue();

      expect(_types(seen.events), [ReplyStarted, ReplyDelta]);
      expect(seen.done, isFalse);
      expect(await transport.answerApproval('srq-old', 'once'), isFalse);
      expect(gateway.responses, isEmpty);
    });

    test('Auto-continue after resume: a prompt queued behind the turn gets its '
        'own turn, and the turn reaches the follow-ups', () async {
      gateway.submitStatus = 'queued';
      gateway.beforeSubmitAnswer = unsolicitedTurn;
      gateway.turn = (g, sid) {
        unsolicitedEnd(g);
        submittedTurn(g, sid);
      };

      final sent = await reply(threadId: 'stored-2');
      final later = await followed(3);

      expect(_types(sent), [
        ReplyStatus,
        ReplyStatus,
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
      expect((sent[3] as ReplyDelta).text, 'mine');
      expect(_types(later), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      expect((later[1] as ReplyDelta).text, 'resumed work');
    });

    test('Auto-continue after resume: a prompt folded into the turn leaves it '
        'to the follow-ups', () async {
      gateway.submitStatus = 'redirected';
      gateway.beforeSubmitAnswer = unsolicitedTurn;
      gateway.turn = (g, sid) => unsolicitedEnd(g);

      final sent = await reply(threadId: 'stored-2');
      final later = await followed(3);

      expect(_types(sent), [PromptFolded]);
      expect(_types(later), [ReplyStarted, ReplyDelta, ReplyCompleted]);
    });

    test('Auto-continue after resume: a drop that hides the turn\'s end does '
        'not hand it to the prompt\'s reply', () async {
      final dropping = FakeGateway()
        ..stampSeq = true
        ..sendReady = true
        ..resumeResult = autoContinue
        ..submitStatus = 'queued'
        ..beforeSubmitAnswer = unsolicitedTurn;
      final reconnecting = HermesGatewayTransport(connect: dropping.connect);
      addTearDown(reconnecting.close);
      dropping.turn = (g, sid) {
        g.drop();
        unsolicitedEnd(g);
        submittedTurn(g, sid);
      };

      final sent = await reconnecting
          .send(threadId: 'stored-2', text: 'hi')
          .toList()
          .timeout(const Duration(seconds: 5));
      final later = await reconnecting
          .followUps('stored-2')
          .take(6)
          .toList()
          .timeout(const Duration(seconds: 5));

      expect(sent.whereType<ReplyDelta>(), isEmpty);
      expect(sent.last, isA<SessionInfo>());
      expect(_types(later), [
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
        ReplyStarted,
        ReplyDelta,
        ReplyCompleted,
      ]);
    });

    test('Auto-continue after resume: a drop that ends the turn clears the '
        'status the send showed', () async {
      final dropping = FakeGateway()
        ..stampSeq = true
        ..sendReady = true
        ..resumeResult = autoContinue
        ..submitStatus = 'queued'
        ..beforeSubmitAnswer = unsolicitedTurn;
      final reconnecting = HermesGatewayTransport(connect: dropping.connect);
      addTearDown(reconnecting.close);
      dropping.turn = (g, sid) {
        g.drop();
        unsolicitedEnd(g);
        submittedTurn(g, sid);
      };

      final sent = await reconnecting
          .send(threadId: 'stored-2', text: 'hi')
          .toList()
          .timeout(const Duration(seconds: 5));

      expect(sent.whereType<ReplyStatus>().map((e) => e.text), [
        'Hermes is finishing the interrupted turn…',
        '',
      ]);
    });

    group('while the turn nobody submitted still runs', () {
      const approval = {
        'command': 'rm -rf build',
        'description': 'delete files',
        'choices': ['once', 'deny'],
        'tool_name': 'terminal',
      };

      /// A prompt queued behind a turn that has begun and asks for approval.
      _Seen queuedBehindApproval() {
        gateway.submitStatus = 'queued';
        gateway.beforeSubmitAnswer = (g) {
          unsolicitedTurn(g);
          g.serverRequest('srq-1', 'approval', 'rt-2', approval);
        };
        return _listen(transport.send(threadId: 'stored-2', text: 'hi'));
      }

      test('Auto-continue after resume: an approval the turn raises reaches '
          'the send while the turn runs, and can be answered', () async {
        final seen = queuedBehindApproval();
        await pumpEventQueue();

        expect(seen.events.whereType<ApprovalRequested>(), hasLength(1));
        expect(seen.done, isFalse);
        expect(await transport.answerApproval('srq-1', 'once'), isTrue);
        await pumpEventQueue();
        expect(gateway.responses.single['id'], 'srq-1');
        expect(gateway.responses.single['result'], {'choice': 'once'});
      });

      test('Auto-continue after resume: the send says Hermes is finishing the '
          'turn, and clears it when the turn ends', () async {
        final seen = queuedBehindApproval();
        await pumpEventQueue();

        expect(seen.events.whereType<ReplyStatus>().map((e) => e.text), [
          'Hermes is finishing the interrupted turn…',
        ]);

        unsolicitedEnd(gateway);
        await pumpEventQueue();

        expect(seen.events.whereType<ReplyStatus>().map((e) => e.text), [
          'Hermes is finishing the interrupted turn…',
          '',
        ]);
      });

      test('Auto-continue after resume: when the turn ends, the send withdraws '
          'the requests it passed through', () async {
        final seen = queuedBehindApproval();
        await pumpEventQueue();
        expect(await transport.answerApproval('srq-1', 'once'), isTrue);

        unsolicitedEnd(gateway);
        await pumpEventQueue();

        expect(
          seen.events.whereType<InputRequestsCancelled>().single.requestIds,
          ['srq-1'],
        );
        expect(await transport.answerApproval('srq-1', 'once'), isFalse);
      });

      test('Auto-continue after resume: a request already withdrawn is not '
          'withdrawn again when the turn ends', () async {
        final seen = queuedBehindApproval();
        await pumpEventQueue();
        gateway.event('approval.cancelled', '', {'session_id': 'rt-2'});
        await pumpEventQueue();
        expect(
          seen.events.whereType<InputRequestsCancelled>().single.requestIds,
          isEmpty,
        );

        unsolicitedEnd(gateway);
        await pumpEventQueue();

        expect(seen.events.whereType<InputRequestsCancelled>(), hasLength(1));
      });

      test('Auto-continue after resume: the follow-ups do not repeat a request '
          'the send showed', () async {
        final seen = queuedBehindApproval();
        await pumpEventQueue();
        expect(await transport.answerApproval('srq-1', 'once'), isTrue);
        unsolicitedEnd(gateway);
        submittedTurn(gateway, 'rt-2');
        await pumpEventQueue();
        expect(seen.done, isTrue);

        final later = await followed(3);

        expect(_types(later), [ReplyStarted, ReplyDelta, ReplyCompleted]);
        expect(await transport.answerApproval('srq-1', 'once'), isFalse);
      });
    });

    test('Auto-continue after resume: a reply that has begun when the submit '
        'is answered is the prompt\'s own', () async {
      gateway.beforeSubmitAnswer = (g) {
        g.event('message.start', 'rt-2');
        g.event('message.delta', 'rt-2', {'text': 'mine'});
      };
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'mine',
        'status': 'complete',
      });

      final sent = await reply(threadId: 'stored-2');

      expect(_types(sent), [ReplyStarted, ReplyDelta, ReplyCompleted]);
    });

    test('Auto-continue after resume: nothing is set aside when the resume '
        'reported none', () async {
      gateway.resumeResult = {'session_id': 'rt-2', 'session_key': 'stored-2'};
      gateway.beforeSubmitAnswer = (g) {
        g.event('message.start', 'rt-2');
        g.event('message.delta', 'rt-2', {'text': 'mine'});
      };
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'mine',
        'status': 'complete',
      });

      final sent = await reply(threadId: 'stored-2');

      expect(_types(sent), [ReplyStarted, ReplyDelta, ReplyCompleted]);
    });
  });

  group('a turn nobody submitted, when the send gives up (476)', () {
    final autoContinue = {
      'session_id': 'rt-2',
      'session_key': 'stored-2',
      'auto_continue': {'attempt': 1},
    };

    test('Auto-continue after resume: a send that gives up after a drop leaves '
        'the turn it set aside to the follow-ups', () async {
      final server = FakeGateway()
        ..stampSeq = true
        ..sendReady = true
        ..resumeResult = autoContinue
        ..submitStatus = 'queued'
        ..beforeSubmitAnswer = (g) {
          g.event('message.start', 'rt-2');
          g.event('message.delta', 'rt-2', {'text': 'resumed work'});
        };
      var reachable = true;
      final flaky = HermesGatewayTransport(
        sleep: (_) async {},
        connect: () async {
          if (!reachable) throw StateError('gateway unreachable');
          return server.connect();
        },
      );
      addTearDown(flaky.close);
      server.turn = (g, sid) {
        g.event('message.complete', 'rt-2', {
          'text': 'resumed work',
          'status': 'complete',
        });
        reachable = false;
        g.drop();
      };

      final sent = _listen(flaky.send(threadId: 'stored-2', text: 'hi'));
      await pumpEventQueue();
      expect(sent.error, isA<GatewayConnectionClosed>());

      reachable = true;
      final later = await flaky
          .followUps('stored-2')
          .take(3)
          .toList()
          .timeout(const Duration(seconds: 5));

      expect(_types(later), [ReplyStarted, ReplyDelta, ReplyCompleted]);
      expect((later[1] as ReplyDelta).text, 'resumed work');
    });
  });

  group('requests of a turn nobody submitted, across a re-key (476)', () {
    const approval = {
      'command': 'rm -rf build',
      'description': 'delete files',
      'choices': ['once', 'deny'],
      'tool_name': 'terminal',
    };

    /// A prompt queued behind an auto-continue turn that asked for approval
    /// and then lost its connection; the resume moved the reply from `rt-2`
    /// to `rt-3`.
    Future<_Seen> rekeyedBehindApproval() async {
      transport = HermesGatewayTransport(connect: gateway.connect);
      gateway
        ..resumeResult = {
          'session_id': 'rt-2',
          'session_key': 'stored-2',
          'auto_continue': {'attempt': 1},
        }
        ..submitStatus = 'queued'
        ..beforeSubmitAnswer = (g) {
          g.event('message.start', 'rt-2');
          g.serverRequest('srq-1', 'approval', 'rt-2', approval);
        }
        ..turn = (g, sid) {
          g.resumeResult = {'session_id': 'rt-3', 'running': true};
          g.drop();
        };
      final seen = _listen(transport.send(threadId: 'stored-2', text: 'hi'));
      await pumpEventQueue();
      expect(seen.events.whereType<ApprovalRequested>(), hasLength(1));
      expect(gateway.methods.where((m) => m == 'session.resume'), hasLength(2));
      return seen;
    }

    test('Auto-continue after resume: a turn that ends after a re-key still '
        'withdraws the requests it passed through', () async {
      final seen = await rekeyedBehindApproval();

      gateway.event('message.complete', 'rt-3', {
        'text': 'resumed work',
        'status': 'complete',
      });
      await pumpEventQueue();

      expect(
        seen.events.whereType<InputRequestsCancelled>().single.requestIds,
        ['srq-1'],
      );
      expect(await transport.answerApproval('srq-1', 'once'), isFalse);
    });

    test('Withdrawn approvals: a broadcast for the session after a re-key '
        'withdraws the open request', () async {
      final seen = await rekeyedBehindApproval();

      gateway.event('approval.cancelled', '', {'session_id': 'rt-3'});
      await pumpEventQueue();

      expect(seen.events.whereType<InputRequestsCancelled>(), hasLength(1));
      expect(await transport.answerApproval('srq-1', 'once'), isFalse);
    });
  });

  group('a request before the prompt\'s first frame (476)', () {
    test(
      'Auto-continue after resume: an approval the prompt\'s own turn raises '
      'before its first frame is not withdrawn with the turn ahead',
      () async {
        gateway
          ..resumeResult = {
            'session_id': 'rt-2',
            'session_key': 'stored-2',
            'auto_continue': {'attempt': 1},
          }
          ..submitStatus = 'queued'
          ..beforeSubmitAnswer = (g) {
            g.event('message.start', 'rt-2');
            g.event('message.delta', 'rt-2', {'text': 'resumed work'});
          }
          ..turn = (g, sid) {
            g.event('message.complete', 'rt-2', {
              'text': 'resumed work',
              'status': 'complete',
            });
            g.serverRequest('srq-2', 'approval', 'rt-2', {
              'command': 'ls build',
              'description': 'list files',
              'choices': ['once', 'deny'],
              'tool_name': 'terminal',
            });
          };

        final seen = _listen(transport.send(threadId: 'stored-2', text: 'hi'));
        await pumpEventQueue();

        expect(seen.events.whereType<ApprovalRequested>(), hasLength(1));
        expect(seen.events.whereType<InputRequestsCancelled>(), isEmpty);
        expect(await transport.answerApproval('srq-2', 'once'), isTrue);
      },
    );
  });

  group('status lines (9.4)', () {
    test('Compacting: a status.update reaches the reply as a status', () async {
      gateway.turn = (g, sid) {
        g.event('status.update', sid, {'kind': 'compacting', 'text': 'x'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(_types(events), [ThreadBound, ReplyStatus, ReplyCompleted]);
      expect((events[1] as ReplyStatus).text, 'Compacting the conversation…');
    });

    test('Explained provider wait: a thinking.delta that explains the wait '
        'reaches the reply as a status', () async {
      gateway.turn = (g, sid) {
        g.event('thinking.delta', sid, {
          'text': '⏳ waiting on local-model — 30s with no output yet',
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(_types(events), [ThreadBound, ReplyStatus, ReplyCompleted]);
      expect(
        (events[1] as ReplyStatus).text,
        '⏳ waiting on local-model — 30s with no output yet',
      );
    });
  });

  group('silence probe on a chained turn', () {
    /// A transport whose first reply ended, with a follow-up stream listening
    /// and a turn Hermes chained on its own under way and then silent.
    ({_Seen seen, FakeGateway gateway}) chainedAndSilent(
      FakeAsync async,
      Map<String, String> listed,
    ) {
      final gateway = FakeGateway()..activeSessions = listed;
      final transport = HermesGatewayTransport(
        connect: () async => gateway.channel,
      );
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Hi',
        'status': 'complete',
      });
      _listen(transport.send(text: 'hi'));
      async.flushMicrotasks();
      final seen = _listen(transport.followUps('stored-1'));
      async.flushMicrotasks();
      gateway.event('message.start', 'rt-1');
      async.flushMicrotasks();
      return (seen: seen, gateway: gateway);
    }

    int probes(FakeGateway gateway) =>
        gateway.methods.where((m) => m == 'session.active_list').length;

    test(
      'A silent live turn: a chained turn no longer listed ends as broken',
      () {
        fakeAsync((async) {
          final (:seen, :gateway) = chainedAndSilent(async, {});

          async.elapse(const Duration(seconds: 44));
          async.flushMicrotasks();
          expect(seen.error, isNull);

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(probes(gateway), 1);
          expect(seen.error, isA<GatewayConnectionClosed>());
          expect(seen.done, isTrue);
        });
      },
    );

    test('A silent live turn: a chained turn still listed keeps waiting', () {
      fakeAsync((async) {
        final (:seen, :gateway) = chainedAndSilent(async, {
          'stored-1': 'working',
        });

        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();
        expect(probes(gateway), 1);
        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();

        expect(probes(gateway), 2);
        expect(seen.error, isNull);
        expect(seen.done, isFalse);

        gateway.event('message.complete', 'rt-1', {
          'text': 'late',
          'status': 'complete',
        });
        async.flushMicrotasks();
        expect(seen.events.last, isA<ReplyCompleted>());
      });
    });

    test('A silent live turn: an idle thread is not probed', () {
      fakeAsync((async) {
        final gateway = FakeGateway()..activeSessions = {};
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Hi',
          'status': 'complete',
        });
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        final seen = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 200));
        async.flushMicrotasks();

        expect(probes(gateway), 0);
        expect(seen.error, isNull);
        expect(seen.done, isFalse);
      });
    });
  });
}
