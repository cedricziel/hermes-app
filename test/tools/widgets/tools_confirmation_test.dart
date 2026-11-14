import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/tools/toolset_copy.dart';
import 'package:hermes_app/src/tools/widgets/tools_confirmation.dart';
import 'package:hermes_app/src/tools/widgets/tools_difference_sheet.dart';

import 'pump_tools.dart';

const _question = ToolsetQuestion(
  title: 'Let Hermes run commands?',
  body: 'It can run commands.',
  confirmLabel: 'Switch on',
);

/// A button that asks [question] and writes the answer into [answers].
Widget _asker(List<bool> answers, {ToolsetQuestion question = _question}) =>
    Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            answers.add(await showToolsetConfirmation(context, question)),
        child: const Text('ask'),
      ),
    );

/// Whether [a] comes before [b]: above it when the buttons are stacked, to
/// the start of it when they sit side by side.
bool _before(WidgetTester t, Finder a, Finder b) {
  final pa = t.getTopLeft(a);
  final pb = t.getTopLeft(b);
  return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
}

void main() {
  group('on Apple platforms', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('Cancel is first and the default on $platform', (t) async {
        await pumpTools(t, _asker([]), platform: platform);
        await t.tap(find.text('ask'));
        await t.pumpAndSettle();
        final actions = t
            .widgetList<CupertinoDialogAction>(
              find.byType(CupertinoDialogAction),
            )
            .toList();
        expect(actions, hasLength(2));
        expect((actions[0].child as Text).data, 'Cancel');
        expect(actions[0].isDefaultAction, isTrue);
        expect((actions[1].child as Text).data, 'Switch on');
        expect(actions[1].isDefaultAction, isFalse);
        expect(actions[1].isDestructiveAction, isFalse);
        expect(actions[0].isDestructiveAction, isFalse);
        expect(
          _before(t, find.text('Cancel'), find.text('Switch on')),
          isTrue,
          reason: 'Cancel sits first',
        );
      });
    }
  });

  group('on Material', () {
    testWidgets('two text buttons, Cancel first, neither filled', (t) async {
      await pumpTools(t, _asker([]), platform: TargetPlatform.android);
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
      final buttons = t
          .widgetList<TextButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            ),
          )
          .toList();
      expect(buttons, hasLength(2));
      expect((buttons[0].child as Text).data, 'Cancel');
      expect((buttons[1].child as Text).data, 'Switch on');
      expect(_before(t, find.text('Cancel'), find.text('Switch on')), isTrue);
    });
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'the answer is true only for the confirming action ($platform)',
      (t) async {
        final answers = <bool>[];
        await pumpTools(t, _asker(answers), platform: platform);
        await t.tap(find.text('ask'));
        await t.pumpAndSettle();
        expect(find.text('Let Hermes run commands?'), findsOneWidget);
        expect(find.text('It can run commands.'), findsOneWidget);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        await t.tap(find.text('ask'));
        await t.pumpAndSettle();
        await t.tap(find.text('Switch on'));
        await t.pumpAndSettle();
        expect(answers, [false, true]);
      },
    );
  }

  testWidgets('dismissing the dialog answers false', (t) async {
    final answers = <bool>[];
    await pumpTools(t, _asker(answers), platform: TargetPlatform.android);
    await t.tap(find.text('ask'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('the Android back button dismisses and answers false', (t) async {
    final answers = <bool>[];
    await pumpTools(t, _asker(answers), platform: TargetPlatform.android);
    await t.tap(find.text('ask'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('Cancel follows the language', (t) async {
    await pumpTools(
      t,
      _asker([]),
      platform: TargetPlatform.android,
      locale: const Locale('de'),
    );
    await t.tap(find.text('ask'));
    await t.pumpAndSettle();
    expect(find.text('Abbrechen'), findsOneWidget);
  });

  test('the questions use the brief\'s words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final local = toolsetLocalBackendQuestion(en);
    expect(local.title, 'Run commands directly on your server?');
    expect(
      local.body,
      "Commands will run on the same machine as Hermes, with full access to that machine's files, not in a container.",
    );
    expect(local.confirmLabel, 'Use local');
    final install = toolsetInstallStepQuestion(en);
    expect(install.title, 'Install on your server?');
    expect(
      install.body,
      'Hermes will run an installer on the server. It may download software.',
    );
    expect(install.confirmLabel, 'Install');
    final allow = toolsetAllowAccessQuestion(en);
    expect(allow.title, "Allow access on the server's Mac?");
    expect(
      allow.body,
      'A permission window will open on the computer that runs Hermes. Someone there has to approve it.',
    );
    expect(allow.confirmLabel, 'Allow access');
    for (final name in [
      'terminal',
      'browser',
      'code_execution',
      'computer_use',
    ]) {
      expect(
        toolsetConfirmQuestion(en, name, 'work')!.confirmLabel,
        'Switch on',
      );
    }
    final other = toolsetInstallQuestion(en, 'Image generation');
    expect(other.title, 'Install on your server?');
    expect(
      other.body,
      'Switching Image generation on may run an installer on the server. It may download software.',
    );
    expect(other.confirmLabel, 'Switch on');
  });

  test('every question has German words', () {
    final de = lookupAppLocalizations(const Locale('de'));
    for (final q in [
      toolsetLocalBackendQuestion(de),
      toolsetInstallStepQuestion(de),
      toolsetAllowAccessQuestion(de),
      toolsetConfirmQuestion(de, 'terminal', 'work')!,
    ]) {
      expect(q.title, isNotEmpty);
      expect(q.confirmLabel, isNotEmpty);
    }
  });

  group('ToolsDifferenceSheet', () {
    testWidgets('title, four paragraphs with the term bold, and Done', (
      t,
    ) async {
      var done = 0;
      await pumpTools(t, ToolsDifferenceSheet(onDone: () => done++));
      expect(
        find.text('Tools, skills, plugins and MCP servers'),
        findsOneWidget,
      );
      for (final term in ['Tools:', 'Skills:', 'Plugins:', 'MCP servers:']) {
        final paragraph = t
            .widgetList<RichText>(find.byType(RichText))
            .where((w) => w.text.toPlainText().startsWith(term));
        expect(paragraph, hasLength(1), reason: term);
        final bold = <TextSpan>[];
        paragraph.single.text.visitChildren((span) {
          if (span is TextSpan && span.text == term) bold.add(span);
          return true;
        });
        expect(bold, hasLength(1), reason: term);
        expect(bold.single.style?.fontWeight, FontWeight.w700);
      }
      expect(
        find.textContaining(
          'written instructions Hermes follows for a kind of job.',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Done'));
      expect(done, 1);
    });

    testWidgets('German, 3x, no overflow', (t) async {
      await pumpTools(
        t,
        ToolsDifferenceSheet(onDone: () {}),
        textScale: 3,
        locale: const Locale('de'),
      );
      expect(t.takeException(), isNull);
      expect(
        find.text('Tools, Skills, Plugins und MCP-Server'),
        findsOneWidget,
      );
    });

    testWidgets('opens as a sheet and Done closes it', (t) async {
      await pumpTools(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showToolsDifferenceSheet(context),
            child: const Text('open'),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(ToolsDifferenceSheet), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.byType(ToolsDifferenceSheet), findsNothing);
    });
  });
}
