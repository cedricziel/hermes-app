import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/widgets/blank_list_watchdog.dart';

void main() {
  test('a painting list never trips the watchdog', () {
    final watchdog = BlankListWatchdog();

    for (var step = 0; step < 100; step++) {
      watchdog.onItemBuilt();
      expect(watchdog.onFollowingStep(), isFalse);
    }
  });

  test('an empty list never arms the watchdog', () {
    final watchdog = BlankListWatchdog();

    for (var step = 0; step < 100; step++) {
      expect(watchdog.onFollowingStep(), isFalse);
    }
  });

  test('churned steps without item builds trip it exactly once', () {
    final watchdog = BlankListWatchdog();
    watchdog.onItemBuilt();

    var fired = false;
    for (var step = 1; step < 8; step++) {
      expect(watchdog.onFollowingStep(), isFalse, reason: 'step $step');
    }
    fired = watchdog.onFollowingStep();
    expect(fired, isTrue);
    // The eighth churn step after recovery starts a new count, not a fire.
    expect(watchdog.onFollowingStep(), isFalse);
  });

  test('recoveries are spaced by the cooldown', () {
    var now = DateTime(2026, 10, 5);
    final watchdog = BlankListWatchdog(
      cooldown: const Duration(seconds: 10),
      now: () => now,
    );

    watchdog.onItemBuilt();
    for (var i = 0; i < 8; i++) {
      watchdog.onFollowingStep();
    }
    expect(watchdog.onFollowingStep(), isTrue, reason: 'first incident fires');

    // Inside the cooldown a second blank stretch stays silent.
    now = now.add(const Duration(seconds: 5));
    for (var i = 0; i < 9; i++) {
      expect(watchdog.onFollowingStep(), isFalse);
    }

    // Past the cooldown it fires again.
    now = now.add(const Duration(seconds: 6));
    for (var i = 0; i < 8; i++) {
      watchdog.onFollowingStep();
    }
    expect(watchdog.onFollowingStep(), isTrue);
  });

  test('disarm pauses counting; a resumed paint re-arms from zero', () {
    final watchdog = BlankListWatchdog();
    watchdog.onItemBuilt();

    for (var i = 0; i < 5; i++) {
      watchdog.onFollowingStep();
    }
    watchdog.disarm();
    for (var i = 0; i < 5; i++) {
      expect(watchdog.onFollowingStep(), isFalse);
    }

    // The list paints again: counting restarts from zero, and it takes the
    // full quiet stretch from here before firing.
    watchdog.onItemBuilt();
    for (var i = 0; i < 7; i++) {
      expect(watchdog.onFollowingStep(), isFalse);
    }
    expect(watchdog.onFollowingStep(), isTrue);
  });
}
