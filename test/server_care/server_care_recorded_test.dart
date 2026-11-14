import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/action_status.dart';
import 'package:hermes_app/src/server_care/doctor_report.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/server_status.dart';
import 'package:hermes_app/src/server_care/update_check.dart';
import 'package:hermes_app/src/server_care/usage_report.dart';

import 'server_care_fixtures.dart';

/// The parsers against the answers recorded from Hermes d923a5eb.
void main() {
  test('the recorded status of a stopped gateway', () {
    final s = ServerStatus.parse(recordedStatusGatewayStopped())!;
    expect(s.gatewayRunning, isFalse);
    expect(s.gatewayState, anyOf(isNull, GatewayState.stopped));
    expect(s.gatewayStateRaw, isNull);
    expect(s.profiles, ['default']);
    expect(s.configVersion, 0);
    expect(s.latestConfigVersion, 50);
    expect(s.disk.freeMb, 26108);
    expect(s.disk.pressure, Pressure.ok);
    expect(s.storageOk, isTrue);
    expect(s.platformsConfigured, 0);
    expect(s.activeAgents, 0);
    expect(s.gatewaySharedWith, isEmpty);
  });

  test('the recorded update check of a git install without a remote', () {
    final c = UpdateCheck.parse(recordedUpdateCheckUnreachable())!;
    expect(c.installMethod, InstallMethod.git);
    expect(c.behind, isNull);
    expect(c.couldNotCheck, isTrue);
    expect(c.updateAvailable, isFalse);
    expect(c.canApply, isTrue);
    expect(c.updateCommand, 'hermes update');
    expect(c.message, isNotEmpty);
    expect(c.commits, isEmpty);
  });

  test('a recorded action that never ran is not running and has no lines', () {
    final a = ActionStatus.parse(recordedActionStatusIdle('doctor'))!;
    expect(a.running, isFalse);
    expect(a.exitCode, isNull);
    expect(a.lines, isEmpty);
  });

  group('recorded logs', () {
    test('every real line parses as an entry, newline included', () {
      for (final raw in [...recordedLogsErrors, ...recordedLogsAgent]) {
        expect(raw, endsWith('\n'), reason: 'the server keeps the newline');
      }
      final entries = LogLine.parseAll(recordedLogsAgent);
      expect(entries, hasLength(recordedLogsAgent.length));
      expect(entries.any((e) => e.isHeaderless), isFalse);
      expect(entries.first.level, LogLevel.info);
      expect(entries[1].level, LogLevel.warning);
      expect(entries[1].source, 'hermes_cli.post_update');
      expect(entries[1].message, startsWith('config migration skipped'));
    });

    test('the errors file holds warnings only', () {
      final entries = LogLine.parseAll(recordedLogsErrors);
      expect(entries, hasLength(recordedLogsErrors.length));
      expect(entries.map((e) => e.level), everyElement(LogLevel.warning));
    });
  });

  group('recorded usage', () {
    final today = DateTime(2026, 11, 14);

    test('an empty history with null totals is seven empty days', () {
      final r = UsageReport.parse(recordedUsageEmpty(), days: 7, today: today)!;
      expect(r.days, hasLength(7));
      expect(r.days.every((d) => d.tokens == 0), isTrue);
    });

    test('one scripted turn lands on its day with tokens and the model', () {
      final r = UsageReport.parse(
        recordedUsageOneTurn(),
        days: 7,
        today: today,
      )!;
      expect(r.days, hasLength(7));
      final used = r.days.where((d) => d.tokens > 0).toList();
      expect(used, hasLength(1));
      expect(used.single.inputTokens, 20);
      expect(used.single.outputTokens, 20);
      expect(used.single.sessions, 1);
      expect(used.single.apiCalls, 2);
    });
  });

  group('the recorded doctor run', () {
    final report = DoctorReport.parse(recordedDoctorLines);

    test('has its header, which the parser drops', () {
      expect(
        recordedDoctorLines.any((l) => l.startsWith('=== doctor started')),
        isTrue,
      );
    });

    test('finds sections, problems, warnings and the four fixes', () {
      expect(report.sections, hasLength(17));
      expect(report.problems, 2);
      expect(report.warnings, greaterThan(0));
      expect(report.passed, greaterThan(0));
      expect(report.allPassed, isFalse);
      expect(report.fixes, hasLength(4));
      expect(report.fixes.first, "Run 'hermes setup' to create .env");
    });

    test('keeps the detail lines under their item', () {
      final auth = report.sections.singleWhere(
        (s) => s.title == 'Auth Providers',
      );
      final codex = auth.items.singleWhere(
        (i) => i.text.startsWith('OpenAI Codex'),
      );
      expect(codex.note, isNotNull);
    });

    test('knows only two lines it cannot place', () {
      // "Running 44 connectivity checks in parallel…" and the closing
      // "Tip: run 'hermes doctor --fix' …" line.
      expect(report.unknownLines, 2);
    });

    test('reads the same with ANSI colour around every line', () {
      final coloured = [
        for (final l in recordedDoctorLines) '\x1B[1;36m$l\x1B[0m',
      ];
      final again = DoctorReport.parse(coloured);
      expect(again.sections.length, report.sections.length);
      expect(again.problems, report.problems);
      expect(again.warnings, report.warnings);
      expect(again.passed, report.passed);
      expect(again.fixes, report.fixes);
      expect(again.unknownLines, report.unknownLines);
    });
  });
}
