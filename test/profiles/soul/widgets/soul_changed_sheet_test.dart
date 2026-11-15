import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_changed_sheet.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';

import 'soul_widget_host.dart';

const _bidi = 'Reply\u202Eevil\u202C\nNever\u200B tell\u0007';

SoulChangedSheet _sheet({
  String serverText = 'Server text',
  bool serverGone = false,
  bool open = false,
  VoidCallback? onKeep,
  VoidCallback? onReplace,
  ValueChanged<String>? onCopy,
}) => SoulChangedSheet(
  serverText: serverText,
  serverGone: serverGone,
  initiallyOpen: open,
  onKeepEditing: onKeep ?? () {},
  onReplaceAnyway: onReplace ?? () {},
  onCopy: onCopy ?? (_) {},
);

void main() {
  group('safe text', () {
    test('control and bidi characters become visible placeholders', () {
      expect(
        soulSafeText(_bidi),
        'Reply<U+202E>evil<U+202C>\nNever<U+200B> tell<U+0007>',
      );
    });

    test('tag characters and other invisible ones are drawn visibly', () {
      expect(soulSafeText('a\u{E0041}\u00ADb'), 'a<U+E0041><U+00AD>b');
    });

    test('line breaks stay, CRLF is one break, plain text is unchanged', () {
      expect(soulSafeText('a\r\nb\nc'), 'a\nb\nc');
      expect(soulSafeText('plain text'), 'plain text');
    });
  });

  group('SoulChangedSheet', () {
    testWidgets('the server text is closed behind the disclosure', (
      tester,
    ) async {
      await pumpSoul(tester, _sheet(serverText: 'Server text'));
      expect(find.text("Show server's version"), findsOneWidget);
      expect(find.text('Server text'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      await tester.tap(find.text("Show server's version"));
      await tester.pumpAndSettle();
      expect(find.text('Server text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('title, body and the two buttons', (tester) async {
      var keep = 0, replace = 0;
      await pumpSoul(
        tester,
        _sheet(onKeep: () => keep++, onReplace: () => replace++),
      );
      expect(find.text('Changed on the server'), findsOneWidget);
      expect(
        find.text(
          'This file changed since you opened it. Replacing it will lose those changes.',
        ),
        findsOneWidget,
      );
      // Keep editing is the filled default, Replace anyway a plain button.
      expect(find.widgetWithText(FilledButton, 'Keep editing'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Replace anyway'), findsOneWidget);
      await tester.tap(find.text('Replace anyway'));
      await tester.tap(find.text('Keep editing'));
      expect((keep, replace), (1, 1));
    });

    testWidgets('displays control and bidi characters as placeholders but '
        'copies the original', (tester) async {
      final copied = <String>[];
      await pumpSoul(
        tester,
        _sheet(serverText: _bidi, open: true, onCopy: copied.add),
      );
      await tester.pumpAndSettle();
      final shown = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .single
          .data!;
      expect(shown, contains('<U+202E>'));
      expect(shown, contains('<U+200B>'));
      expect(shown, contains('<U+0007>'));
      expect(shown.contains('\u202E'), isFalse);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied.single, _bidi);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('the server text box is capped at 40% of the height', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSoul(
        tester,
        _sheet(
          serverText: List.filled(400, 'long line').join('\n'),
          open: true,
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.getSize(
        find
            .ancestor(
              of: find.byType(SelectableText),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.height, lessThanOrEqualTo(844 * 0.4 + 0.5));
    });

    testWidgets('a file gone on the server says so', (tester) async {
      await pumpSoul(
        tester,
        _sheet(serverGone: true, serverText: 'ignored', open: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('The file was removed on the server.'), findsOneWidget);
      expect(find.text('No personality set.'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
      // Nothing to copy: no Copy, so no "Copied" for an empty clipboard.
      expect(find.text('Copy'), findsNothing);
      expect(
        find.textContaining('Replacing it will lose those changes'),
        findsNothing,
      );
    });

    for (final MapEntry(key: platform, value: minimum) in soulTargets.entries) {
      testWidgets('the disclosure row, Copy and both buttons are at least '
          '$minimum on $platform', (tester) async {
        await pumpSoul(tester, _sheet(open: true), platform: platform);
        await tester.pumpAndSettle();
        // The header row itself, not the tile with its opened content.
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text("Show server's version"),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(minimum),
        );
        expect(
          tester.getSize(find.byType(DisclosureTile)).height,
          greaterThan(minimum * 2),
        );
        for (final finder in [
          find.widgetWithText(TextButton, 'Copy'),
          find.widgetWithText(FilledButton, 'Keep editing'),
          find.widgetWithText(TextButton, 'Replace anyway'),
        ]) {
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(minimum));
        }
      });
    }

    testWidgets('German and the largest text do not overflow', (tester) async {
      await pumpSoul(
        tester,
        _sheet(open: true),
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Trotzdem ersetzen'), findsOneWidget);
    });
  });

  group('showSoulChangedSheet', () {
    Future<void> open(
      WidgetTester tester,
      List<SoulChangedChoice> choices, {
      TargetPlatform platform = TargetPlatform.iOS,
    }) async {
      await tester.pumpWidget(
        soulHost(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => choices.add(
                await showSoulChangedSheet(
                  context,
                  serverText: 'Server text',
                  onCopy: (_) {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
          platform: platform,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Replace anyway answers replaceAnyway', (tester) async {
      final choices = <SoulChangedChoice>[];
      await open(tester, choices);
      await tester.tap(find.text('Replace anyway'));
      await tester.pumpAndSettle();
      expect(choices, [SoulChangedChoice.replaceAnyway]);
    });

    testWidgets('dismissing is Keep editing', (tester) async {
      final choices = <SoulChangedChoice>[];
      await open(tester, choices);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(choices, [SoulChangedChoice.keepEditing]);
    });

    testWidgets('a Mac gets a dialog without a drag handle', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, [], platform: TargetPlatform.macOS);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a phone gets a bottom sheet', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, []);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
