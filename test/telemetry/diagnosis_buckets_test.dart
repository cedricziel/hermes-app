import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/reply_diagnostics.dart';
import 'package:hermes_app/src/telemetry/diagnosis_buckets.dart';

import '../support/recorded_events.dart';

void main() {
  group('buckets', () {
    test('away', () {
      expect(awayBucket(const Duration(seconds: 4)), 'under_5s');
      expect(awayBucket(const Duration(seconds: 5)), '5_30s');
      expect(awayBucket(const Duration(seconds: 30)), '30_120s');
      expect(awayBucket(const Duration(seconds: 120)), '120_600s');
      expect(awayBucket(const Duration(seconds: 600)), 'over_600s');
    });

    test('duration', () {
      expect(durationBucket(const Duration(milliseconds: 999)), 'under_1s');
      expect(durationBucket(const Duration(seconds: 1)), '1_5s');
      expect(durationBucket(const Duration(seconds: 5)), '5_20s');
      expect(durationBucket(const Duration(seconds: 20)), '20_60s');
      expect(durationBucket(const Duration(seconds: 60)), 'over_60s');
    });

    test('count', () {
      expect(
        [for (var i = 0; i < 6; i++) countBucket(i)],
        ['0', '1', '2_3', '2_3', '4_plus', '4_plus'],
      );
    });

    test('close code', () {
      expect(closeCodeBucket(null), 'none');
      expect(closeCodeBucket(1000), 'normal');
      expect(closeCodeBucket(1001), 'going_away');
      expect(closeCodeBucket(1006), 'abnormal');
      expect(closeCodeBucket(1008), 'policy');
      expect(closeCodeBucket(1011), 'server_error');
      expect(closeCodeBucket(4009), 'app_busy');
      expect(closeCodeBucket(4001), 'app_other');
      expect(closeCodeBucket(3000), 'other');
      for (final code in [null, 1000, 1001, 1006, 1008, 1011, 4009, 4001, 77]) {
        expect(kCloseCodeBuckets, contains(closeCodeBucket(code)));
      }
    });
  });

  group('ReplyDiagnostics', () {
    test('an abandoned queue is logged with a count bucket only', () {
      final events = RecordedEvents();
      final diag = ReplyDiagnostics(events: events.call);
      final thread = Object();
      diag.queue(thread, 'abandoned', 5);
      diag.queue(thread, 'abandoned', 5);

      expect(events.named('chat.queue.state'), [
        {'state': 'abandoned', 'count': '4_plus'},
      ]);
    });

    test('a throwing logger never reaches the caller', () {
      final diag = ReplyDiagnostics(
        events: (name, [attributes = const {}]) => throw StateError('down'),
      );
      final thread = Object();
      final run = diag.begin(thread);
      diag.lifecycle(AppLifecycleState.paused, replyRunning: true);
      diag.ended(
        thread,
        run,
        outcome: 'failed',
        error: null,
        stopped: false,
        queued: 0,
      );
      diag.follow(thread, const ReplyCompleted('x'));
      diag.queue(thread, 'paused', 1);
    });
  });
}
