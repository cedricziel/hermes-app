import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/subagents/widgets/confirm_stop_agent.dart';

Future<bool?> open(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  String goal = 'Audit the dependency tree',
}) async {
  bool? answer;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              answer = await confirmStopAgent(context, goal: goal),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('asks first: title, the goal on one line, what stays and '
      'what keeps running', (tester) async {
    await open(
      tester,
      goal:
          'Audit the dependency tree for packages with known vulnerabilities, '
          'then write a summary of every finding for the release notes',
    );
    expect(find.text('Stop this agent?'), findsOneWidget);
    final message = tester.widget<Text>(
      find.textContaining('Audit the dependency tree'),
    );
    final text = message.data!;
    expect(text.split('\n').first.length, lessThanOrEqualTo(81));
    expect(text.split('\n').first, endsWith('…'));
    expect(text, contains('A tool that is running may be cut off.'));
    expect(text, contains('Programs it started keep running.'));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Stop agent'), findsOneWidget);
  });

  testWidgets('Material: two text buttons, Cancel first, none filled', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(FilledButton), findsNothing);
    final cancel = tester.getTopLeft(find.text('Cancel'));
    final stop = tester.getTopLeft(find.text('Stop agent'));
    expect(cancel.dx, lessThan(stop.dx));
  });

  testWidgets('Cancel answers false and nothing else does', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answer = await confirmStopAgent(context, goal: 'x'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop agent'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('German, and an Apple alert', (tester) async {
    await open(
      tester,
      platform: TargetPlatform.iOS,
      locale: const Locale('de'),
    );
    expect(find.text('Diesen Agenten stoppen?'), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Agent stoppen'), findsOneWidget);
  });

  test('goal line collapses whitespace and cuts on characters', () {
    expect(confirmGoalLine('  a\n b  '), 'a b');
    expect(confirmGoalLine('😀' * 100).runes.length, kConfirmGoalChars + 1);
  });

  testWidgets('Cancel is the default on Apple platforms', (tester) async {
    await open(tester, platform: TargetPlatform.iOS);
    final cancel = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Cancel'),
    );
    final stop = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Stop agent'),
    );
    expect(cancel.isDefaultAction, isTrue);
    expect(stop.isDestructiveAction, isTrue);
    expect(stop.isDefaultAction, isFalse);
  });

  testWidgets('on Material Stop agent is plain text in the error colour', (
    tester,
  ) async {
    await open(tester);
    final stop = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Stop agent'),
    );
    final color = stop.style?.foregroundColor?.resolve({});
    expect(
      color,
      Theme.of(tester.element(find.text('Stop agent'))).colorScheme.error,
    );
  });
}
