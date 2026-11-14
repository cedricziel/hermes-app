import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/files/files_controller.dart';
import 'package:hermes_app/src/files/files_platform_policy.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_files_source.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';

void main() {
  group('Open with on Windows', () {
    final windows = FilesPlatformPolicy(windows: true, mark: (_) async {});

    test('is never offered for a file that runs', () {
      for (final name in [
        'setup.exe',
        'a.BAT',
        'run.cmd',
        'x.msi',
        'x.ps1',
        'x.vbs',
        'x.js',
        'x.lnk',
        'x.hta',
        'x.reg',
        'x.jar',
        'a.exe.',
        'a.exe ',
        'archive.tar.exe',
      ]) {
        expect(windows.canOpenWith(name), isFalse, reason: name);
      }
    });

    test('stays for documents, images, archives and extensionless names', () {
      for (final name in [
        'a.pdf',
        'a.png',
        'a.zip',
        'a.exe.txt',
        'Makefile',
        '.env',
        'a.json',
      ]) {
        expect(windows.canOpenWith(name), isTrue, reason: name);
      }
    });

    test('other platforms keep it for everything', () {
      expect(const FilesPlatformPolicy.none().canOpenWith('a.exe'), isTrue);
      expect(FilesPlatformPolicy(windows: false).canOpenWith('a.bat'), isTrue);
    });
  });

  group('the controller on Windows', () {
    late FakeFilesSource source;
    late Directory cache;
    late FakeMediaActions actions;
    late MediaStore media;
    final marked = <String>[];
    var markFails = false;

    FilesController build() {
      final controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
        policy: FilesPlatformPolicy(
          windows: true,
          mark: (file) async {
            if (markFails) throw const FileSystemException('no streams');
            marked.add(file.path);
          },
        ),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    setUp(() {
      source = FakeFilesSource();
      cache = tempDir('files_windows');
      actions = FakeMediaActions();
      media = MediaStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        actions: actions,
      );
      marked.clear();
      markFails = false;
      source.lists['/srv/p'] = () =>
          listing([file('/srv/p/setup.exe'), file('/srv/p/doc.pdf')]);
      source.gitRoots['/srv/p'] = () => ok(null);
      source.downloads['/srv/p/setup.exe'] = writes([1], length: 1);
      source.downloads['/srv/p/doc.pdf'] = writes([1, 2], length: 2);
    });

    test('an executable is not opened and not even downloaded', () async {
      final controller = build();
      await controller.start();
      final exe = controller.entries.first;
      await controller.select(exe);
      expect(controller.canOpenWith(exe), isFalse);

      await controller.openWith();

      expect(actions.opened, isEmpty);
      expect(source.count('download'), 0);
    });

    test('a downloaded file carries the mark before it is opened', () async {
      final controller = build();
      await controller.start();
      await controller.select(controller.entries.last);
      await controller.openWith();

      expect(marked, isNotEmpty);
      expect(actions.opened, hasLength(1));
      expect(marked.last, actions.opened.single);
    });

    test('a file that cannot be marked is not opened', () async {
      markFails = true;
      final controller = build();
      await controller.start();
      await controller.select(controller.entries.last);
      await controller.openWith();

      expect(actions.opened, isEmpty);
    });
  });
}
