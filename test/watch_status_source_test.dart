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
    });
  });
}
