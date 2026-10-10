import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_sections.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/cron_fixtures.dart';

const _reason =
    'Provider timeout after 120 seconds while waiting for the model to '
    'answer the scheduled prompt';

Future<void> _pump(
  WidgetTester tester,
  Map<String, Object?> row, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view
    ..physicalSize = const Size(320, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      home: Scaffold(
        body: ScheduleStatusRow(
          job: CronJob.fromJson(row)!,
          now: DateTime.utc(2026, 9, 20, 12),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a paused job still says why its last run failed', (
    tester,
  ) async {
    await _pump(
      tester,
      cronJobRow(state: 'paused', lastStatus: 'error', lastError: 'Boom'),
    );

    expect(find.text('Boom'), findsOneWidget);
  });

  testWidgets('a completed job still says its result was not delivered', (
    tester,
  ) async {
    await _pump(
      tester,
      cronJobRow(
        state: 'completed',
        lastStatus: 'ok',
        lastDeliveryError: 'Telegram refused the message',
      ),
    );

    expect(find.text('Telegram refused the message'), findsOneWidget);
  });

  testWidgets('on a Mac the whole failure can be selected and copied', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const error = '$_reason\nTraceback (most recent call last): ...';
    await _pump(
      tester,
      cronJobRow(lastStatus: 'error', lastError: error),
      platform: TargetPlatform.macOS,
    );

    final text = find.text(error);
    expect(text, findsOneWidget);
    expect(
      find.ancestor(of: text, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    // Read as text, not offered as a field to type in.
    expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsNothing);
    handle.dispose();
  });
}
