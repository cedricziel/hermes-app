import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_replay.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

GatewayEvent _event(String sid, int? seq, {String type = 'message.delta'}) {
  return GatewayEvent(type: type, sessionId: sid, payload: const {}, seq: seq);
}

Map<String, Object?> _replayElement(String sid, int seq) => {
  'type': 'message.delta',
  'session_id': sid,
  'payload': {'text': '$seq'},
  'seq': seq,
};

Map<String, Object?> _result({
  required List<Object?> events,
  bool truncated = false,
  String? epoch,
  int latestSeq = 0,
}) => {
  'events': events,
  'latest_seq': latestSeq,
  'truncated': truncated,
  'count': events.length,
  'epoch': ?epoch,
};

/// A [Random] whose [nextDouble] always returns [value], so the jitter is
/// fixed and the delay bound is what the test checks.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

List<int> _seqs(ReplayDecision decision) {
  return switch (decision) {
    Deliver(:final events) => [for (final e in events) e.seq!],
    Refetch() => throw StateError('expected Deliver, got Refetch'),
  };
}

void main() {
  group('5.1 ReplayLedger', () {
    test('observe delivers a seq above the watermark and raises it', () {
      final ledger = ReplayLedger();
      expect(ledger.observe('s', 1), isTrue);
      expect(ledger.lastSeen('s'), 1);
      expect(ledger.observe('s', 2), isTrue);
      expect(ledger.lastSeen('s'), 2);
    });

    test('observe drops a seq at or below the watermark', () {
      final ledger = ReplayLedger();
      ledger.observe('s', 7);
      expect(ledger.observe('s', 7), isFalse);
      expect(ledger.observe('s', 3), isFalse);
      expect(ledger.lastSeen('s'), 7);
    });

    test('observe with a null seq always delivers and keeps the watermark', () {
      final ledger = ReplayLedger();
      ledger.observe('s', 4);
      expect(ledger.observe('s', null), isTrue);
      expect(ledger.observe('s', null), isTrue);
      expect(ledger.lastSeen('s'), 4);
    });

    test('lastSeen is 0 for a session never observed', () {
      final ledger = ReplayLedger();
      expect(ledger.lastSeen('unknown'), 0);
    });

    test('watermarks are kept per runtime session', () {
      final ledger = ReplayLedger();
      ledger.observe('a', 9);
      expect(ledger.observe('b', 1), isTrue);
      expect(ledger.lastSeen('a'), 9);
      expect(ledger.lastSeen('b'), 1);
    });
  });

  group('5.2 ReplayLedger.merge', () {
    test('replay 8-12 then parked 11-13 after watermark 7 delivers 8 to 13 once each', () {
      final ledger = ReplayLedger()..observe('s', 7);
      final decision = ledger.merge(
        sid: 's',
        result: _result(
          events: [for (var i = 8; i <= 12; i++) _replayElement('s', i)],
          latestSeq: 12,
        ),
        parked: [for (var i = 11; i <= 13; i++) _event('s', i)],
      );
      expect(_seqs(decision), [8, 9, 10, 11, 12, 13]);
      expect(ledger.lastSeen('s'), 13);
    });

    test('a replay element becomes a GatewayEvent with its type, session, payload and seq', () {
      final ledger = ReplayLedger();
      final decision = ledger.merge(
        sid: 's',
        result: _result(
          events: [
            {
              'type': 'tool.start',
              'session_id': 's',
              'payload': {'name': 'shell'},
              'seq': 1,
            },
          ],
        ),
        parked: const [],
      );
      final events = (decision as Deliver).events;
      expect(events, hasLength(1));
      expect(events.single.type, 'tool.start');
      expect(events.single.sessionId, 's');
      expect(events.single.payload, {'name': 'shell'});
      expect(events.single.seq, 1);
    });

    test('merge with truncated true returns Refetch and leaves the watermark unchanged', () {
      final ledger = ReplayLedger()..observe('s', 7);
      final decision = ledger.merge(
        sid: 's',
        result: _result(
          events: [_replayElement('s', 8)],
          truncated: true,
          latestSeq: 50,
        ),
        parked: const [],
      );
      expect(decision, isA<Refetch>());
      expect(ledger.lastSeen('s'), 7);
    });

    test('parked events still pass observe after a truncated Refetch', () {
      final ledger = ReplayLedger()..observe('s', 7);
      ledger.merge(
        sid: 's',
        result: _result(events: const [], truncated: true, latestSeq: 50),
        parked: const [],
      );
      final decision = ledger.merge(
        sid: 's',
        result: _result(events: const []),
        parked: [_event('s', 8), _event('s', 9)],
      );
      expect(_seqs(decision), [8, 9]);
    });

    test('a truncated Refetch does not jump the watermark to latest_seq', () {
      final ledger = ReplayLedger()..observe('s', 7);
      ledger.merge(
        sid: 's',
        result: _result(events: const [], truncated: true, latestSeq: 50),
        parked: const [],
      );
      expect(ledger.lastSeen('s'), isNot(50));
      expect(ledger.lastSeen('s'), 7);
    });

    test('an answer from another epoch than the watermark was recorded at returns Refetch and clears every watermark', () {
      final ledger = ReplayLedger()
        ..observe('a', 5, epoch: 'old')
        ..observe('b', 9, epoch: 'old');
      final decision = ledger.merge(
        sid: 'a',
        result: _result(events: [_replayElement('a', 6)], epoch: 'new'),
        parked: const [],
      );
      expect(decision, isA<Refetch>());
      expect(ledger.lastSeen('a'), 0);
      expect(ledger.lastSeen('b'), 0);
      expect(ledger.epochOf('a'), isNull);
    });

    test(
      'an epoch mismatch clears only the sessions recorded at another epoch',
      () {
        final ledger = ReplayLedger()
          ..observe('a', 5, epoch: 'old')
          ..observe('b', 9, epoch: 'new');
        final decision = ledger.merge(
          sid: 'a',
          result: _result(events: const [], epoch: 'new'),
          parked: const [],
        );
        expect(decision, isA<Refetch>());
        expect(ledger.lastSeen('a'), 0);
        expect(ledger.lastSeen('b'), 9);
      },
    );

    test('observe drops a watermark recorded at another epoch', () {
      final ledger = ReplayLedger()..observe('s', 9, epoch: 'old');
      expect(ledger.observe('s', 1, epoch: 'new'), isTrue);
      expect(ledger.lastSeen('s'), 1);
      expect(ledger.epochOf('s'), 'new');
    });

    test(
      'resumeFrom is 0 for a connection at another epoch than the watermark',
      () {
        final ledger = ReplayLedger()..observe('s', 9, epoch: 'old');
        expect(ledger.resumeFrom('s', 'new'), 0);
        expect(ledger.resumeFrom('s', 'old'), 9);
        expect(ledger.resumeFrom('s', null), 9);
      },
    );

    test('a matching epoch is not a mismatch', () {
      final ledger = ReplayLedger()..observe('s', 1, epoch: 'same');
      final decision = ledger.merge(
        sid: 's',
        result: _result(events: [_replayElement('s', 2)], epoch: 'same'),
        parked: const [],
      );
      expect(_seqs(decision), [2]);
      expect(ledger.epochOf('s'), 'same');
    });

    test('an epoch is ignored when the watermark has none recorded or the answer has none', () {
      final unrecorded = ReplayLedger()..observe('s', 1);
      final fromResult = unrecorded.merge(
        sid: 's',
        result: _result(events: [_replayElement('s', 2)], epoch: 'e'),
        parked: const [],
      );
      expect(_seqs(fromResult), [2]);
      expect(unrecorded.epochOf('s'), 'e');

      final recorded = ReplayLedger()..observe('s', 1, epoch: 'e');
      final fromConnection = recorded.merge(
        sid: 's',
        result: _result(events: [_replayElement('s', 2)]),
        parked: const [],
      );
      expect(_seqs(fromConnection), [2]);
    });

    test('hasWatermark is true only once an event with a seq was observed', () {
      final ledger = ReplayLedger();
      expect(ledger.hasWatermark('s'), isFalse);
      ledger.observe('s', null);
      expect(ledger.hasWatermark('s'), isFalse);
      ledger.observe('s', 3);
      expect(ledger.hasWatermark('s'), isTrue);
    });

    test('parked events of another session are not delivered to this one', () {
      final ledger = ReplayLedger();
      final decision = ledger.merge(
        sid: 's',
        result: _result(events: const []),
        parked: [_event('other', 1), _event('s', 1)],
      );
      expect(_seqs(decision), [1]);
      expect(ledger.lastSeen('other'), 0);
    });

    test('malformed replay elements are skipped', () {
      final ledger = ReplayLedger();
      final decision = ledger.merge(
        sid: 's',
        result: _result(
          events: [
            'not a map',
            42,
            {'payload': {}, 'seq': 1},
            _replayElement('s', 1),
          ],
        ),
        parked: const [],
      );
      expect(_seqs(decision), [1]);
    });
  });

  group('5.3 reconnectDelay', () {
    const cap = Duration(seconds: 15);
    const base = Duration(milliseconds: 300);
    final top = _FixedRandom(0.999999);

    test('attempt 0 waits at most the 300 ms base', () {
      final delay = reconnectDelay(0, top);
      expect(delay, lessThanOrEqualTo(base));
      expect(delay, greaterThan(Duration.zero));
    });

    test('attempt 6 is capped at 15 s', () {
      final delay = reconnectDelay(6, top);
      expect(delay, lessThanOrEqualTo(cap));
      expect(delay, greaterThan(const Duration(seconds: 14)));
    });

    test('attempt 20 is capped at 15 s', () {
      expect(reconnectDelay(20, top), lessThanOrEqualTo(cap));
    });

    test('the bound doubles with each attempt before the cap', () {
      expect(
        reconnectDelay(1, top),
        lessThanOrEqualTo(const Duration(milliseconds: 600)),
      );
      expect(
        reconnectDelay(2, top),
        lessThanOrEqualTo(const Duration(milliseconds: 1200)),
      );
    });

    test('full jitter scales the bound by the random fraction', () {
      expect(
        reconnectDelay(0, _FixedRandom(0.5)),
        const Duration(milliseconds: 150),
      );
    });
  });

  group('5.4 settles', () {
    final submittedAt = DateTime.utc(2026, 10, 7, 12);

    test('a started turn settles', () {
      expect(
        settles(started: true, submittedAt: submittedAt, now: submittedAt),
        isTrue,
      );
    });

    test('a turn not started within 15 s of submit does not settle', () {
      expect(
        settles(
          started: false,
          submittedAt: submittedAt,
          now: submittedAt.add(const Duration(seconds: 14, milliseconds: 999)),
        ),
        isFalse,
      );
    });

    test('a turn not started after 15 s of submit settles', () {
      expect(
        settles(
          started: false,
          submittedAt: submittedAt,
          now: submittedAt.add(const Duration(seconds: 15)),
        ),
        isTrue,
      );
    });
  });
}
