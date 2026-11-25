import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/ticket_mint_gate.dart';

import '../support/fake_hermes_server.dart';

/// A [Random] that always draws [value].
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor();
}

DioException _answered(int status) {
  final options = RequestOptions(path: '/api/auth/ws-ticket');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<Object?>(requestOptions: options, statusCode: status),
  );
}

DioException _cancelled() => DioException(
  requestOptions: RequestOptions(path: '/api/auth/ws-ticket'),
  type: DioExceptionType.cancel,
);

DioException _unreachable() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/api/auth/ws-ticket'),
  reason: 'down',
);

void main() {
  late TicketMintGate gate;
  late int mints;
  late DioException? failure;

  /// One mint through the gate, true when it went out and false when the gate
  /// refused it without calling the server.
  Future<bool> mint() async {
    try {
      await gate.run(() async {
        mints++;
        final error = failure;
        if (error != null) throw error;
        return 'ticket';
      });
      return true;
    } on GatewayCredentialBackedOff {
      return false;
    } on DioException {
      return true;
    }
  }

  var epoch = 0;
  var ended = false;

  void fake(void Function(FakeAsync async) body, {double draw = 0.999999}) =>
      fakeAsync((async) {
        mints = 0;
        epoch = 0;
        ended = false;
        failure = null;
        gate = TicketMintGate(
          random: _FixedRandom(draw),
          sessionEpoch: () => epoch,
          sessionEnded: () => ended,
        );
        body(async);
      });

  group('after the server refused the credential (401 or 403)', () {
    test('no ticket is minted while the cooldown runs, so a loop that asks '
        'every few seconds reaches the server once', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();

        // A reconnecting socket and two pollers, every 5 s for 20 s.
        for (var i = 0; i < 4; i++) {
          async.elapse(const Duration(seconds: 5));
          unawaited(mint());
          unawaited(mint());
          unawaited(mint());
          async.flushMicrotasks();
        }

        expect(mints, 1);
      });
    });

    test('the wait doubles with every refusal up to the cap, with jitter', () {
      fake((async) {
        failure = _answered(401);
        final waits = <Duration>[];
        for (var i = 0; i < 9; i++) {
          unawaited(mint());
          async.flushMicrotasks();
          final before = mints;
          // The shortest wait after which a mint goes out again.
          var waited = Duration.zero;
          while (mints == before && waited < const Duration(minutes: 11)) {
            async.elapse(const Duration(seconds: 1));
            waited += const Duration(seconds: 1);
            unawaited(mint());
            async.flushMicrotasks();
          }
          waits.add(waited);
        }

        // A draw just under 1 is just under the bound: 30 s, 60 s, ... 10 min.
        expect(
          waits,
          [
            30,
            60,
            120,
            240,
            480,
            600,
            600,
            600,
            600,
          ].map((s) => Duration(seconds: s)).toList(),
        );
      });
    });

    test('the wait is drawn between half the bound and the bound, so clients '
        'that failed together do not come back together, and none comes back '
        'at once', () {
      for (final (draw, mintsAfter14, mintsAfter23) in [
        // A draw of 0 waits 15 s of the 30 s bound; of a half, 22.5 s.
        (0.0, 2, 2),
        (0.5, 1, 2),
      ]) {
        fake((async) {
          failure = _answered(401);
          unawaited(mint());
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 16));
          unawaited(mint());
          async.flushMicrotasks();
          expect(mints, mintsAfter14, reason: 'at 16 s, draw $draw');

          async.elapse(const Duration(seconds: 7));
          unawaited(mint());
          async.flushMicrotasks();
          expect(mints, mintsAfter23, reason: 'at 23 s, draw $draw');
        }, draw: draw);
      }
    });

    test('a 403 is a refusal too', () {
      fake((async) {
        failure = _answered(403);
        unawaited(mint());
        async.flushMicrotasks();
        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 1);
      });
    });

    test('a mint that works again ends the cooldown and the growth', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 31));
        failure = null;
        unawaited(mint());
        async.flushMicrotasks();
        expect(mints, 2);

        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();
        // Back at the first step, not the third.
        async.elapse(const Duration(seconds: 31));
        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 4);
      });
    });

    test('concurrent refusals count once, so two answers that land together '
        'do not double the wait', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        unawaited(mint());
        unawaited(mint());
        async.flushMicrotasks();
        expect(mints, 3);

        async.elapse(const Duration(seconds: 31));
        unawaited(mint());
        async.flushMicrotasks();

        // One failure was counted: the wait was 30 s, not 120 s.
        expect(mints, 4);
      });
    });

    test('the refusal the gate repeats is the backed-off one, not a new '
        'request', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();

        Object? thrown;
        unawaited(
          gate
              .run(() async => 'never')
              .then<void>(
                (_) {},
                onError: (Object e) {
                  thrown = e;
                },
              ),
        );
        async.flushMicrotasks();

        expect(thrown, isA<GatewayCredentialBackedOff>());
        expect(mints, 1);
      });
    });
  });

  group('a wait never outlives its session', () {
    test('a refusal that ended the session leaves no wait, so the next '
        'sign-in mints at once', () {
      fake((async) {
        failure = _answered(401);
        ended = true;
        unawaited(mint());
        async.flushMicrotasks();

        ended = false;
        failure = null;
        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 2);
      });
    });

    test('a refusal that renewed the credential during the request still '
        'starts a wait, which lasts under the new one', () {
      fake((async) {
        failure = _answered(401);
        // A window's client is handed a new header while its request is
        // retried: the 401 is the server's answer to the new one.
        final refused = gate.run(() async {
          mints++;
          epoch++;
          throw failure!;
        });
        unawaited(refused.then<void>((_) {}, onError: (Object _) {}));
        async.flushMicrotasks();

        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 1);
      });
    });

    test('a renewed access token ends a wait too, so a refusal after a lost '
        'refresh does not outlast the session that works again', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();
        unawaited(mint());
        async.flushMicrotasks();
        expect(mints, 1);

        // The epoch of the real client carries the token: a new one differs.
        epoch++;
        failure = null;
        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 2);
      });
    });

    test('a wait that began under an earlier session is over once the epoch '
        'changed', () {
      fake((async) {
        failure = _answered(401);
        unawaited(mint());
        async.flushMicrotasks();
        unawaited(mint());
        async.flushMicrotasks();
        expect(mints, 1, reason: 'waiting');

        epoch++;
        unawaited(mint());
        async.flushMicrotasks();

        expect(mints, 2);
      });
    });
  });

  group('after another answer of the server (a restart, an overload)', () {
    test(
      'the first wait is shorter than a caller\'s own retry after 500 ms',
      () {
        fake((async) {
          failure = _answered(503);
          unawaited(mint());
          async.flushMicrotasks();

          async.elapse(const Duration(milliseconds: 500));
          unawaited(mint());
          async.flushMicrotasks();

          expect(mints, 2);
        });
      },
    );

    test('the wait doubles, to a minute at most', () {
      fake((async) {
        failure = _answered(503);
        final left = <Duration>[];
        for (var i = 0; i < 10; i++) {
          unawaited(mint());
          async.flushMicrotasks();
          unawaited(
            gate
                .run(() async => 'never')
                .then<void>(
                  (_) {},
                  onError: (e) {
                    left.add((e as GatewayCredentialBackedOff).retryAfter);
                  },
                ),
          );
          async.flushMicrotasks();
          // Let the wait run out before the next failure.
          async.elapse(const Duration(minutes: 2));
        }

        // A draw just under 1 is just under the bound.
        expect(
          [for (final d in left) (d.inMilliseconds / 100).round()],
          [3, 6, 12, 24, 48, 96, 192, 384, 600, 600],
        );
      });
    });
  });

  group('what never reached the server does not count', () {
    test('a cancelled request (the session ended or the app is locked) and '
        'an unreachable server leave the gate open', () {
      fake((async) {
        for (final error in [_cancelled(), _unreachable()]) {
          failure = error;
          unawaited(mint());
          unawaited(mint());
          async.flushMicrotasks();
        }

        expect(mints, 4);
      });
    });
  });

  group('isCredentialRefusal', () {
    test('is a 401 or 403 answer, the gate backing off, never a cancel', () {
      expect(isCredentialRefusal(_answered(401)), isTrue);
      expect(isCredentialRefusal(_answered(403)), isTrue);
      expect(
        isCredentialRefusal(
          const GatewayCredentialBackedOff(
            refused: true,
            retryAfter: Duration(seconds: 1),
          ),
        ),
        isTrue,
      );
      expect(
        isCredentialRefusal(
          const GatewayCredentialBackedOff(
            refused: false,
            retryAfter: Duration(seconds: 1),
          ),
        ),
        isFalse,
      );
      expect(isCredentialRefusal(_answered(503)), isFalse);
      expect(isCredentialRefusal(_unreachable()), isFalse);
      expect(isCredentialRefusal(_cancelled()), isFalse);
      expect(isCredentialRefusal(null), isFalse);
    });

    test('a cancelled request is a stop of its own', () {
      expect(isCredentialStop(_cancelled()), isTrue);
      expect(isCredentialStop(_answered(401)), isTrue);
      expect(isCredentialStop(_answered(503)), isFalse);
      expect(isCredentialStop(_unreachable()), isFalse);
    });
  });

  group('one gate per client', () {
    test(
      'every socket of one client shares it, another client has its own',
      () {
        final server = FakeHermesServer();
        final one = server.client();

        expect(TicketMintGate.of(one), same(TicketMintGate.of(one)));
        expect(
          TicketMintGate.of(one),
          isNot(same(TicketMintGate.of(server.client()))),
        );
      },
    );
  });
}
