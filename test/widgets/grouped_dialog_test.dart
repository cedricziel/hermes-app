import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required double scale,
  required TargetPlatform platform,
  required String title,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(320, 568)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                GroupedDialog(title: title, children: const [Text('Row')]),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    for (final scale in [1.0, 2.0, 3.1]) {
      for (final title in ['Appearance and display', 'Notifications']) {
        testWidgets('title stays clear of Done: ${platform.name} x$scale '
            '"$title"', (tester) async {
          await _open(tester, scale: scale, platform: platform, title: title);
          expect(tester.takeException(), isNull);

          final done = tester.getRect(
            find.byKey(const Key('grouped-dialog-done')),
          );
          final titleRect = tester.getRect(
            find.descendant(
              of: find.byType(GroupedDialog),
              matching: find.text(title),
            ),
          );
          expect(titleRect.overlaps(done), isFalse);

          final dialog = tester.getRect(find.byType(GroupedDialog));
          expect(done.right, lessThanOrEqualTo(dialog.right));
          expect(titleRect.left, greaterThanOrEqualTo(dialog.left));
          expect(titleRect.right, lessThanOrEqualTo(dialog.right));
          // The bar grows with the text, never below its resting height.
          expect(done.height, greaterThan(0));
        });
      }
    }
  }

  testWidgets('Material chrome has no overflow at the largest text', (
    tester,
  ) async {
    for (final scale in [2.0, 3.1]) {
      await _open(
        tester,
        scale: scale,
        platform: TargetPlatform.android,
        title: 'Appearance and display',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('grouped-dialog-done')), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the header is as tall as before at the default scale', (
    tester,
  ) async {
    await _open(tester, scale: 1, platform: TargetPlatform.iOS, title: 'Prefs');
    final done = tester.getRect(find.byKey(const Key('grouped-dialog-done')));
    final row = tester.getRect(find.text('Row'));
    // Done sits in the middle of the 52 pt bar, and the rows follow it.
    expect(row.top - done.center.dy, 26);
  });

  testWidgets('Done is localized and closes the dialog', (tester) async {
    await _open(
      tester,
      scale: 1,
      platform: TargetPlatform.iOS,
      title: 'Titel',
      locale: const Locale('de'),
    );
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupedDialog), findsNothing);
  });

  testWidgets('the title mirrors to the start side in right to left', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const GroupedDialog(title: 'Titel', children: [Text('Row')]),
      ),
    );
    final done = tester.getRect(find.byKey(const Key('grouped-dialog-done')));
    final dialog = tester.getRect(find.byType(GroupedDialog));
    expect(done.left - dialog.left, lessThan(30));
  });
}
