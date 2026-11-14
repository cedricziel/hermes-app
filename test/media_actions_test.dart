import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/file_export.dart';
import 'package:hermes_app/src/chat/media/media_actions.dart';

import 'support/attachment_fixtures.dart';

void main() {
  group('desktop save', () {
    test('copies the file to the chosen place on disk', () async {
      final dir = tempDir('save_desktop');
      final source = writeTemp(dir, 'big.bin', List.filled(64, 7));
      final target = '${dir.path}/chosen.bin';
      String? asked;
      final actions = PlatformMediaActions(
        export: FileExport(
          mobile: false,
          pickDestination: (name) async {
            asked = name;
            return target;
          },
        ),
      );

      expect(await actions.saveFile('export.bin', source), isTrue);
      expect(asked, 'export.bin');
      expect(File(target).readAsBytesSync(), List.filled(64, 7));
    });

    test(
      'copies onto the chosen file only, with no sibling temp file',
      () async {
        final dir = tempDir('save_direct');
        final source = writeTemp(dir, 'a.bin', [5, 6]);
        final target = '${dir.path}/chosen.bin';
        final actions = PlatformMediaActions(
          export: FileExport(
            mobile: false,
            pickDestination: (_) async => target,
          ),
        );

        await actions.saveFile('x', source);

        expect(File(target).readAsBytesSync(), [5, 6]);
        expect(dir.listSync().map((e) => e.path).toSet(), {
          source.path,
          target,
        });
      },
    );

    test('a failing copy leaves no temp file and keeps the old file', () async {
      final dir = tempDir('save_atomic');
      final target = File('${dir.path}/chosen.bin')..writeAsBytesSync([1]);
      final actions = PlatformMediaActions(
        export: FileExport(
          mobile: false,
          pickDestination: (_) async => target.path,
        ),
      );

      await expectLater(
        actions.saveFile('x', File('${dir.path}/missing.bin')),
        throwsA(anything),
      );
      expect(target.readAsBytesSync(), [1]);
      expect(dir.listSync().map((e) => e.path), [target.path]);
    });

    test('cancelling copies nothing', () async {
      final dir = tempDir('save_cancel');
      final source = writeTemp(dir, 'a.bin', [1]);
      final actions = PlatformMediaActions(
        export: FileExport(mobile: false, pickDestination: (_) async => null),
      );
      expect(await actions.saveFile('a.bin', source), isFalse);
      expect(dir.listSync().length, 1);
    });
  });

  group('mobile save', () {
    test('hands the dialog the file path, not its bytes', () async {
      final dir = tempDir('save_mobile');
      final source = writeTemp(dir, 'a.zip', [1, 2, 3]);
      ({String name, String path})? got;
      final actions = PlatformMediaActions(
        export: FileExport(
          mobile: true,
          exportFromPath: (name, path) async {
            got = (name: name, path: path);
            return '/saved/$name';
          },
        ),
      );

      expect(await actions.saveFile('a.zip', source), isTrue);
      expect(got, (name: 'a.zip', path: source.path));
    });

    test('a cancelled dialog is not a save', () async {
      final dir = tempDir('save_mobile_cancel');
      final source = writeTemp(dir, 'a.zip', [1]);
      final actions = PlatformMediaActions(
        export: FileExport(mobile: true, exportFromPath: (_, _) async => null),
      );
      expect(await actions.saveFile('a.zip', source), isFalse);
    });
  });
}
