import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_sheet.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

const _body = ValueKey('modal-body');

class _Answer {
  Object? value = 'pending';
  int calls = 0;
  void received(Object? answer) {
    value = answer;
    calls++;
  }
}

Future<void> _open(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.macOS,
  double width = 390,
  Brightness brightness = Brightness.light,
  bool sheet = false,
  bool reduced = false,
  ValueNotifier<bool>? busy,
  required _Answer answer,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Theme(
        data: ThemeData(platform: platform, brightness: brightness),
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (!sheet) {
                  showConfirmDialog(
                    context,
                    title: 'Confirm changes?',
                    confirmLabel: 'Confirm',
                  ).then(answer.received);
                  return;
                }
                showAdaptiveSheet<bool>(
                  context,
                  builder: (dialog) {
                    final content = SizedBox(
                      key: _body,
                      width: 200,
                      height: 120,
                      child: Column(
                        children: [
                          Text('Content: ${Theme.of(dialog).brightness.name}'),
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );
                    return busy == null
                        ? content
                        : ValueListenableBuilder<bool>(
                            valueListenable: busy,
                            builder: (_, saving, _) =>
                                PopScope(canPop: !saving, child: content),
                          );
                  },
                ).then(answer.received);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
}

double _opacity(WidgetTester tester, Finder content) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: content, matching: find.byType(FadeTransition)),
    )
    .fold(1, (value, fade) => value * fade.opacity.value);

void main() {
  for (final width in [390.0, 1000.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Mac sheet is a centered dialog at $width/$brightness', (
        tester,
      ) async {
        await _open(
          tester,
          width: width,
          brightness: brightness,
          sheet: true,
          answer: _Answer(),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.getCenter(find.byKey(_body)).dy, closeTo(400, 1));
        expect(find.text('Content: ${brightness.name}'), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }

  testWidgets('Mac confirmation stays stationary and finishes in 150 ms', (
    tester,
  ) async {
    await _open(tester, answer: _Answer());
    final content = find.text('Confirm changes?');
    final initial = tester.getRect(content);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getRect(content), initial);
    expect(_opacity(tester, content), greaterThan(0));
    expect(_opacity(tester, content), lessThan(1));
    await tester.pump(const Duration(milliseconds: 101));
    expect(_opacity(tester, content), 1);
    expect(tester.getRect(content), initial);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Mac confirmation closes with a stationary 150 ms fade', (
    tester,
  ) async {
    await _open(tester, answer: _Answer());
    await tester.pumpAndSettle();
    final content = find.text('Confirm changes?');
    final initial = tester.getRect(content);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getRect(content), initial);
    expect(_opacity(tester, content), greaterThan(0));
    expect(_opacity(tester, content), lessThan(1));
    await tester.pump(const Duration(milliseconds: 101));
    expect(content, findsNothing);
    expect(find.text('Open'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('reduced motion exposes Mac confirmation immediately', (
    tester,
  ) async {
    await _open(tester, reduced: true, answer: _Answer());
    expect(_opacity(tester, find.text('Confirm changes?')), 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'Mac confirmation keyboard actions preserve the underlying route',
    (tester) async {
      final answer = _Answer();
      await _open(tester, answer: answer);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final oldAction = tester.element(find.text('Confirm'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      Actions.maybeInvoke(oldAction, const ActivateIntent());
      await tester.pumpAndSettle();
      expect(answer.value, true);
      expect(answer.calls, 1);
      expect(find.text('Open'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('Mac alert ignores a retained action callback after dismissal', (
    tester,
  ) async {
    await _open(tester, answer: _Answer());
    await tester.pumpAndSettle();
    final callback = tester
        .widget<CupertinoDialogAction>(
          find.ancestor(
            of: find.text('Confirm'),
            matching: find.byType(CupertinoDialogAction),
          ),
        )
        .onPressed!;
    await tester.tap(find.text('Confirm'));
    callback();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Mac alert skips disabled actions and activates with Space', (
    tester,
  ) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (dialog) => AppAlertDialog(
                  title: const Text('Choose'),
                  actions: [
                    const AppDialogAction(
                      onPressed: null,
                      child: Text('Unavailable'),
                    ),
                    AppDialogAction(
                      onPressed: () {
                        accepted = true;
                        Navigator.pop(dialog);
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final action = find.text('Continue');
    final focus = Focus.of(tester.element(action));
    expect(focus.hasFocus, true);
    final decorated = tester.widgetList<DecoratedBox>(
      find.ancestor(of: action, matching: find.byType(DecoratedBox)),
    );
    expect(
      decorated.any(
        (widget) =>
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
      true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focus.hasFocus, true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(focus.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(accepted, true);
    expect(find.text('Open'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Escape cancels Mac confirmation without confirming', (
    tester,
  ) async {
    final answer = _Answer();
    await _open(tester, answer: answer);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(answer.value, false);
    expect(answer.calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('busy Mac dialog refuses barrier and Escape dismissal', (
    tester,
  ) async {
    final busy = ValueNotifier(true);
    addTearDown(busy.dispose);
    final answer = _Answer();
    await _open(tester, sheet: true, busy: busy, answer: answer);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(answer.calls, 0);
    busy.value = false;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(answer.value, isNull);
    expect(answer.calls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform wide sheet remains a dialog and returns its result',
      (tester) async {
        final answer = _Answer();
        await _open(
          tester,
          platform: platform,
          width: 1000,
          sheet: true,
          answer: answer,
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.getCenter(find.byKey(_body)).dy, closeTo(400, 1));
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(answer.value, true);
        expect(find.text('Open'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform compact sheet keeps mobile presentation', (
      tester,
    ) async {
      await _open(tester, platform: platform, sheet: true, answer: _Answer());
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byKey(_body)).dy, greaterThan(600));
      expect(find.byType(BottomSheet), findsOneWidget);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
