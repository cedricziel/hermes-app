import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_glyph.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/file_size.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/files/widgets/files_preview_body.dart';
import 'package:hermes_app/src/files/widgets/folder_pick_list.dart';

import 'files_widget_harness.dart';

/// The user-visible strings of the Files screen that no other widget test
/// reads, in English and in German, with their screen-reader labels.
void main() {
  group('strings no other test reads', () {
    for (final (locale, note, empty, reading, code, one, many) in [
      (
        'en',
        "This chat hasn't started yet, so Hermes shows the server's own "
            "folder. After your first message it shows this chat's folder.",
        'No folders in here.',
        'Opening file…',
        'Source code',
        '1 byte',
        '512 bytes',
      ),
      (
        'de',
        null,
        'Keine Ordner hier.',
        'Datei wird geöffnet…',
        'Quelltext',
        '1 Byte',
        '512 Byte',
      ),
    ]) {
      testWidgets('the server folder note, $locale', (tester) async {
        await pumpFiles(
          tester,
          const FilesServerFolderNote(),
          locale: Locale(locale),
        );
        final l10n = l10nFor(locale);
        expect(find.text(l10n.filesNoteServerFolderTitle), findsOneWidget);
        expect(find.text(l10n.filesNoteServerFolderDetail), findsOneWidget);
        if (note != null) expect(find.text(note), findsOneWidget);
      });

      testWidgets('an empty folder picker, $locale', (tester) async {
        await pumpFiles(
          tester,
          FolderPickList(
            rows: [FileRowModel(name: 'notes.txt', isFolder: false)],
            onTap: (_) {},
          ),
          locale: Locale(locale),
        );
        expect(find.text(empty), findsOneWidget);
      });

      testWidgets('a file being read is announced, $locale', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpFiles(
          tester,
          const FilesPreviewBody(model: FilesPreviewLoading()),
          locale: Locale(locale),
        );
        expect(find.bySemanticsLabel(reading), findsOneWidget);
        handle.dispose();
      });

      test('the type word of source code and byte sizes, $locale', () {
        final l10n = l10nFor(locale);
        expect(fileTypeLabel(l10n, 'main.c'), code);
        expect(l10n.filesTypeCode, code);
        expect(formatByteSize(l10n, 1), one);
        expect(formatByteSize(l10n, 512), many);
      });
    }
  });

  group('screen-reader labels', () {
    testWidgets('rows say what they are', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFiles(
        tester,
        Column(
          children: [
            FileRow(
              model: const FileRowModel(name: 'src', isFolder: true),
              onTap: () {},
            ),
            FileRow(
              model: const FileRowModel(name: 'app.py', isFolder: false),
              onTap: () {},
            ),
            FileRow(
              model: const FileRowModel(
                name: '.env',
                isFolder: false,
                looksSecret: true,
              ),
              onTap: () {},
            ),
          ],
        ),
      );
      expect(find.bySemanticsLabel('src, folder'), findsOneWidget);
      expect(find.bySemanticsLabel('app.py, file'), findsOneWidget);
      expect(
        find.bySemanticsLabel('.env, file, may contain secrets'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
