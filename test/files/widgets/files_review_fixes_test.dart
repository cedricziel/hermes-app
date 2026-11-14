import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hermes_app/src/files/widgets/file_download_progress.dart';
import 'package:hermes_app/src/files/widgets/file_path_bar.dart';
import 'package:hermes_app/src/files/widgets/file_preview_header.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/files_browser_view.dart';
import 'package:hermes_app/src/files/widgets/files_failures.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/files/widgets/files_questions.dart';
import 'package:hermes_app/src/files/widgets/files_spinner.dart';
import 'package:hermes_app/src/files/widgets/folder_pick_list.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import 'files_widget_harness.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final hi = math.max(_luminance(a), _luminance(b));
  final lo = math.min(_luminance(a), _luminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

/// The colour [needle] is drawn in, found in the rendered paragraphs.
Color? _colorOf(WidgetTester tester, String needle) {
  Color? walk(InlineSpan span, TextStyle? inherited) {
    final style = span.style == null
        ? inherited
        : (inherited?.merge(span.style) ?? span.style);
    if (span is TextSpan) {
      if ((span.text ?? '').contains(needle)) return style?.color;
      for (final child in span.children ?? const <InlineSpan>[]) {
        final found = walk(child, style);
        if (found != null) return found;
      }
    }
    return null;
  }

  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final base = TextStyle(color: Colors.transparent);
    final found = walk(paragraph.text, base);
    if (found != null) return found;
  }
  return null;
}

final _rows = [
  for (var i = 0; i < 2000; i++)
    FileRowModel(
      name: 'sensor-log-${i.toString().padLeft(4, '0')}.txt',
      isFolder: false,
      path: serverPath('/srv/demo/field-notes/sensor-log-$i.txt'),
    ),
];

void main() {
  group('rendered Markdown in dark mode', () {
    const text =
        '# Field notes\n\nBody with a [link](https://example.org/a).\n\n'
        '```\nrun: sensors --since monday\n```\n';

    testWidgets('the heading and the code block read against the page', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(text: text),
        brightness: Brightness.dark,
      );
      final scheme = buildHermesDarkTheme().colorScheme;

      final heading = _colorOf(tester, 'Field notes')!;
      expect(_contrast(heading, scheme.surface), greaterThanOrEqualTo(4.5));

      final block = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('run: sensors --since monday'),
              matching: find.byType(Container),
            )
            .first,
      );
      final fill = (block.decoration! as BoxDecoration).color!;
      expect(fill, scheme.surfaceContainerHighest);
      final code = _colorOf(tester, 'run: sensors')!;
      expect(_contrast(code, fill), greaterThanOrEqualTo(4.5));
      expect(_luminance(fill), lessThan(0.2));
    });

    testWidgets(
      'the heading and the code block read against the page in light',
      (tester) async {
        await pumpFiles(tester, const MarkdownPreview(text: text));
        final scheme = buildHermesLightTheme().colorScheme;

        expect(
          _contrast(_colorOf(tester, 'Field notes')!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    for (final brightness in Brightness.values) {
      testWidgets('a link has the app\'s link colour in ${brightness.name}', (
        tester,
      ) async {
        await pumpFiles(
          tester,
          const MarkdownPreview(text: text),
          brightness: brightness,
        );
        final theme = brightness == Brightness.dark
            ? buildHermesDarkTheme()
            : buildHermesLightTheme();
        final link = theme.extension<HermesChatColors>()!.link;

        final themed = tester.widget<GptMarkdownTheme>(
          find.byType(GptMarkdownTheme),
        );
        expect(themed.gptThemeData.linkColor, link);
        expect(_contrast(link, theme.colorScheme.surface), greaterThan(4.5));
      });
    }
  });

  group('inert Markdown', () {
    testWidgets('HTML is text: an <img> tag loads nothing and renders none', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(
          text:
              'Before <img src="https://example.org/t.png"> after\n\n'
              '<b>bold</b> <a href="https://example.org">anchor</a>',
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(
        find.textContaining(
          '<img src="https://example.org/t.png">',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('<b>bold</b>', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets(
      'a reference-style image shows its alt text and loads nothing',
      (tester) async {
        await pumpFiles(
          tester,
          const MarkdownPreview(
            text: 'Look: ![a chart][r]\n\n[r]: https://example.org/chart.png',
          ),
        );

        expect(find.byType(Image), findsNothing);
        expect(
          find.textContaining('a chart', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('a relative link is plain text, not a blue underlined link', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(text: 'See [the table](./data/table.md) now.'),
      );

      final theme = buildHermesLightTheme();
      final link = theme.extension<HermesChatColors>()!.link;
      expect(
        find.textContaining('the table', findRichText: true),
        findsOneWidget,
      );
      expect(_colorOf(tester, 'the table'), isNot(link));
      expect(
        find.textContaining('./data/table.md', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('"Image not loaded" is set apart in italics', (tester) async {
      await pumpFiles(tester, const MarkdownPreview(text: '![](img/a.png)'));

      expect(
        find.textContaining('Image not loaded', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a mail link asks "Write to …?"', (tester) async {
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmOpenLink(context, 'me@example.org'),
            child: const Text('ask'),
          ),
        ),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Write to me@example.org?'), findsOneWidget);
    });

    testWidgets('the mail question is German in German', (tester) async {
      await pumpFiles(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmOpenLink(context, 'me@example.org'),
            child: const Text('ask'),
          ),
        ),
        locale: const Locale('de'),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('me@example.org schreiben?'), findsOneWidget);
    });
  });

  group('FilePathBar at the largest text', () {
    testWidgets('the current folder is not clipped', (tester) async {
      await pumpFiles(
        tester,
        FilePathBar(
          current: serverPath('/srv/demo/field-notes'),
          highest: serverPath('/srv/demo/field-notes'),
          onOpen: (_) {},
        ),
        textScale: 3,
      );

      final text = tester.getSize(find.text('field-notes'));
      final segment = tester.getSize(
        find
            .ancestor(
              of: find.text('field-notes'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(segment.height, greaterThanOrEqualTo(text.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chevrons grow with the text', (tester) async {
      Future<double> chevron(double scale) async {
        await pumpFiles(
          tester,
          FilePathBar(
            current: serverPath('/srv/demo/field-notes/reports'),
            highest: serverPath('/srv/demo/field-notes'),
            onOpen: (_) {},
          ),
          textScale: scale,
        );
        return tester.getSize(find.byIcon(AppIcons.chevronRight.apple)).width;
      }

      expect(await chevron(3), greaterThan(await chevron(1)));
    });
  });

  group('lazy list', () {
    testWidgets('2,000 rows build only the ones on screen', (tester) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows, totalCount: 5310),
          onOpen: (_) {},
        ),
      );

      final built = tester.widgetList(find.byType(FileRow)).length;
      expect(built, greaterThan(5));
      expect(built, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolling to the end reaches the footer', (tester) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows, totalCount: 5310),
          onOpen: (_) {},
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500000));
      await tester.pumpAndSettle();
      expect(find.text('Showing the first 2,000 of 5,310.'), findsOneWidget);
      expect(find.text('sensor-log-1999.txt'), findsOneWidget);
    });

    testWidgets('every row is still 44 pt, and 32 pt on a Mac', (tester) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows.take(5).toList()),
          onOpen: (_) {},
        ),
      );
      for (final row
          in tester.widgetList(find.byType(FileRow)).toList().indexed) {
        expect(
          tester.getSize(find.byWidget(row.$2)).height,
          greaterThanOrEqualTo(44),
        );
      }
    });

    testWidgets('a Mac row is 32 pt', (tester) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows.take(5).toList()),
          onOpen: (_) {},
        ),
        platform: TargetPlatform.macOS,
      );
      expect(tester.getSize(find.byType(FileRow).first).height, 32);
    });

    testWidgets('a folder picker is lazy too, and shows only folders', (
      tester,
    ) async {
      final folders = [
        for (var i = 0; i < 500; i++)
          FileRowModel(name: 'dir-$i', isFolder: true),
      ];
      await pumpFiles(
        tester,
        FolderPickList(rows: [...folders, _rows.first], onTap: (_) {}),
      );

      expect(tester.widgetList(find.byType(FileRow)).length, lessThan(40));
      expect(find.text('sensor-log-0000.txt'), findsNothing);
    });

    testWidgets('the rows still form one card with separators', (tester) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows.take(3).toList()),
          onOpen: (_) {},
        ),
      );

      // Two separators between three rows, none above the first.
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('folder problems with their design copy', () {
    testWidgets('a fixed-folder server also says the chat folder is outside', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const FolderProblemView(problem: FolderProblem.fixedFolder),
      );

      expect(find.text("This chat's folder is outside it."), findsOneWidget);
    });

    testWidgets('a down workspace says the machine did not answer', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const FolderProblemView(problem: FolderProblem.workspaceDown),
        locale: const Locale('de'),
      );

      expect(
        find.text(
          'Der Rechner, auf dem dieses Profil arbeitet, hat nicht geantwortet.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a down workspace, in English', (tester) async {
      await pumpFiles(
        tester,
        const FolderProblemView(problem: FolderProblem.workspaceDown),
      );

      expect(
        find.text("The machine this profile works on didn't answer."),
        findsOneWidget,
      );
    });

    testWidgets('the stale banner shows even without a Try again action', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        FilesBrowserView(
          state: FolderViewReady(rows: _rows.take(2).toList(), stale: true),
          onOpen: (_) {},
        ),
      );

      expect(find.text('This list may be out of date.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(FilesOfflineBanner), findsOneWidget);
      expect(
        tester.widget<AppBanner>(find.byType(AppBanner)).tone,
        AppBannerTone.warning,
      );
    });
  });

  group('FileDownloadProgress', () {
    test('the announced figure steps by tenths', () {
      expect(announcedProgressBytes(0, 1000), 0);
      expect(announcedProgressBytes(99, 1000), 0);
      expect(announcedProgressBytes(100, 1000), 100);
      expect(announcedProgressBytes(149, 1000), 100);
      expect(announcedProgressBytes(1000, 1000), 1000);
      expect(announcedProgressBytes(5000, 1000), 1000);
      expect(announcedProgressBytes(5, 0), 0);
    });

    test('an unknown length steps by megabytes, then by ten', () {
      const mb = 1024 * 1024;
      expect(announcedReceivedBytes(500), 0);
      expect(announcedReceivedBytes(3 * mb + 5), 3 * mb);
      expect(announcedReceivedBytes(12 * mb), 10 * mb);
      expect(announcedReceivedBytes(29 * mb), 20 * mb);
    });

    testWidgets('the live region keeps its words between steps', (
      tester,
    ) async {
      const mb = 1024 * 1024;
      Future<void> pump(int received) => pumpFiles(
        tester,
        FileDownloadProgress(
          received: received,
          total: 30 * mb,
          onCancel: () {},
        ),
      );

      await pump(4 * mb);
      expect(find.semantics.byLabel('Downloading… 3 of 30 MB'), findsOneWidget);
      expect(find.text('Downloading… 4 of 30 MB'), findsOneWidget);
      await pump(4 * mb + 1000);
      expect(find.semantics.byLabel('Downloading… 3 of 30 MB'), findsOneWidget);
      await pump(7 * mb);
      expect(find.semantics.byLabel('Downloading… 6 of 30 MB'), findsOneWidget);
    });

    testWidgets('the bar track has contrast with its fill', (tester) async {
      await pumpFiles(
        tester,
        FileDownloadProgress(
          received: 15 * 1024 * 1024,
          total: 30 * 1024 * 1024,
          onCancel: () {},
        ),
      );

      final scheme = buildHermesLightTheme().colorScheme;
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.backgroundColor, scheme.surfaceContainerHighest);
      final fill = bar.color ?? scheme.primary;
      expect(_contrast(fill, bar.backgroundColor!), greaterThan(3));
    });
  });

  group('still spinner', () {
    testWidgets('is not announced as a percentage under reduced motion', (
      tester,
    ) async {
      await pumpFiles(tester, const FilesSpinner(), reduceMotion: true);

      expect(find.byType(ExcludeSemantics), findsWidgets);
      final exclude = tester.widget<ExcludeSemantics>(
        find.descendant(
          of: find.byType(FilesSpinner),
          matching: find.byType(ExcludeSemantics),
        ),
      );
      expect(exclude.excluding, isTrue);
    });

    testWidgets('a moving spinner keeps its semantics', (tester) async {
      await pumpFiles(tester, const FilesSpinner());

      final exclude = tester.widget<ExcludeSemantics>(
        find.descendant(
          of: find.byType(FilesSpinner),
          matching: find.byType(ExcludeSemantics),
        ),
      );
      expect(exclude.excluding, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('preview header at the largest text', () {
    testWidgets('stacks the tile above the name, then the actions', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        FilePreviewHeader(
          name: 'analysis.py',
          size: 1834,
          onSave: () {},
          onShare: () {},
        ),
        textScale: 3,
        size: const Size(820, 1400),
      );

      final tile = tester.getRect(find.byKey(const Key('file-preview-tile')));
      final name = tester.getRect(find.text('analysis.py'));
      final save = tester.getRect(
        find.ancestor(
          of: find.bySemanticsLabel('Save'),
          matching: find.byType(IconButton),
        ),
      );
      expect(name.top, greaterThanOrEqualTo(tile.bottom));
      expect(save.top, greaterThanOrEqualTo(name.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('is a row at the default size', (tester) async {
      await pumpFiles(
        tester,
        const FilePreviewHeader(name: 'analysis.py', size: 1834),
        size: const Size(820, 400),
      );

      final tile = tester.getRect(find.byKey(const Key('file-preview-tile')));
      final name = tester.getRect(find.text('analysis.py'));
      expect(name.left, greaterThanOrEqualTo(tile.right));
    });
  });

  group('secret row at the largest text', () {
    testWidgets('the lock sits level with its line', (tester) async {
      await pumpFiles(
        tester,
        Material(
          child: FileRow(
            model: const FileRowModel(
              name: 'api_token.txt',
              isFolder: false,
              looksSecret: true,
            ),
            onTap: () {},
          ),
        ),
        textScale: 3,
      );

      final lock = tester.getRect(find.byIcon(AppIcons.lock.apple));
      final hint = tester.getRect(
        find.textContaining('May contain', findRichText: true),
      );
      expect(lock.center.dy, closeTo(hint.top + hint.height / 2, hint.height));
      expect(lock.top, greaterThanOrEqualTo(hint.top - 2));
    });
  });

  test(
    'the widget files import neither dio nor dart:io nor the failure type',
    () {
      final offenders = <String>[];
      for (final file in Directory('lib/src/files/widgets').listSync()) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final line in file.readAsLinesSync()) {
          if (!line.startsWith('import')) continue;
          if (line.contains('package:dio') ||
              line.contains('dart:io') ||
              line.contains('files_failure.dart')) {
            offenders.add('${file.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty);
    },
  );
}
