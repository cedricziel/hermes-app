import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/reply_diagnostics.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/diagnosis_buckets.dart';

import 'support/fake_chat_transport.dart';
import 'support/recorded_events.dart';

/// Recognisable text no event may carry.
const _prompt = 'SENTINEL_PROMPT_91c2 deploy the secret thing';
const _serverText = 'SENTINEL_SERVER_TEXT_91c2';

/// What `chat.reply.ended` and its companions say about a reply that was
/// lost, failed or ended well: fixed names, buckets and counts only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late RecordedEvents events;
  late ChatController chat;
  late ChatThread thread;
  late FakeSend send;
  late DateTime now;

  ChatController build({void Function(String, Map<String, Object>)? log}) {
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final controller = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      events: log == null
          ? events.call
          : (name, [attributes = const {}]) {
              log(name, attributes);
            },
      reconnectRetry: const Duration(hours: 1),
      now: () => now,
    );
    addTearDown(() {
      controller.dispose();
      attention.dispose();
    });
    return controller;
  }

  Future<void> startTurn({String text = _prompt}) async {
    chat.newThread();
    thread = chat.selectedThread!;
    expect(chat.submit(text, const []), isTrue);
    send = transport.sends.single;
    send
      ..emit(const ThreadBound('s1'))
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Working. '));
    await pumpEventQueue();
  }

  Future<void> lose([Object error = const GatewayReplyLost()]) async {
    send.fail(error);
    await pumpEventQueue();
  }

  List<Map<String, Object>> ended() => events.named('chat.reply.ended');

  setUp(() {
    now = DateTime(2026, 11, 15, 12);
    transport = FakeChatTransport();
    events = RecordedEvents();
    chat = build();
  });

  group('chat.reply.ended', () {
    test('a completed reply says so with the fixed attribute set', () async {
      await startTurn();
      send
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();

      expect(ended(), [
        {
          'outcome': 'completed',
          'cause': 'none',
          'step': 'none',
          'reconnect_attempts': 0,
          'away': 'under_5s',
          'duration': 'under_1s',
          'queue_len': '0',
        },
      ]);
    });

    test('a loss before the server had the prompt is a failed reply', () async {
      chat.newThread();
      thread = chat.selectedThread!;
      await chat.submit(_prompt, const []);
      send = transport.sends.single;
      send.emit(const ThreadBound('s1'));
      await pumpEventQueue();
      await lose(const GatewayConnectionClosed());

      expect(ended().single['outcome'], 'failed');
      expect(ended().single['cause'], 'connection_closed');
    });

    test('a send that failed at a step names the step', () async {
      chat.newThread();
      await chat.submit(_prompt, const []);
      transport.sends.single.fail(
        const SendFailure(SendStep.connect, GatewayCallTimedOut()),
      );
      await pumpEventQueue();

      expect(ended().single['outcome'], 'failed');
      expect(ended().single['cause'], 'timeout');
      expect(ended().single['step'], 'connect');
    });

    test('a request that gave up waiting is a timeout', () async {
      chat.newThread();
      await chat.submit(_prompt, const []);
      transport.sends.single.fail(
        const SendFailure(SendStep.attach, GatewayRequestTimeout()),
      );
      await pumpEventQueue();

      expect(ended().single['cause'], 'timeout');
      expect(ended().single['step'], 'attach');
    });

    test('a stopped reply is stopped, by the user', () async {
      await startTurn();
      send
        ..emit(const ReplyCompleted('Done.', stopped: true))
        ..finish();
      await pumpEventQueue();

      expect(ended().single['outcome'], 'stopped');
    });

    test(
      'a reply that ends without a completion fails as a server error',
      () async {
        await startTurn();
        send.finish();
        await pumpEventQueue();

        expect(ended().single['outcome'], 'failed');
      },
    );

    test(
      'a lost connection is not an end, and the pick-up closes it',
      () async {
        await startTurn();
        await lose();

        expect(ended().single['outcome'], 'lost_connection');
        expect(ended().single['cause'], 'reconnect_gave_up');
        expect(ended().single['reconnect_attempts'], 1);

        now = now.add(const Duration(seconds: 40));
        chat.checkConnection();
        await pumpEventQueue();
        transport.followUpStreams['s1']!
          ..emit(const ReplyStarted())
          ..emit(const ReplyCompleted('Done.'));
        await pumpEventQueue();

        expect(ended().last['outcome'], 'completed');
        expect(ended().last['reconnect_attempts'], 2);
        expect(ended(), hasLength(2));
      },
    );

    test('a settled held reply ends exactly once', () async {
      await startTurn();
      await lose();
      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(const ReplyCompleted('Done.'))
        ..emit(const SessionInfo(running: false))
        ..emit(const ReplyDelta('A chained turn.'))
        ..emit(const ReplyCompleted('A chained turn.'));
      await pumpEventQueue();

      expect(ended().where((e) => e['outcome'] == 'completed'), hasLength(1));
      expect(ended(), hasLength(2));
    });

    test('a pick-up that finds the session gone is a failed reply', () async {
      await startTurn();
      await lose();

      chat.checkConnection();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.fail(const GatewaySessionGone(4007));
      await pumpEventQueue();

      expect(ended().last['outcome'], 'failed');
      expect(ended().last['cause'], 'session_gone');
    });

    test('the queue behind a reply is counted, never listed', () async {
      await startTurn();
      await chat.submit('SENTINEL_QUEUED_91c2', const []);
      await pumpEventQueue();
      await lose();

      expect(ended().single['queue_len'], '1');
      expect(events.named('chat.queue.state'), [
        {'state': 'held', 'count': '1'},
      ]);
    });
  });

  group('chat.queue.state', () {
    test('a failed reply pauses what waited behind it', () async {
      await startTurn();
      await chat.submit('second', const []);
      await chat.submit('third', const []);
      await pumpEventQueue();
      send.fail(StateError(_serverText));
      await pumpEventQueue();

      expect(events.named('chat.queue.state'), [
        {'state': 'paused', 'count': '2_3'},
      ]);
    });

    test('a completed reply drains the next prompt', () async {
      await startTurn();
      await chat.submit('second', const []);
      await pumpEventQueue();
      send
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();
      // The session reports itself idle: the queue goes on at once, with no
      // wait for the settle timer.
      transport.followUpStreams['s1']!.emit(const SessionInfo(running: false));
      await pumpEventQueue();

      expect(transport.sends, hasLength(2));
      expect(
        events.named('chat.queue.state'),
        anyElement(equals({'state': 'drained', 'count': '0'})),
      );
    });
  });

  group('app.lifecycle', () {
    test('nothing is logged while no reply runs', () {
      chat.appLifecycleChanged(AppLifecycleState.paused);
      chat.appLifecycleChanged(AppLifecycleState.resumed);

      expect(events.named('app.lifecycle'), isEmpty);
    });

    test('leaving and returning during a reply say how long it was', () async {
      await startTurn();
      chat.appLifecycleChanged(AppLifecycleState.inactive);
      chat.appLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 90));
      chat.appLifecycleChanged(AppLifecycleState.resumed);

      expect(events.named('app.lifecycle'), [
        {'state': 'inactive', 'reply_running': true, 'away': 'none'},
        {'state': 'paused', 'reply_running': true, 'away': 'none'},
        {'state': 'resumed', 'reply_running': true, 'away': '30_120s'},
      ]);
    });

    test('the end of a reply carries the time it spent away', () async {
      await startTurn();
      chat.appLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 11));
      chat.appLifecycleChanged(AppLifecycleState.resumed);
      send.fail(const GatewayConnectionClosed());
      await pumpEventQueue();

      expect(ended().single['away'], 'over_600s');
    });

    test('a reply that ended while away still reports the return', () async {
      await startTurn();
      chat.appLifecycleChanged(AppLifecycleState.paused);
      send
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();
      now = now.add(const Duration(seconds: 10));
      chat.appLifecycleChanged(AppLifecycleState.resumed);

      expect(events.named('app.lifecycle').last, {
        'state': 'resumed',
        'reply_running': false,
        'away': '5_30s',
      });
    });
  });

  group('chat.reply.late_event', () {
    test(
      'a frame for a reply already failed is counted once per kind',
      () async {
        chat.newThread();
        thread = chat.selectedThread!;
        await chat.submit(_prompt, const []);
        send = transport.sends.single;
        send.emit(const ThreadBound('s1'));
        await pumpEventQueue();
        await lose(const GatewayConnectionClosed());
        expect(ended().single['outcome'], 'failed');

        chat.select('s1');
        await pumpEventQueue();
        now = now.add(const Duration(seconds: 7));
        transport.followUpStreams['s1']!
          ..emit(const ReplyDelta('late one'))
          ..emit(const ReplyDelta('late two'))
          ..emit(const ReplyCompleted('late'));
        await pumpEventQueue();

        expect(events.named('chat.reply.late_event'), [
          {'kind': 'delta', 'since_end': '5_20s'},
          {'kind': 'completed', 'since_end': '5_20s'},
        ]);
      },
    );

    test('a completed reply has no late frames', () async {
      await startTurn();
      send
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();
      chat.select('s1');
      await pumpEventQueue();
      transport.followUpStreams['s1']?.emit(const ReplyDelta('next turn'));
      await pumpEventQueue();

      expect(events.named('chat.reply.late_event'), isEmpty);
    });
  });

  group('privacy and robustness', () {
    test('no attribute carries what was typed, named or said', () async {
      await startTurn();
      await chat.submit('SENTINEL_QUEUED_91c2', const []);
      await pumpEventQueue();
      chat.appLifecycleChanged(AppLifecycleState.paused);
      await lose(StateError(_serverText));
      chat.appLifecycleChanged(AppLifecycleState.resumed);

      const names = {
        'chat.reply.ended',
        'chat.queue.state',
        'app.lifecycle',
        'chat.reply.late_event',
      };
      final fixed = {
        ...kReplyEndCauses,
        ...kReplyEndOutcomes,
        ...kReplyEndSteps,
        ...kAwayBuckets,
        ...kDurationBuckets,
        ...kCountBuckets,
        ...kQueueStates,
        ...kLateEventKinds,
        'paused',
        'resumed',
        'inactive',
        'none',
      };
      var seen = 0;
      for (final name in names) {
        for (final attributes in events.named(name)) {
          seen++;
          for (final entry in attributes.entries) {
            expect(entry.key, matches(RegExp(r'^[a-z_]+$')));
            final value = entry.value;
            if (value is String) {
              expect(fixed, contains(value), reason: '$name ${entry.key}');
            } else {
              expect(value, anyOf(isA<bool>(), isA<int>()));
            }
          }
        }
      }
      expect(seen, greaterThan(2));
    });

    test(
      'a logger that throws does not break the reply or resend it',
      () async {
        chat = build(log: (name, attributes) => throw StateError('exporter'));
        await startTurn();
        chat.appLifecycleChanged(AppLifecycleState.paused);
        chat.appLifecycleChanged(AppLifecycleState.resumed);
        send
          ..emit(const ReplyCompleted('Done.'))
          ..finish();
        await pumpEventQueue();

        expect(thread.isReplying, isFalse);
        expect(
          thread.messages.lastWhere((m) => m.role == ChatRole.assistant).status,
          MessageStatus.sent,
        );
        expect(transport.sends, hasLength(1));
      },
    );

    test('losing the connection never resends the prompt', () async {
      await startTurn();
      await lose();
      chat.checkConnection();
      await pumpEventQueue();
      chat.checkConnection();
      await pumpEventQueue();

      expect(transport.sends, hasLength(1));
    });
  });
}
