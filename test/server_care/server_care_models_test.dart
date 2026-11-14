import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/action_status.dart';
import 'package:hermes_app/src/server_care/attention.dart';
import 'package:hermes_app/src/server_care/doctor_report.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/server_status.dart';
import 'package:hermes_app/src/server_care/update_check.dart';
import 'package:hermes_app/src/server_care/update_receipt.dart';
import 'package:hermes_app/src/server_care/usage_report.dart';

import 'server_care_fixtures.dart';

ServerStatus status(Map<String, dynamic> patch) =>
    ServerStatus.parse({...statusHealthy(), ...patch})!;

void main() {
  group('ServerStatus', () {
    test('reads the healthy fixture', () {
      final s = ServerStatus.parse(statusHealthy())!;
      expect(s.version, '0.22.2');
      expect(s.gatewayState, GatewayState.running);
      expect(s.gatewaySharedWith, ['default', 'work']);
      expect(s.platformsConfigured, 1);
      expect(s.storageOk, isTrue);
      expect(s.disk.freeMb, 52000);
      expect(s.disk.pressure, Pressure.ok);
    });

    test('an older server reads as unknown, not as a problem', () {
      final s = ServerStatus.parse(statusOld())!;
      expect(s.storageOk, isNull);
      expect(s.disk.pressure, Pressure.unknown);
      expect(s.memory.lastBootSuspectedOom, isFalse);
      expect(Attention.of(s), Attention.allGood);
    });

    test('keeps an unknown gateway state as other', () {
      final s = status({'gateway_state': 'hibernating'});
      expect(s.gatewayState, GatewayState.other);
      expect(s.gatewayStateRaw, 'hibernating');
    });

    test('ill-typed fields never throw', () {
      final s = ServerStatus.parse({
        'version': 3,
        'components': 'x',
        'disk': {'pressure': 7, 'free_mb': 'lots'},
        'profiles': [1, 'a'],
        'gateway_running': 'yes',
      })!;
      expect(s.version, isNull);
      expect(s.profiles, ['a']);
      expect(s.gatewayRunning, isFalse);
      expect(ServerStatus.parse('nope'), isNull);
    });
  });

  group('Attention', () {
    test('ranks the design table, first match wins', () {
      Attention of(Map<String, dynamic> patch) => Attention.of(status(patch));
      expect(Attention.of(null), Attention.offline);
      expect(
        of({
          'components': {
            'storage': {'status': 'error', 'reason': 'corrupt'},
          },
          'gateway_running': false,
        }),
        Attention.storageUnreadable,
      );
      expect(of({'gateway_state': 'startup_failed'}), Attention.gatewayFailed);
      expect(
        of({'gateway_state': 'degraded', 'gateway_running': false}),
        Attention.gatewayFailed,
      );
      expect(
        of({'gateway_heartbeat_stale_s': 120}),
        Attention.gatewayUnresponsive,
      );
      expect(of({'gateway_running': false}), Attention.gatewayOff);
      expect(
        of({
          'disk': {'pressure': 'critical', 'free_mb': 1200},
          'memory': {'last_boot_suspected_oom': true},
        }),
        Attention.diskCritical,
      );
      expect(
        of({
          'memory': {'last_boot_suspected_oom': true},
          'gateway_state': 'degraded',
        }),
        Attention.unexpectedRestart,
      );
      expect(of({'gateway_state': 'degraded'}), Attention.channelsOffline);
      expect(
        of({
          'components': {
            'platforms': {'configured': 2, 'connected': 1},
          },
        }),
        Attention.channelsOffline,
      );
      expect(
        of({
          'memory': {'pressure': 'critical'},
        }),
        Attention.memoryLow,
      );
      expect(
        of({
          'disk': {'pressure': 'elevated'},
        }),
        Attention.diskLow,
      );
      expect(of({}), Attention.allGood);
    });

    test('a stopped gateway without channels is neutral', () {
      final s = status({
        'gateway_running': false,
        'gateway_state': 'stopped',
        'components': {
          'platforms': {'configured': 0, 'connected': 0},
        },
      });
      expect(Attention.of(s), Attention.allGood);
      expect(Attention.of(s).needsAttention, isFalse);
    });

    test('low disk and memory are not urgent', () {
      expect(Attention.diskLow.needsAttention, isFalse);
      expect(Attention.memoryLow.needsAttention, isFalse);
      expect(Attention.diskCritical.needsAttention, isTrue);
      expect(Attention.gatewayOff.needsAttention, isTrue);
    });
  });

  group('UpdateCheck', () {
    test('reads commits and skips rows without sha or summary', () {
      final c = UpdateCheck.parse(updateCheckBehind())!;
      expect(c.installMethod, InstallMethod.git);
      expect(c.behind, 2);
      expect(c.canApply, isTrue);
      expect(c.commits.map((e) => e.sha), ['1a2b3c4', '5d6e7f8']);
    });

    test('behind null means the check could not run', () {
      final c = UpdateCheck.parse(updateCheckDocker())!;
      expect(c.couldNotCheck, isTrue);
      expect(c.installMethod, InstallMethod.docker);
      expect(c.canApply, isFalse);
      expect(c.updateCommand, contains('docker'));
    });

    test('an empty command is none; unknown methods are kept', () {
      final c = UpdateCheck.parse(updateCheckManaged())!;
      expect(c.installMethod, InstallMethod.managedRuntime);
      expect(c.updateCommand, isNull);
      final o = UpdateCheck.parse({'install_method': 'flatpak'})!;
      expect(o.installMethod, InstallMethod.other);
      expect(o.installMethodRaw, 'flatpak');
    });

    test('rollback is read', () {
      final c = UpdateCheck.parse({'rollback_to': 'v0.22.0', 'behind': 0})!;
      expect(c.rollbackTo, 'v0.22.0');
    });
  });

  group('UpdateStart and receipt', () {
    test('started, already running and refused', () {
      final started = UpdateStart.parse(updateStarted()) as UpdateStarted;
      expect(started.actionId, 'a' * 32);
      expect(started.alreadyRunning, isFalse);
      final again = UpdateStart.parse({
        ...updateStarted(),
        'already_running': true,
      }) as UpdateStarted;
      expect(again.alreadyRunning, isTrue);
      final refused = UpdateStart.parse(updateRefused()) as UpdateRefused;
      expect(refused.code, 'docker_update_unsupported');
      expect(refused.command, 'docker compose pull');
      expect(UpdateStart.parse([]), isNull);
    });

    test('reads success and partial with user_action', () {
      final ok = UpdateReceiptSummary.parse(receiptSuccess())!;
      expect(ok.outcome, UpdateOutcome.success);
      expect(ok.actionId, 'a' * 32);
      expect(ok.postVersion, '0.23.0');
      final partial = UpdateReceiptSummary.parse(receiptPartial())!;
      expect(partial.outcome, UpdateOutcome.partial);
      expect(partial.userAction?.reason, contains('config migrate'));
      expect(partial.followups.single.step, 'restart');
    });

    test('ill-typed followups never throw', () {
      final r = UpdateReceiptSummary.parse({
        'summary': {'outcome': 'success', 'followups': 'none'},
      })!;
      expect(r.followups, isEmpty);
    });

    test('an unknown outcome is other; no summary is null', () {
      expect(
        UpdateReceiptSummary.parse({
          'summary': {'outcome': 'weird'},
        })!.outcome,
        UpdateOutcome.other,
      );
      expect(UpdateReceiptSummary.parse({'receipt': {}}), isNull);
    });
  });

  group('ActionStatus', () {
    test('keeps only the lines after the last start header', () {
      final s = ActionStatus.parse(actionStatusAfterTwoRuns())!;
      expect(s.running, isFalse);
      expect(s.exitCode, 1);
      expect(s.lines.first, contains('Configuration'));
      expect(s.lines, isNot(contains('old run line')));
    });

    test('no header keeps every line; ill-typed fields are tolerated', () {
      final s = ActionStatus.parse({
        'running': 1,
        'exit_code': 'x',
        'lines': ['a', 2],
      })!;
      expect(s.running, isFalse);
      expect(s.exitCode, isNull);
      expect(s.lines, ['a']);
    });

    test('a header with a trailing carriage return is recognised', () {
      expect(
        linesOfLatestRun([
          'a',
          '=== doctor started 2026-11-14 09:00:00 ===\r',
          'b',
        ]),
        ['b'],
      );
    });

    test('the status keeps the header of the latest run', () {
      final s = ActionStatus.parse({
        'running': false,
        'lines': [
          '=== doctor started 2026-11-14 08:00:00 ===',
          'old',
          '=== doctor started 2026-11-14 09:00:00 ===\r',
          'new',
        ],
      })!;
      expect(s.lines, ['new']);
      expect(s.startHeader, '=== doctor started 2026-11-14 09:00:00 ===');
      expect(
        ActionStatus.parse({
          'lines': ['a'],
        })!.startHeader,
        isNull,
      );
    });

    test('a header with an action id is recognised', () {
      expect(
        linesOfLatestRun([
          'x',
          '=== hermes-update started 2026-11-14 09:00:00 ${'a' * 32} ===',
          'y',
        ]),
        ['y'],
      );
    });
  });

  group('LogLine', () {
    test('parses entries and folds a traceback into the line before', () {
      final lines = LogLine.parseAll(logsErrors);
      expect(lines, hasLength(2));
      expect(lines.first.level, LogLevel.error);
      expect(lines.first.source, 'gateway.run');
      expect(lines.first.message, 'Telegram failed');
      expect(lines.first.time, '2026-11-14 09:12:03,114');
      expect(lines.first.continuation, hasLength(3));
      expect(lines.last.level, LogLevel.warning);
      expect(lines.last.continuation, isEmpty);
    });

    test('a leading orphan line stays as a headerless entry', () {
      final lines = LogLine.parseAll([
        '  at x',
        '2026-11-14 09:12:04,001 INFO a.b: hi',
      ]);
      expect(lines.first.isHeaderless, isTrue);
      expect(lines.first.raw, '  at x');
      expect(lines.last.message, 'hi');
    });
  });

  group('DoctorReport', () {
    test('reads sections, items, notes, fixes and counts unknown lines', () {
      final r = DoctorReport.parse(
        actionStatusAfterTwoRuns()['lines'] as List<String>,
      );
      expect(r.sections.map((s) => s.title), ['Configuration', 'Messaging']);
      expect(r.passed, 1);
      expect(r.warnings, 1);
      expect(r.problems, 1);
      final warning = r.sections.first.items[1];
      expect(warning.text, 'Config version 30 is behind 31');
      expect(warning.detail, "run 'hermes config migrate'");
      expect(warning.note, 'Older keys still work');
      expect(r.sections.last.other, ['something unexpected']);
      expect(r.unknownLines, 1);
      expect(r.fixes, ["Re-run 'hermes setup telegram'", 'Migrate the config']);
      expect(r.allPassed, isFalse);
    });

    test('keeps lines after the list of fixes that are not fixes', () {
      final r = DoctorReport.parse([
        '◆ A',
        '  ✗ Broken',
        '  Found 1 issue(s) to address:',
        '',
        '  1. Do this',
        '  and then something odd',
      ]);
      expect(r.fixes, ['Do this']);
      expect(r.trailing, ['and then something odd']);
      expect(r.unknownLines, 1);
    });

    test('an emoji-presentation warning marker leaves no invisible text', () {
      final r = DoctorReport.parse(['◆ A', '  ⚠\uFE0F Low disk']);
      expect(r.sections.single.items.single.text, 'Low disk');
    });

    test('all passed', () {
      final r = DoctorReport.parse(doctorAllPassed);
      expect(r.allPassed, isTrue);
      expect(r.problems, 0);
      expect(r.fixes, isEmpty);
    });

    test('random and truncated input never throws', () {
      final random = Random(7);
      const alphabet = '◆✓⚠✗→ \n=-ab1.\x1B[0m';
      for (var i = 0; i < 300; i++) {
        final lines = List.generate(
          random.nextInt(8),
          (_) => String.fromCharCodes(
            List.generate(
              random.nextInt(20),
              (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
            ),
          ),
        );
        DoctorReport.parse(lines);
        LogLine.parseAll(lines);
        linesOfLatestRun(lines);
      }
      final truncated = (doctorProblems.join('\n'))
          .substring(0, 40)
          .split('\n');
      expect(() => DoctorReport.parse(truncated), returnsNormally);
    });
  });

  group('UsageReport', () {
    final today = DateTime(2026, 11, 14, 23, 59);

    test('fills the window with zero days, one per calendar day', () {
      final r = UsageReport.parse(usage30(), days: 30, today: today)!;
      expect(r.days, hasLength(30));
      expect(r.days.first.day, DateTime.utc(2026, 10, 16));
      expect(r.days.last.day, DateTime.utc(2026, 11, 14));
      final nov12 = r.days.firstWhere(
        (d) => d.day == DateTime.utc(2026, 11, 12),
      );
      expect(nov12.tokens, 876000);
      expect(nov12.sessions, 9);
      expect(
        r.days.firstWhere((d) => d.day == DateTime.utc(2026, 11, 11)).tokens,
        0,
      );
    });

    test('the window ends at the newest day the server sent when that is later '
        'than the device date', () {
      // The server's calendar day can be ahead of the device's.
      final r = UsageReport.parse(
        usage30(),
        days: 7,
        today: DateTime(2026, 11, 11),
      )!;
      expect(r.days, hasLength(7));
      expect(r.days.last.day, DateTime.utc(2026, 11, 12));
      expect(r.days.first.day, DateTime.utc(2026, 11, 6));
      expect(r.totals.tokens, 877500);
      expect(
        r.days.firstWhere((d) => d.day == DateTime.utc(2026, 11, 12)).tokens,
        876000,
      );
    });

    test('totals come from the server; tokens are input plus output', () {
      final r = UsageReport.parse(usage30(), days: 30, today: today)!;
      expect(r.totals.tokens, 877500);
      expect(r.totals.estimatedCost, 1.2);
      expect(r.totals.actualCost, 0.9);
      expect(r.totals.cacheReadTokens, 410000);
    });

    test('without totals they are summed from the days', () {
      final r = UsageReport.parse(
        {'daily': usage30()['daily']},
        days: 7,
        today: today,
      )!;
      expect(r.totals.tokens, 876000 + 1500);
    });

    test('models are sorted by tokens and skip rows without a name', () {
      final r = UsageReport.parse(usage30(), days: 30, today: today)!;
      expect(r.byModel.map((m) => m.model), ['<model id>', '<small model>']);
    });

    test('empty and odd bodies', () {
      final empty = UsageReport.parse(
        {'daily': [], 'totals': {}},
        days: 7,
        today: today,
      )!;
      expect(empty.isEmpty, isTrue);
      expect(empty.days, hasLength(7));
      expect(UsageReport.parse([], days: 7, today: today), isNull);
      expect(
        UsageReport.parse(
          {'daily': 'x', 'by_model': 3},
          days: 7,
          today: today,
        )!.isEmpty,
        isTrue,
      );
    });
  });
}
