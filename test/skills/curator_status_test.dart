import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/action_status.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/skills/curator/curator_status.dart';

import 'curator_fixtures.dart';

void main() {
  group('CuratorStatus.parse', () {
    test('reads the recorded answer of a profile that never ran', () {
      final status = CuratorStatus.parse(recordedCuratorNeverRun)!;

      expect(status.enabled, isTrue);
      expect(status.paused, isFalse);
      expect(status.intervalHours, 168);
      expect(status.lastRun, CuratorLastRun.never);
      expect(status.lastRunAt, isNull);
      expect(status.minIdleHours, 2.0);
      expect(status.staleAfterDays, 14);
      expect(status.archiveAfterDays, 30);
    });

    test('reads a last run time with an offset as that instant in UTC', () {
      final status = CuratorStatus.parse(recordedCuratorRan)!;

      expect(status.lastRun, CuratorLastRun.at);
      expect(status.lastRunAt, DateTime.utc(2026, 11, 15, 3, 37, 52, 300, 226));
    });

    test('reads paused and off in config', () {
      expect(CuratorStatus.parse(recordedCuratorPaused)!.paused, isTrue);
      final off = CuratorStatus.parse(recordedCuratorDisabled)!;
      expect(off.enabled, isFalse);
      expect(off.isOn, isFalse);
    });

    test(
      'a time without an offset is read as UTC, whatever the device zone',
      () {
        expect(
          CuratorStatus.utcTimeText('2026-11-15T03:37:52'),
          '2026-11-15T03:37:52Z',
        );
        expect(
          CuratorStatus.utcTimeText('2026-11-15 03:37:52.5'),
          '2026-11-15 03:37:52.5Z',
        );
        for (final text in [
          '2026-11-15T03:37:52Z',
          '2026-11-15T03:37:52+02:00',
          '2026-11-15T03:37:52-0500',
          '2026-11-15T03:37:52+01',
        ]) {
          expect(CuratorStatus.utcTimeText(text), text, reason: text);
        }
        final status = CuratorStatus.parse({
          ...recordedCuratorNeverRun,
          'last_run_at': '2026-11-15T03:37:52',
        })!;
        expect(status.lastRunAt, DateTime.utc(2026, 11, 15, 3, 37, 52));
      },
    );

    test('a date without a time is unknown, not local midnight', () {
      expect(CuratorStatus.utcTimeText('2026-11-15'), isNull);
      expect(CuratorStatus.utcTimeText('2026-11-15T03'), isNull);
      final status = CuratorStatus.parse({
        ...recordedCuratorNeverRun,
        'last_run_at': '2026-11-15',
      })!;

      expect(status.lastRun, CuratorLastRun.unknown);
      expect(status.lastRunAt, isNull);
    });

    test('a count that is not a whole, sane number is unknown', () {
      final status = CuratorStatus.parse({
        ...recordedCuratorNeverRun,
        'interval_hours': 2.9,
        'stale_after_days': 1e300,
        'archive_after_days': 9007199254740993,
      })!;

      expect(status.intervalHours, isNull);
      expect(status.staleAfterDays, isNull);
      expect(status.archiveAfterDays, isNull);
    });

    test('a missing field is unknown and the rest is used', () {
      final status = CuratorStatus.parse({
        'paused': true,
        'stale_after_days': 7,
      })!;

      expect(status.paused, isTrue);
      expect(status.staleAfterDays, 7);
      expect(status.enabled, isNull);
      expect(status.isOn, isTrue, reason: 'enabled null counts as on');
      expect(status.intervalHours, isNull);
      expect(status.lastRun, CuratorLastRun.unknown);
      expect(status.lastRunAt, isNull);
      expect(status.minIdleHours, isNull);
      expect(status.archiveAfterDays, isNull);
    });

    test('an ill-typed field is unknown and the rest is used', () {
      final status = CuratorStatus.parse({
        'enabled': 'yes',
        'paused': 1,
        'interval_hours': 'weekly',
        'last_run_at': 12345,
        'min_idle_hours': 'soon',
        'stale_after_days': [14],
        'archive_after_days': 30,
      })!;

      expect(status.enabled, isNull);
      expect(status.paused, isNull);
      expect(status.intervalHours, isNull);
      expect(status.lastRun, CuratorLastRun.unknown);
      expect(status.minIdleHours, isNull);
      expect(status.staleAfterDays, isNull);
      expect(status.archiveAfterDays, 30);
    });

    test('a time that is not a time is unknown, not "never"', () {
      final status = CuratorStatus.parse({
        ...recordedCuratorNeverRun,
        'last_run_at': 'yesterday',
      })!;

      expect(status.lastRun, CuratorLastRun.unknown);
      expect(status.lastRunAt, isNull);
    });

    test('numbers that make no sense are unknown', () {
      final status = CuratorStatus.parse({
        ...recordedCuratorNeverRun,
        'interval_hours': 0,
        'min_idle_hours': -1,
        'stale_after_days': -3,
        'archive_after_days': double.nan,
      })!;

      expect(status.intervalHours, isNull);
      expect(status.minIdleHours, isNull);
      expect(status.staleAfterDays, isNull);
      expect(status.archiveAfterDays, isNull);
    });

    test('a whole number sent as a float is read as the number', () {
      final status = CuratorStatus.parse({
        ...recordedCuratorNeverRun,
        'interval_hours': 24.0,
      })!;

      expect(status.intervalHours, 24);
    });

    test('something that is not an object is not a status', () {
      for (final json in <Object?>[null, 'text', 12, true, <Object?>[]]) {
        expect(CuratorStatus.parse(json), isNull, reason: '$json');
      }
    });

    test('an empty object is a status of unknowns', () {
      final status = CuratorStatus.parse(<String, Object?>{})!;

      expect(status.enabled, isNull);
      expect(status.paused, isNull);
      expect(status.lastRun, CuratorLastRun.unknown);
    });

    test('truncated input never throws', () {
      final text = jsonEncode(recordedCuratorRan);
      for (var end = 0; end <= text.length; end++) {
        Object? decoded;
        try {
          decoded = jsonDecode(text.substring(0, end));
        } on FormatException {
          decoded = text.substring(0, end);
        }
        expect(() => CuratorStatus.parse(decoded), returnsNormally);
      }
    });
  });

  group('the curator-run action', () {
    test('is a server-care action with the route name Hermes uses', () {
      expect(CareAction.curatorRun.routeName, 'curator-run');
    });

    test('reads through the shared ActionStatus: header, lines, exit', () {
      final status = ActionStatus.parse(recordedStatusArchived)!;

      expect(status.running, isFalse);
      expect(status.exitCode, 0);
      expect(
        status.startHeader,
        '=== curator-run started 2026-11-15 03:37:50 ===',
      );
      expect(status.lines.first, 'curator: running review pass...');
      expect(status.lines.last, contains('archived=1'));
    });

    test('a running pass has the header and no lines', () {
      final status = ActionStatus.parse(recordedStatusRunning)!;

      expect(status.running, isTrue);
      expect(status.exitCode, isNull);
      expect(status.startHeader, recordedRunHeader);
      expect(status.lines, isEmpty);
    });

    test('a disabled pass exits 1 with the one line Hermes prints', () {
      final status = ActionStatus.parse(recordedStatusDisabled)!;

      expect(status.exitCode, 1);
      expect(status.lines, [
        'curator: disabled via config; enable with `curator.enabled: true`',
      ]);
    });

    test('after a restart there is no exit code and the lines are kept', () {
      final status = ActionStatus.parse(recordedStatusAfterRestart)!;

      expect(status.running, isFalse);
      expect(status.exitCode, isNull);
      expect(status.lines, isNotEmpty);
    });
  });
}
