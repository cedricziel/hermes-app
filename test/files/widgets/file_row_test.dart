import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_glyph.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import 'files_widget_harness.dart';

FileRowModel _file(String name, {bool secret = false}) =>
    FileRowModel(name: name, isFolder: false, looksSecret: secret);

Widget _row(
  FileRowModel model, {
  VoidCallback? onTap,
  bool selected = false,
  FileRowMode mode = FileRowMode.browse,
}) => Builder(
  builder: (context) => GroupedSection(
    dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
    children: [
      FileRow(
        model: model,
        onTap: onTap ?? () {},
        selected: selected,
        mode: mode,
      ),
    ],
  ),
);

void main() {
  group('glyph and type word', () {
    final en = l10nFor('en');

    test('a name alone picks the glyph', () {
      expect(fileGlyphForName('notes.txt'), FileGlyph.text);
      expect(fileGlyphForName('README.md'), FileGlyph.text);
      expect(fileGlyphForName('analysis.py'), FileGlyph.code);
      expect(fileGlyphForName('chart.PNG'), FileGlyph.image);
      expect(fileGlyphForName('invoice.pdf'), FileGlyph.pdf);
      expect(fileGlyphForName('export.zip'), FileGlyph.archive);
      expect(fileGlyphForName('backup.tar'), FileGlyph.archive);
      expect(fileGlyphForName('sensor.dat'), FileGlyph.generic);
      expect(fileGlyphForName('Makefile'), FileGlyph.text);
    });

    test('the type word is a name or a localized word', () {
      expect(fileTypeLabel(en, 'analysis.py'), 'Python');
      expect(fileTypeLabel(en, 'notes.txt'), 'Plain text');
      expect(fileTypeLabel(en, 'build.log'), 'Log');
      expect(fileTypeLabel(en, 'data.sqlite'), 'Database');
      expect(fileTypeLabel(en, 'invoice.pdf'), 'PDF document');
      expect(fileTypeLabel(en, 'export.zip'), 'ZIP archive');
      expect(fileTypeLabel(en, 'backup.tar'), 'Archive');
      expect(fileTypeLabel(en, 'sensor.dat'), 'File');
      expect(fileTypeLabel(l10nFor('de'), 'export.zip'), 'ZIP-Archiv');
      expect(fileTypeLabel(l10nFor('de'), 'sensor.dat'), 'Datei');
    });
  });

  group('FileRow', () {
    testWidgets('a folder reads as a folder and ends in a chevron', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _row(const FileRowModel(name: 'reports', isFolder: true)),
      );

      expect(find.text('reports'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronRight.apple), findsOneWidget);
      expect(find.bySemanticsLabel('reports, folder'), findsOneWidget);
    });

    testWidgets('a file reads as a file and has no chevron', (tester) async {
      await pumpFiles(tester, _row(_file('notes.txt')));

      expect(find.bySemanticsLabel('notes.txt, file'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronRight.apple), findsNothing);
      expect(find.text('May contain secrets'), findsNothing);
    });

    testWidgets('a secret-looking file shows the lock and the words', (
      tester,
    ) async {
      await pumpFiles(tester, _row(_file('.env', secret: true)));

      expect(find.byIcon(AppIcons.lock.apple), findsOneWidget);
      expect(find.text('May contain secrets'), findsOneWidget);
      expect(
        find.bySemanticsLabel('.env, file, may contain secrets'),
        findsOneWidget,
      );
    });

    testWidgets('only a file is marked secret, never a folder', (tester) async {
      await pumpFiles(
        tester,
        _row(
          const FileRowModel(name: '.ssh', isFolder: true, looksSecret: true),
        ),
      );

      expect(find.byIcon(AppIcons.lock.apple), findsNothing);
      expect(find.bySemanticsLabel('.ssh, folder'), findsOneWidget);
    });

    testWidgets('the screen reader label is German in German', (tester) async {
      await pumpFiles(
        tester,
        _row(_file('.env', secret: true)),
        locale: const Locale('de'),
      );

      expect(find.text('Kann Geheimnisse enthalten'), findsOneWidget);
      expect(
        find.bySemanticsLabel('.env, Datei, kann Geheimnisse enthalten'),
        findsOneWidget,
      );
    });

    testWidgets('a tap calls onTap and the row is a button', (tester) async {
      var taps = 0;
      await pumpFiles(tester, _row(_file('notes.txt'), onTap: () => taps++));

      await tester.tap(find.text('notes.txt'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(FileRow)),
        isSemantics(
          label: 'notes.txt, file',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
    });

    testWidgets('a selected row says so to a screen reader', (tester) async {
      await pumpFiles(tester, _row(_file('notes.txt'), selected: true));

      expect(
        tester.getSemantics(find.byType(FileRow)),
        isA<SemanticsNode>().having(
          (n) => n.flagsCollection.isSelected,
          'selected',
          Tristate.isTrue,
        ),
      );
    });

    testWidgets('a chosen folder in a picker shows a check mark', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _row(
          const FileRowModel(name: 'reports', isFolder: true),
          selected: true,
          mode: FileRowMode.pick,
        ),
      );

      expect(find.byIcon(AppIcons.check.apple), findsOneWidget);
    });

    for (final (platform, height, name) in [
      (TargetPlatform.iOS, 44.0, 'iOS'),
      (TargetPlatform.android, 56.0, 'Android'),
      (TargetPlatform.macOS, 32.0, 'a Mac'),
    ]) {
      testWidgets('a row is $height tall on $name', (tester) async {
        await pumpFiles(tester, _row(_file('a.txt')), platform: platform);

        expect(tester.getSize(find.byType(FileRow)).height, height);
      });
    }

    testWidgets('a long name is cut in the middle and keeps its extension', (
      tester,
    ) async {
      const name =
          'quarterly-soil-moisture-survey-results-final-reviewed-2026-v3.pdf';
      await pumpFiles(tester, _row(_file(name)));

      final shown = tester.widget<Text>(
        find.descendant(of: find.byType(FileRow), matching: find.byType(Text)),
      );
      expect(shown.data, contains('…'));
      expect(shown.data, endsWith('.pdf'));
      expect(shown.maxLines, 2);
      // The screen reader still gets the whole name.
      expect(find.bySemanticsLabel('$name, file'), findsOneWidget);
    });

    testWidgets(
      'at the largest text the name wraps whole and the lock moves under it',
      (tester) async {
        await pumpFiles(
          tester,
          _row(_file('api_token.txt', secret: true)),
          textScale: 3,
        );

        final name = tester.getTopLeft(find.text('api_token.txt'));
        final hint = tester.getRect(
          find.textContaining('May contain secrets', findRichText: true),
        );
        final lock = tester.getRect(find.byIcon(AppIcons.lock.apple));
        expect(hint.top, greaterThan(name.dy));
        // The lock is level with the line it begins.
        expect(lock.center.dy, greaterThan(hint.top));
        expect(lock.center.dy, lessThan(hint.bottom));
        expect(lock.left, lessThanOrEqualTo(hint.left + 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a row grows with the text instead of cutting it', (
      tester,
    ) async {
      await pumpFiles(tester, _row(_file('notes.txt')), textScale: 3);
      final tall = tester.getSize(find.byType(FileRow)).height;
      await pumpFiles(tester, _row(_file('notes.txt')));
      final normal = tester.getSize(find.byType(FileRow)).height;

      expect(tall, greaterThan(normal));
    });
  });
}
