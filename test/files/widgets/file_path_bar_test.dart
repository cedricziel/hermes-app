import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_path_bar.dart';
import 'package:hermes_app/src/files/widgets/middle_ellipsis.dart';

import 'files_widget_harness.dart';

const _root = '/srv/demo/field-notes';

Widget _bar(
  String current, {
  String? highest = _root,
  bool showUp = false,
  VoidCallback? onUp,
  ValueChanged<ServerPath>? onOpen,
}) => FilePathBar(
  current: serverPath(current),
  highest: highest == null ? null : serverPath(highest),
  showUp: showUp,
  onUp: onUp,
  onOpen: onOpen ?? (_) {},
);

void main() {
  group('pathBarFolders', () {
    test('runs from the highest folder to the current one', () {
      final folders = pathBarFolders(
        serverPath('$_root/reports/2026'),
        serverPath(_root),
      );

      expect(folders.map((p) => p.value), [
        _root,
        '$_root/reports',
        '$_root/reports/2026',
      ]);
    });

    test('is one folder when the current one is the highest', () {
      expect(
        pathBarFolders(serverPath(_root), serverPath('$_root/')),
        hasLength(1),
      );
    });

    test('starts at the root without a highest folder', () {
      final folders = pathBarFolders(serverPath('/srv/demo'), null);

      expect(folders.map((p) => p.value), ['/', '/srv', '/srv/demo']);
    });

    test('starts at the root when the path is outside the highest folder', () {
      final folders = pathBarFolders(
        serverPath('/srv/other'),
        serverPath(_root),
      );

      expect(folders.first.value, '/');
    });
  });

  group('elideMiddle', () {
    test('leaves a short name alone', () {
      expect(elideMiddle('reports', maxChars: 24), 'reports');
      expect(elideMiddle('a' * 24, maxChars: 24), 'a' * 24);
    });

    test('cuts the middle of a long name to the limit', () {
      final cut = elideMiddle(
        'q3-soil-moisture-survey-results-field-team-north-b',
        maxChars: 24,
      );

      expect(cut, 'q3-soil-mois…eam-north-b');
      expect(cut.length, 24);
    });

    test('can keep the extension', () {
      final cut = elideMiddle(
        'quarterly-report-final-reviewed.pdf',
        maxChars: 16,
        keepExtension: true,
      );

      expect(cut.length, 16);
      expect(cut, endsWith('.pdf'));
      expect(cut, contains('…'));
    });

    test('counts characters, not code units', () {
      final cut = elideMiddle('🌱' * 30, maxChars: 10);

      expect(cut.characters.length, 10);
    });
  });

  group('FilePathBar', () {
    testWidgets('one segment is the current folder and not a button', (
      tester,
    ) async {
      await pumpFiles(tester, _bar(_root));

      expect(find.text('field-notes'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.bySemanticsLabel('$_root, current folder'), findsOneWidget);
    });

    testWidgets('ancestors are buttons that open that folder', (tester) async {
      final opened = <String>[];
      await pumpFiles(
        tester,
        _bar('$_root/reports/2026', onOpen: (p) => opened.add(p.value)),
      );

      expect(find.byType(TextButton), findsNWidgets(2));
      await tester.tap(find.text('reports'));
      await tester.tap(find.text('field-notes'));

      expect(opened, ['$_root/reports', _root]);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('every segment is read as its full path', (tester) async {
      await pumpFiles(tester, _bar('$_root/reports/2026'));

      expect(
        find.bySemanticsLabel('$_root/reports, folder, go to'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('$_root, folder, go to'), findsOneWidget);
      expect(
        find.bySemanticsLabel('$_root/reports/2026, current folder'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.widgetWithText(TextButton, 'reports')),
        isSemantics(
          label: '$_root/reports, folder, go to',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('the strip is named for a screen reader, in German too', (
      tester,
    ) async {
      await pumpFiles(tester, _bar('$_root/reports'));
      expect(find.bySemanticsLabel('Folder path'), findsOneWidget);

      await pumpFiles(
        tester,
        _bar('$_root/reports'),
        locale: const Locale('de'),
      );
      expect(find.bySemanticsLabel('Ordnerpfad'), findsOneWidget);
      expect(find.bySemanticsLabel('$_root, Ordner, öffnen'), findsOneWidget);
    });

    testWidgets('segments can be reached with the keyboard', (tester) async {
      await pumpFiles(tester, _bar('$_root/reports/2026'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final first = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(first, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(first));
    });

    testWidgets('a segment longer than 24 characters is cut in the middle', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _bar(
          '$_root/reports/q3-soil-moisture-survey-results-field-team-north-b',
        ),
      );

      expect(find.text('q3-soil-mois…eam-north-b'), findsOneWidget);
      // Its full path stays in the screen reader label and the tooltip.
      expect(
        find.bySemanticsLabel(
          '$_root/reports/q3-soil-moisture-survey-results-field-team-north-b, current folder',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a long path shows its end, with the start faded', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        _bar(
          '$_root/reports/2026/q3/regional-summaries/north-district/week-12',
          highest: '/srv/demo',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('week-12'), findsOneWidget);
      expect(find.byKey(const Key('path-bar-fade-start')), findsOneWidget);
      expect(find.byKey(const Key('path-bar-fade-end')), findsNothing);
      final shown = tester.getRect(find.text('week-12'));
      expect(shown.right, lessThanOrEqualTo(390));
    });

    testWidgets('a long path scrolls back to its start', (tester) async {
      await pumpFiles(
        tester,
        _bar(
          '$_root/reports/2026/q3/regional-summaries/north-district/week-12',
          highest: '/srv/demo',
        ),
      );
      await tester.pump();
      await tester.pump();

      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('path-bar-scroll')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(100000);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('path-bar-fade-start')), findsNothing);
      expect(find.byKey(const Key('path-bar-fade-end')), findsOneWidget);
    });

    testWidgets('a short path has no fade', (tester) async {
      await pumpFiles(tester, _bar('$_root/reports'));
      await tester.pump();

      expect(find.byKey(const Key('path-bar-fade-start')), findsNothing);
      expect(find.byKey(const Key('path-bar-fade-end')), findsNothing);
    });

    testWidgets('at the largest text the strip scrolls and nothing overflows', (
      tester,
    ) async {
      await pumpFiles(tester, _bar('$_root/reports/2026'), textScale: 3);
      await tester.pump();
      await tester.pump();

      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('path-bar-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(find.text('2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('Up button', () {
      testWidgets('is only there on wide layouts', (tester) async {
        await pumpFiles(tester, _bar('$_root/reports'));

        expect(find.byKey(const Key('path-bar-up')), findsNothing);
      });

      testWidgets('goes up when it is enabled', (tester) async {
        var ups = 0;
        await pumpFiles(
          tester,
          _bar('$_root/reports', showUp: true, onUp: () => ups++),
        );

        expect(find.bySemanticsLabel('Up'), findsOneWidget);
        await tester.tap(find.byKey(const Key('path-bar-up')));
        expect(ups, 1);
      });

      testWidgets('is disabled at the highest folder', (tester) async {
        await pumpFiles(tester, _bar(_root, showUp: true));

        final button = tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(const Key('path-bar-up')),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('is named Up (command-up arrow) on a Mac', (tester) async {
        await pumpFiles(
          tester,
          _bar('$_root/reports', showUp: true, onUp: () {}),
          platform: TargetPlatform.macOS,
        );

        expect(find.byTooltip('Up (⌘↑)'), findsOneWidget);
      });
    });

    group('targets', () {
      for (final (platform, target, name) in [
        (TargetPlatform.iOS, 44.0, 'iOS 44 pt'),
        (TargetPlatform.android, 48.0, 'Android 48 dp'),
        (TargetPlatform.macOS, 28.0, 'a Mac 28 pt'),
      ]) {
        testWidgets('segments and Up are at least $name', (tester) async {
          await pumpFiles(
            tester,
            _bar('$_root/reports/2026', showUp: true, onUp: () {}),
            platform: platform,
          );

          for (final finder in [
            find.widgetWithText(TextButton, 'reports'),
            find.byKey(const Key('path-bar-up')),
          ]) {
            final size = tester.getSize(finder);
            expect(size.height, greaterThanOrEqualTo(target));
            expect(size.width, greaterThanOrEqualTo(target));
          }
        });
      }
    });
  });
}
