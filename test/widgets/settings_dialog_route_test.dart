import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_choice_dialog.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/memory/widgets/memory_choice_dialog.dart';
import 'package:hermes_app/src/settings/appearance_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:provider/provider.dart';

import '../support/test_localizations.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _dialog = find.byType(GroupedDialog);
final _done = find.text('Done');

/// The visible panel, not the full-screen box that centres it.
final _panel = find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

typedef _Open = Future<void> Function(BuildContext context);

/// Opens a settings dialog through [open] on [platform] and leaves it showing.
Future<void> _show(
  WidgetTester tester,
  TargetPlatform platform,
  _Open open,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(platform: platform),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(_dialog, findsOneWidget);
}

Future<void> _tapBarrier(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

Future<void> _esc(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

Future<String?> _memoryChoice(BuildContext context) => showMemoryChoice<String>(
  context,
  title: 'Reports',
  options: const [('off', 'Off'), ('on', 'On')],
  current: 'on',
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  final dialogs = <String, _Open>{
    'Appearance': showAppearanceDialog,
    'Memory choice': _memoryChoice,
  };

  for (final MapEntry(key: name, value: open) in dialogs.entries) {
    group(name, () {
      testWidgets('iOS: a barrier tap leaves it open, Done closes it', (
        tester,
      ) async {
        await _show(tester, TargetPlatform.iOS, open);
        await _tapBarrier(tester);
        expect(_dialog, findsOneWidget);
        await tester.tap(_done);
        await tester.pumpAndSettle();
        expect(_dialog, findsNothing);
      });

      testWidgets('macOS: a barrier click closes it', (tester) async {
        await _show(tester, TargetPlatform.macOS, open);
        await _tapBarrier(tester);
        expect(_dialog, findsNothing);
      });

      testWidgets('Android: a barrier tap closes it', (tester) async {
        await _show(tester, TargetPlatform.android, open);
        await _tapBarrier(tester);
        expect(_dialog, findsNothing);
      });

      testWidgets('macOS: Esc closes it', (tester) async {
        await _show(tester, TargetPlatform.macOS, open);
        await _esc(tester);
        expect(_dialog, findsNothing);
      });

      testWidgets('iOS: Esc closes it like Done', (tester) async {
        await _show(tester, TargetPlatform.iOS, open);
        await _esc(tester);
        expect(_dialog, findsNothing);
      });
    });
  }

  testWidgets('Memory choice on iOS still returns the picked value', (
    tester,
  ) async {
    String? picked;
    await _show(
      tester,
      TargetPlatform.iOS,
      (context) async => picked = await _memoryChoice(context),
    );
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(picked, 'off');
    expect(_dialog, findsNothing);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('${platform.name}: Esc pops the dialog only, once', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (page) => Scaffold(
                    body: TextButton(
                      onPressed: () => _memoryChoice(page),
                      child: const Text('Page two'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page two'));
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      await _esc(tester);
      expect(_dialog, findsNothing);
      expect(find.text('Page two'), findsOneWidget);
    });

    testWidgets('${platform.name}: Esc with focus in a row closes it', (
      tester,
    ) async {
      await _show(tester, platform, _memoryChoice);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        primaryFocus?.context?.findAncestorWidgetOfExactType<GroupedDialog>(),
        isNotNull,
      );
      await _esc(tester);
      expect(_dialog, findsNothing);
    });
  }

  testWidgets('iOS: the dialog and Done stay inside the safe area at 3x text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 59, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await _show(
      tester,
      TargetPlatform.iOS,
      (context) => showMemoryChoice<int>(
        context,
        title: 'Review every',
        options: [for (var i = 1; i <= 12; i++) (i, 'Every $i turns')],
        current: 1,
      ),
    );
    final dialog = tester.getRect(_panel);
    final done = tester.getRect(_done);
    expect(dialog.top, greaterThanOrEqualTo(59));
    expect(dialog.bottom, lessThanOrEqualTo(844 - 34));
    expect(done.top, greaterThanOrEqualTo(59));
  });

  testWidgets('iOS: the dialog is centred in the safe area', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 59, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    await _show(tester, TargetPlatform.iOS, showAppearanceDialog);
    final rect = tester.getRect(_panel);
    expect(rect.center.dy, closeTo((59 + 844 - 34) / 2, 1));
    // Where main's showDialog put it.
    expect(rect.top, closeTo(329.5, 1));
  });

  testWidgets('macOS: Esc does not close a dialog whose barrier is inert', (
    tester,
  ) async {
    await _show(
      tester,
      TargetPlatform.macOS,
      (context) => showAppDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const GroupedDialog(title: 'Inert', children: []),
      ),
    );
    await _esc(tester);
    expect(_dialog, findsOneWidget);
  });

  testWidgets('Android: Esc closes a dialog like the route does', (
    tester,
  ) async {
    await _show(tester, TargetPlatform.android, _memoryChoice);
    await _esc(tester);
    expect(_dialog, findsNothing);
  });

  testWidgets('iOS: Esc closes the Kanban choice dialog', (tester) async {
    await _show(
      tester,
      TargetPlatform.iOS,
      (context) => showAppDialog<int>(
        context: context,
        builder: (dialog) => KanbanTaskChoiceDialog<int>(
          title: 'Priority',
          options: const [0, 1],
          labelOf: (value) => 'P$value',
          selected: 0,
          onPicked: (value) => Navigator.pop(dialog, value),
        ),
      ),
    );
    await _esc(tester);
    expect(_dialog, findsNothing);
  });

  testWidgets('iOS: a dialog with custom actions leaves a field its focus', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _show(
      tester,
      TargetPlatform.iOS,
      (context) => showAppDialog<void>(
        context: context,
        builder: (_) => GroupedDialog(
          title: 'Name',
          actions: [TextButton(onPressed: () {}, child: const Text('Save'))],
          children: [TextField(focusNode: focus, autofocus: true)],
        ),
      ),
    );
    expect(focus.hasPrimaryFocus, isTrue);
  });
}
