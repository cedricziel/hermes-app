import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/watch/watch_status_source.dart';

class _Transport implements ChatTransport {
  final reads = <Completer<Map<String, String>>>[];
  bool closed = false;

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) {
    final read = Completer<Map<String, String>>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const budget = Duration(milliseconds: 50);
  const idle = Duration(milliseconds: 100);

  test('a timed-out read leaves the next transport on its idle close', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      }, idleTimeout: idle);
      Object? error;
      source
          .activeStatuses(budget: budget)
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.elapse(budget + const Duration(milliseconds: 1));
      expect(error, isA<TimeoutException>());
      expect(transports[0].closed, isTrue);

      Map<String, String>? got;
      unawaited(source.activeStatuses(budget: budget).then((v) => got = v));
      transports[1].reads.single.complete({'a': 'running'});
      async.flushMicrotasks();
      expect(got, {'a': 'running'});
      expect(transports[1].closed, isFalse);
      // The first read is still pending when the idle timer should fire.
      expect(transports[0].reads.single.isCompleted, isFalse);
      async.elapse(idle + const Duration(milliseconds: 1));
      expect(transports[1].closed, isTrue);
    });
  });

  test('a timed-out read does not close a newer transport', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      }, idleTimeout: const Duration(minutes: 5));
      void read(Map<String, String>? Function(Map<String, String>?) sink) =>
          unawaited(
            source
                .activeStatuses(budget: budget)
                .then((v) => sink(v), onError: (Object _) {}),
          );
      read((v) => v); // A, times out at 50 ms and closes the first transport.
      async.elapse(const Duration(milliseconds: 30));
      read((v) => v); // B, shares the first transport, times out at 80 ms.
      async.elapse(const Duration(milliseconds: 30));
      expect(transports[0].closed, isTrue);
      Map<String, String>? got;
      unawaited(source.activeStatuses(budget: budget).then((v) => got = v));
      expect(transports, hasLength(2));
      async.elapse(const Duration(milliseconds: 25)); // B's budget passes.
      expect(transports[1].closed, isFalse);
      transports[1].reads.single.complete({'c': 'running'});
      async.flushMicrotasks();
      expect(got, {'c': 'running'});
      // One more read reuses the newer transport.
      unawaited(source.activeStatuses(budget: budget).then((_) {}));
      expect(transports, hasLength(2));
      expect(transports[1].reads, hasLength(2));
      transports[1].reads.last.complete({});
      async.elapse(const Duration(minutes: 5, milliseconds: 1));
      expect(transports[1].closed, isTrue);
      // After that, a new read opens a third transport and close() ends it.
      unawaited(source.activeStatuses(budget: budget).then((_) {}));
      expect(transports, hasLength(3));
      unawaited(source.close());
      async.flushMicrotasks();
      expect(transports[2].closed, isTrue);
    });
  });

  test('a read finishing on a released transport does not arm the idle '
      'close under a newer one', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      }, idleTimeout: idle);
      const long = Duration(milliseconds: 500);
      unawaited(
        source.activeStatuses(budget: budget).then((_) {}, onError: (_) {}),
      ); // A: times out at 50 ms and releases the first transport.
      async.elapse(const Duration(milliseconds: 30));
      unawaited(
        source.activeStatuses(budget: long).then((_) {}, onError: (_) {}),
      ); // B: on the first transport, still pending after A released it.
      async.elapse(const Duration(milliseconds: 30));
      expect(transports[0].closed, isTrue);
      unawaited(
        source.activeStatuses(budget: long).then((_) {}, onError: (_) {}),
      ); // C: on the second transport, in flight.
      expect(transports, hasLength(2));
      transports[0].reads.last.complete({}); // B ends on the released one.
      async.elapse(idle * 2);
      expect(transports[1].closed, isFalse);
    });
  });

  test('a read after dispose connects nothing', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      });
      unawaited(source.activeStatuses().then((_) {}));
      expect(transports, hasLength(1));
      unawaited(source.dispose());
      async.flushMicrotasks();
      expect(transports.single.closed, isTrue);
      Map<String, String>? got = {'x': 'y'};
      unawaited(source.activeStatuses().then((v) => got = v));
      async.flushMicrotasks();
      expect(got, isNull);
      expect(transports, hasLength(1));
    });
  });

  test('a read still pending on a released transport does not stop the '
      'newer one from closing when idle', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      }, idleTimeout: idle);
      const long = Duration(milliseconds: 500);
      unawaited(
        source.activeStatuses(budget: budget).then((_) {}, onError: (_) {}),
      ); // A on X: times out at 50 ms and releases X.
      async.elapse(const Duration(milliseconds: 30));
      unawaited(
        source.activeStatuses(budget: long).then((_) {}, onError: (_) {}),
      ); // B on X: still pending.
      async.elapse(const Duration(milliseconds: 30));
      unawaited(source.activeStatuses(budget: long).then((_) {}));
      expect(transports, hasLength(2)); // C on Y.
      transports[1].reads.single.complete({});
      async.flushMicrotasks();
      transports[0].reads.last.complete({}); // B ends on X.
      async.flushMicrotasks();
      async.elapse(idle + const Duration(milliseconds: 1));
      expect(transports[1].closed, isTrue);
    });
  });

  test('reads spaced under the idle timeout keep one transport open', () {
    fakeAsync((async) {
      final transports = <_Transport>[];
      final source = WatchStatusSource(() {
        final t = _Transport();
        transports.add(t);
        return t;
      }, idleTimeout: idle);
      for (var i = 0; i < 5; i++) {
        unawaited(source.activeStatuses().then((_) {}));
        transports.last.reads.last.complete({});
        async.elapse(const Duration(milliseconds: 60));
      }
      expect(transports, hasLength(1));
      expect(transports.single.closed, isFalse);
    });
  });

  test(
    'close() cancels the idle timer so it cannot close a newer transport',
    () {
      fakeAsync((async) {
        final transports = <_Transport>[];
        final source = WatchStatusSource(() {
          final t = _Transport();
          transports.add(t);
          return t;
        }, idleTimeout: idle);
        unawaited(source.activeStatuses().then((_) {}));
        transports[0].reads.single.complete({}); // arms the idle timer at 0 ms
        async.elapse(const Duration(milliseconds: 10));
        unawaited(source.close()); // as invalidateSession does
        async.elapse(const Duration(milliseconds: 10));
        unawaited(source.activeStatuses().then((_) {}));
        expect(transports, hasLength(2));
        transports[1].reads.single.complete({}); // arms its own timer at 20 ms
        // Past the first timer's deadline (100 ms), before the new one's (120).
        async.elapse(const Duration(milliseconds: 90));
        expect(transports[1].closed, isFalse);
      });
    },
  );
}
