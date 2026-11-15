import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/resumable_sleep.dart';

void main() {
  late bool covered;
  late List<Completer<void>> timers;

  /// A delay that never fires by itself: the suspended app's timer.
  Future<void> suspended(Duration d) {
    final timer = Completer<void>();
    timers.add(timer);
    return timer.future;
  }

  ResumableSleep make() => ResumableSleep(suspended, covered: () => covered);

  setUp(() {
    covered = false;
    timers = [];
  });

  /// Lets the pending microtasks run.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('resumed ends a pending sleep', () async {
    final pause = make();
    var done = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    await flush();
    expect(done, 0);
    pause.resumed();
    await flush();
    expect(done, 1);
  });

  test('a resume under cover is owed and wakes once on unlock', () async {
    final pause = make();
    var done = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    covered = true;
    pause.resumed();
    await flush();
    expect(done, 0);
    covered = false;
    pause.unlocked();
    await flush();
    expect(done, 1);

    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    pause.unlocked();
    await flush();
    expect(done, 1, reason: 'the owed wake was spent');
  });

  test('a resume once uncovered clears what was owed', () async {
    final pause = make();
    covered = true;
    pause.resumed();
    covered = false;
    pause.resumed();

    var done = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    pause.unlocked();
    await flush();
    expect(done, 0, reason: 'nothing is owed any more');
  });

  test('unlocked without an owed resume does nothing', () async {
    final pause = make();
    var done = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    pause.unlocked();
    await flush();
    expect(done, 0);
  });

  test('a finished sleep does not clear a later sleep\'s wake', () async {
    final pause = make();
    var first = 0;
    var second = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => first++));
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => second++));
    // The earlier sleep ends by its timer while the later one still waits.
    timers.first.complete();
    await flush();
    expect(first, 1);
    expect(second, 0);
    pause.resumed();
    await flush();
    expect(second, 1);
  });

  test('release ends only a pending sleep', () async {
    final pause = make();
    pause.release();
    var done = 0;
    unawaited(pause.sleep(const Duration(seconds: 5)).then((_) => done++));
    await flush();
    expect(done, 0, reason: 'an earlier release does not touch a new sleep');
    pause.release();
    await flush();
    expect(done, 1);
  });
}
