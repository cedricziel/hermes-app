import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';

Future<List<ScheduleSpec>> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  ScheduleSpec spec,
) async {
  final changes = <ScheduleSpec>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: SchedulePicker(
          spec: spec,
          now: DateTime(2026, 10, 3, 12),
          onChanged: changes.add,
        ),
      ),
    ),
  );
  return changes;
}

/// The row's value, which is the pop-up button on the Mac.
Finder _value(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'\d').hasMatch(w.data ?? ''),
  ),
);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('the time opens a Cupertino picker on $platform', (
      tester,
    ) async {
      final changes = await _pump(tester, platform, const DailySpec(8, 0));
      await tester.tap(_value('when-time'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(changes.single, isA<DailySpec>());
      expect((changes.single as DailySpec).hour, 8);
    });

    testWidgets('Cancel keeps the schedule on $platform', (tester) async {
      final changes = await _pump(tester, platform, const DailySpec(8, 0));
      await tester.tap(_value('when-time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('the date opens a Cupertino picker on $platform', (
      tester,
    ) async {
      await _pump(tester, platform, OnceSpec(DateTime(2026, 10, 4, 9)));
      await tester.tap(_value('when-date'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  }

  testWidgets('the time opens Material\'s picker on Android', (tester) async {
    await _pump(tester, TargetPlatform.android, const DailySpec(8, 0));
    await tester.tap(_value('when-time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('the date opens Material\'s picker on Android', (tester) async {
    await _pump(
      tester,
      TargetPlatform.android,
      OnceSpec(DateTime(2026, 10, 4, 9)),
    );
    await tester.tap(_value('when-date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });
}
