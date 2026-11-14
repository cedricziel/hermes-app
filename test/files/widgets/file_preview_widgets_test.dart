import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_details_view.dart';
import 'package:hermes_app/src/files/widgets/file_download_progress.dart';
import 'package:hermes_app/src/files/widgets/file_glyph.dart';
import 'package:hermes_app/src/files/widgets/file_preview_cover.dart';
import 'package:hermes_app/src/files/widgets/file_preview_header.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/files/widgets/files_failures.dart';
import 'package:hermes_app/src/files/widgets/files_metrics.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/files/widgets/markdown_inert.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import '../../../widgetbook/files_sample_image.dart';
import 'files_widget_harness.dart';

const _longName =
    'quarterly-soil-moisture-survey-results-final-reviewed-2026-v3.pdf';

void main() {
  group('FilePreviewHeader', () {
    Widget header({String name = 'analysis.py', int? size = 1834}) =>
        FilePreviewHeader(
          name: name,
          size: size,
          onShare: () {},
          onSave: () {},
          onQuickLook: () {},
          onOpenWith: () {},
          onReload: () {},
        );

    testWidgets('shows the name and "type · size"', (tester) async {
      await pumpFiles(tester, header(), size: const Size(820, 400));

      expect(find.text('analysis.py'), findsOneWidget);
      expect(find.text('Python · 1.8 KB'), findsOneWidget);
    });

    testWidgets('shows the type alone until the size is known', (tester) async {
      await pumpFiles(tester, header(size: null), size: const Size(820, 400));

      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('a long name takes two lines and keeps its extension', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        header(name: _longName),
        size: const Size(440, 400),
      );

      final name = tester.widget<Text>(
        find.descendant(
          of: find.byType(FilePreviewHeader),
          matching: find.textContaining('…'),
        ),
      );
      expect(name.data, endsWith('.pdf'));
      expect(find.bySemanticsLabel(_longName), findsOneWidget);
    });

    testWidgets('iPad actions are Share, Save and More, at 44 pt', (
      tester,
    ) async {
      await pumpFiles(tester, header(), size: const Size(820, 400));

      for (final label in ['Share', 'Save', 'More']) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget, reason: label);
      }
      expect(find.bySemanticsLabel('Quick Look'), findsNothing);
      for (final label in ['Share', 'Save']) {
        final size = tester.getSize(
          find.ancestor(
            of: find.bySemanticsLabel(label),
            matching: find.byType(IconButton),
          ),
        );
        expect(size, const Size(44, 44), reason: label);
      }
    });

    testWidgets('Mac actions are Quick Look, Save and More, at 28 pt', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        header(),
        platform: TargetPlatform.macOS,
        size: const Size(820, 400),
      );

      expect(find.bySemanticsLabel('Quick Look'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsNothing);
      expect(find.byTooltip('Quick Look (Space)'), findsOneWidget);
      final size = tester.getSize(
        find.ancestor(
          of: find.bySemanticsLabel('Save'),
          matching: find.byType(IconButton),
        ),
      );
      expect(size, const Size(28, 28));
      // The tile is 32 pt.
      expect(
        tester.getSize(find.byKey(const Key('file-preview-tile'))),
        const Size(32, 32),
      );
    });

    testWidgets('a button calls its callback', (tester) async {
      var saves = 0;
      await pumpFiles(
        tester,
        FilePreviewHeader(name: 'a.txt', onSave: () => saves++),
        size: const Size(820, 400),
      );

      await tester.tap(find.bySemanticsLabel('Save'));
      expect(saves, 1);
    });

    testWidgets('the More menu offers Open with… and Reload', (tester) async {
      var opened = 0;
      var reloaded = 0;
      await pumpFiles(
        tester,
        FilePreviewHeader(
          name: 'a.txt',
          onOpenWith: () => opened++,
          onReload: () => reloaded++,
        ),
        platform: TargetPlatform.android,
        size: const Size(820, 400),
      );

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.text('Open with…'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(reloaded, 1);
      expect(opened, 0);
    });

    testWidgets('the Mac tile can be wrapped as the drag-out handle', (
      tester,
    ) async {
      var wrapped = 0;
      await pumpFiles(
        tester,
        FilePreviewHeader(
          name: 'a.txt',
          wrapTile: (context, tile) {
            wrapped++;
            return KeyedSubtree(key: const Key('drag'), child: tile);
          },
        ),
        platform: TargetPlatform.macOS,
        size: const Size(820, 400),
      );

      expect(wrapped, greaterThan(0));
      expect(find.byKey(const Key('drag')), findsOneWidget);
      expect(find.byTooltip('Drag to Finder'), findsOneWidget);
    });

    testWidgets('at the largest text the actions drop under the name', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        header(name: _longName),
        textScale: 3,
        size: const Size(820, 1200),
      );

      final title = tester.getRect(find.textContaining('quarterly').first);
      final save = tester.getRect(
        find.ancestor(
          of: find.bySemanticsLabel('Save'),
          matching: find.byType(IconButton),
        ),
      );
      expect(save.top, greaterThan(title.bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the subtitle is German in German', (tester) async {
      await pumpFiles(
        tester,
        header(name: 'export.zip', size: 4404019),
        locale: const Locale('de'),
        size: const Size(820, 400),
      );

      expect(find.text('ZIP-Archiv · 4,2 MB'), findsOneWidget);
      expect(find.bySemanticsLabel('Teilen'), findsOneWidget);
      expect(find.bySemanticsLabel('Speichern'), findsOneWidget);
      expect(find.bySemanticsLabel('Mehr'), findsOneWidget);
    });
  });

  group('previews', () {
    testWidgets('text is selectable monospace on 20 pt lines', (tester) async {
      await pumpFiles(tester, const TextPreview(text: 'one\ntwo'));

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.style?.fontFamily, 'monospace');
      expect(text.style?.fontSize, 13);
      expect(text.style!.fontSize! * text.style!.height!, 20);
    });

    testWidgets('a Mac shows 12 pt text', (tester) async {
      await pumpFiles(
        tester,
        const CodePreview(text: 'x'),
        platform: TargetPlatform.macOS,
      );

      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .style
            ?.fontSize,
        12,
      );
    });

    testWidgets('truncated text shows the note and Download full file', (
      tester,
    ) async {
      var downloads = 0;
      await pumpFiles(
        tester,
        TextPreview(
          text: 'log',
          truncation: const FileTruncation(
            shownBytes: 512 * 1024,
            totalBytes: 3355443,
          ),
          onDownloadFull: () => downloads++,
        ),
      );

      expect(find.text('Showing the first 512 KB of 3.2 MB.'), findsOneWidget);
      expect(find.byType(AppBanner), findsOneWidget);
      await tester.tap(find.text('Download full file'));
      expect(downloads, 1);
    });

    testWidgets('the note is German in German', (tester) async {
      await pumpFiles(
        tester,
        const TextPreview(
          text: 'log',
          truncation: FileTruncation(shownBytes: 524288, totalBytes: 3355443),
        ),
        locale: const Locale('de'),
      );

      expect(
        find.text('Die ersten 512 KB von 3,2 MB werden angezeigt.'),
        findsOneWidget,
      );
      expect(find.text('Ganze Datei herunterladen'), findsOneWidget);
    });

    testWidgets('an untruncated text has no note', (tester) async {
      await pumpFiles(tester, const TextPreview(text: 'log'));

      expect(find.byType(AppBanner), findsNothing);
    });

    testWidgets('at the largest text the note scrolls with the text', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const TextPreview(
          text: 'log',
          truncation: FileTruncation(shownBytes: 524288, totalBytes: 3355443),
        ),
        textScale: 3,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(AppBanner),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Markdown renders and its source is plain text', (
      tester,
    ) async {
      await pumpFiles(tester, const MarkdownPreview(text: '# Title\n\nbody'));
      expect(find.byType(SelectableText), findsNothing);
      expect(find.textContaining('Title', findRichText: true), findsOneWidget);

      await pumpFiles(
        tester,
        const MarkdownPreview(text: '# Title\n\nbody', showSource: true),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('# Title\n\nbody'), findsOneWidget);
    });

    testWidgets('Markdown shows an image\'s alt text and loads nothing', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        const MarkdownPreview(
          text: '![moisture chart](https://example.org/chart.png)\n\n![](img/map.png)',
        ),
      );

      expect(
        find.textContaining('moisture chart', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Image not loaded', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a Markdown link asks "Open example.org?" and opens on Open', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpFiles(
        tester,
        MarkdownPreview(
          text: 'See [the methods](https://example.org/methods).',
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );

      await _tapLink(tester, 'the methods');
      await tester.pumpAndSettle();
      expect(find.text('Open example.org?'), findsOneWidget);
      expect(opened, isEmpty);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://example.org/methods')]);
    });

    testWidgets('Cancel leaves a Markdown link unopened', (tester) async {
      final opened = <Uri>[];
      await pumpFiles(
        tester,
        MarkdownPreview(
          text: 'See [the methods](https://example.org/methods).',
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );

      await _tapLink(tester, 'the methods');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
    });

    testWidgets('a relative Markdown link does nothing, not even a question', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpFiles(
        tester,
        MarkdownPreview(
          text: 'See [the table](./data/table.md).',
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );

      await _tapLink(tester, 'the table');
      await tester.pumpAndSettle();

      expect(find.textContaining('Open '), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('the Rendered / Source switch reports the choice', (
      tester,
    ) async {
      bool? chosen;
      await pumpFiles(
        tester,
        MarkdownModeControl(showSource: false, onChanged: (v) => chosen = v),
        platform: TargetPlatform.android,
      );

      expect(find.text('Rendered'), findsOneWidget);
      await tester.tap(find.text('Source'));
      expect(chosen, isTrue);
    });

    testWidgets('an image shows the picture inside the room with a margin', (
      tester,
    ) async {
      final image = MemoryImage(base64Decode(kFilesSamplePngBase64));
      await tester.runAsync(() async {
        await pumpFiles(
          tester,
          ImagePreview(image: image, label: 'chart.png'),
          size: const Size(390, 600),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      final rect = tester.getRect(find.byType(Image));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(390 - 16));
      expect(find.bySemanticsLabel('chart.png'), findsOneWidget);
    });
  });

  group('inert Markdown', () {
    test('a link names its host, a relative link has none', () {
      expect(markdownLinkHost('https://example.org/a?b=1'), 'example.org');
      expect(markdownLinkHost('http://docs.example.org'), 'docs.example.org');
      expect(markdownLinkHost('mailto:me@example.org'), 'me@example.org');
      expect(markdownLinkHost('mailto:nobody'), isNull);
      expect(markdownLinkHost('./notes.md'), isNull);
      expect(markdownLinkHost('notes.md'), isNull);
      expect(markdownLinkHost('#top'), isNull);
      expect(markdownLinkHost('/etc/hosts'), isNull);
      expect(markdownLinkHost('file:///etc/hosts'), isNull);
      expect(markdownLinkHost('javascript:alert(1)'), isNull);
      expect(markdownLinkHost('hermes://chat'), isNull);
    });

    test('an image becomes its alt text, or the notice without one', () {
      const notLoaded = 'Image not loaded';
      expect(
        inertMarkdown(
          'a ![chart](https://e.org/c.png) b',
          notLoaded: notLoaded,
        ),
        'a chart b',
      );
      expect(
        inertMarkdown('![](img/a.png)', notLoaded: notLoaded),
        '*Image not loaded*',
      );
      expect(
        inertMarkdown(
          '![x](https://e.org/a_(1).png "title")',
          notLoaded: notLoaded,
        ),
        'x',
      );
      expect(
        inertMarkdown('[![logo](u.png)](https://e.org)', notLoaded: notLoaded),
        '[logo](https://e.org)',
      );
      expect(
        inertMarkdown('no images [here](https://e.org)', notLoaded: notLoaded),
        'no images [here](https://e.org)',
      );
    });
  });

  group('FileDetailsView', () {
    Widget details({
      String name = 'export.zip',
      int? size,
      String? note,
      List<FileDetailsAction> secondary = const [],
      VoidCallback? onPrimary,
    }) => FileDetailsView(
      name: name,
      size: size,
      note: note,
      primary: FileDetailsAction(label: 'Save', onPressed: onPrimary),
      secondary: secondary,
    );

    testWidgets('shows a 56 pt icon, the name and the type', (tester) async {
      await pumpFiles(tester, details());

      expect(find.text('export.zip'), findsOneWidget);
      expect(find.text('ZIP archive'), findsOneWidget);
      expect(
        tester.getSize(find.byIcon(FileGlyph.archive.icon.apple)).height,
        56,
      );
    });

    testWidgets('a PDF shows the type and the size once known', (tester) async {
      await pumpFiles(tester, details(name: 'invoice-2026.pdf', size: 2516582));

      expect(find.text('PDF document · 2.4 MB'), findsOneWidget);
    });

    testWidgets('the note line and one filled and outlined buttons', (
      tester,
    ) async {
      var saves = 0;
      var shares = 0;
      await pumpFiles(
        tester,
        details(
          note: 'This file is too large to open here.',
          onPrimary: () => saves++,
          secondary: [
            FileDetailsAction(label: 'Share', onPressed: () => shares++),
          ],
        ),
      );

      expect(find.text('This file is too large to open here.'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Share'));
      expect((saves, shares), (1, 1));
    });

    testWidgets('buttons are full width up to 320 pt and 44 pt high', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        details(
          secondary: [FileDetailsAction(label: 'Share', onPressed: () {})],
        ),
        size: const Size(900, 700),
      );

      for (final type in [FilledButton, OutlinedButton]) {
        final size = tester.getSize(find.byType(type));
        expect(size.width, 272); // 320 less its 24 pt padding on both sides
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('buttons are 48 dp on Android and 28 pt on a Mac', (
      tester,
    ) async {
      await pumpFiles(tester, details(), platform: TargetPlatform.android);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );

      await pumpFiles(tester, details(), platform: TargetPlatform.macOS);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(28),
      );
    });

    testWidgets('at the largest text it scrolls and cuts nothing off', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        details(
          name: _longName,
          size: 4404019,
          note: 'This file is too large to open here.',
          secondary: [FileDetailsAction(label: 'Share', onPressed: () {})],
        ),
        textScale: 3,
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Share'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);
    });
  });

  group('FileDownloadProgress', () {
    testWidgets('with a length shows a bar and "14 of 30 MB"', (tester) async {
      var cancels = 0;
      await pumpFiles(
        tester,
        FileDownloadProgress(
          received: 14 * 1024 * 1024,
          total: 30 * 1024 * 1024,
          onCancel: () => cancels++,
        ),
      );

      expect(find.text('Downloading… 14 of 30 MB'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(14 / 30, 0.001));
      await tester.tap(find.text('Cancel'));
      expect(cancels, 1);
    });

    testWidgets('without a length shows a spinner and "Downloaded 12 MB"', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        FileDownloadProgress(received: 12 * 1024 * 1024, onCancel: () {}),
      );

      expect(find.text('Downloaded 12 MB'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('the status is a live region with the words as its label', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        FileDownloadProgress(
          received: 14 * 1024 * 1024,
          total: 30 * 1024 * 1024,
          onCancel: () {},
        ),
      );

      expect(
        find.semantics.byLabel('Downloading… 12 of 30 MB'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Downloading… 14 of 30 MB')),
        isA<SemanticsNode>().having(
          (n) => n.flagsCollection.isLiveRegion,
          'live region',
          isTrue,
        ),
      );
    });

    testWidgets('holds the spinner still under reduced motion', (tester) async {
      await pumpFiles(
        tester,
        FileDownloadProgress(received: 1024, onCancel: () {}),
        reduceMotion: true,
      );

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNotNull,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is German in German, with Cancel at 44 pt', (tester) async {
      await pumpFiles(
        tester,
        FileDownloadProgress(
          received: 14 * 1024 * 1024,
          total: 30 * 1024 * 1024,
          onCancel: () {},
        ),
        locale: const Locale('de'),
      );

      expect(find.text('Wird heruntergeladen … 14 von 30 MB'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('file failures', () {
    for (final (problem, title, action) in [
      (FileProblem.notShared, "Hermes doesn't share this file.", null),
      (FileProblem.gone, 'This file no longer exists.', null),
      (
        FileProblem.busy,
        'This file is open in a database right now. Try again in a moment.',
        'Try again',
      ),
      (FileProblem.notAFile, "This item can't be opened as a file.", null),
      (FileProblem.couldntOpen, "Couldn't open this file.", 'Try again'),
      (FileProblem.incomplete, 'The file may be incomplete.', 'Try again'),
    ]) {
      testWidgets('${problem.name} says "$title"', (tester) async {
        var retries = 0;
        await pumpFiles(
          tester,
          FilePreviewFailure(problem: problem, onTryAgain: () => retries++),
        );

        expect(find.text(title), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        if (action == null) {
          expect(find.byType(OutlinedButton), findsNothing);
        } else {
          await tester.tap(find.text(action));
          expect(retries, 1);
        }
      });
    }

    testWidgets('an incomplete download says nothing was kept', (tester) async {
      await pumpFiles(
        tester,
        const FilePreviewFailure(problem: FileProblem.incomplete),
      );

      expect(
        find.text(
          'The connection dropped while it downloaded. Nothing was kept.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the failure is German in German and a live region', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        FilePreviewFailure(problem: FileProblem.gone, onTryAgain: () {}),
        locale: const Locale('de'),
      );

      expect(find.text('Diese Datei existiert nicht mehr.'), findsOneWidget);
      expect(find.semantics.byFlag(SemanticsFlag.isLiveRegion), findsWidgets);
    });
  });

  group('notes', () {
    testWidgets('the shared banner carries every note, neutral or warning', (
      tester,
    ) async {
      await pumpFiles(
        tester,
        Column(
          children: [
            const FilesServerFolderNote(),
            FilesTruncatedNote(
              shownBytes: 512 * 1024,
              totalBytes: 3355443,
              onDownloadFull: () {},
            ),
            FilesOfflineBanner(onRetry: () {}),
          ],
        ),
        size: const Size(390, 1200),
      );

      final banners = tester.widgetList<AppBanner>(find.byType(AppBanner));
      expect(banners.map((b) => b.tone), [
        AppBannerTone.neutral,
        AppBannerTone.neutral,
        AppBannerTone.warning,
      ]);
    });
  });

  group('FilePreviewCover', () {
    testWidgets('shows only the type icon, with no name and no text', (
      tester,
    ) async {
      await pumpFiles(tester, const FilePreviewCover(glyph: FileGlyph.code));

      expect(find.byIcon(FileGlyph.code.icon.apple), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.bySemanticsLabel('File preview hidden'), findsOneWidget);
    });

    testWidgets('each kind has its own icon', (tester) async {
      final icons = {
        for (final glyph in FileGlyph.values) glyph.icon.apple.codePoint,
      };

      expect(icons, hasLength(FileGlyph.values.length));
    });
  });

  group('metrics', () {
    for (final (platform, row, target) in [
      (TargetPlatform.iOS, 44.0, 44.0),
      (TargetPlatform.android, 56.0, 48.0),
      (TargetPlatform.macOS, 32.0, 28.0),
    ]) {
      testWidgets('on $platform rows are $row and targets $target', (
        tester,
      ) async {
        late FilesMetrics metrics;
        await pumpFiles(
          tester,
          Builder(
            builder: (context) {
              metrics = FilesMetrics.of(context);
              return const SizedBox();
            },
          ),
          platform: platform,
        );

        expect((metrics.rowMinHeight, metrics.target), (row, target));
      });
    }
  });
}

/// Taps the link whose text is [label] in a rendered Markdown view.
Future<void> _tapLink(WidgetTester tester, String label) async {
  final finder = find.textContaining(label, findRichText: true);
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderParagraph>(finder);
  final text = box.text.toPlainText();
  final offset = text.indexOf(label);
  final boxes = box.getBoxesForSelection(
    TextSelection(baseOffset: offset, extentOffset: offset + label.length),
  );
  final target = box.localToGlobal(boxes.first.toRect().center);
  await tester.tapAt(target);
}
