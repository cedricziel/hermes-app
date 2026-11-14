import 'dart:io';

import 'package:flutter/foundation.dart';

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
        'a.exe\u00a0',
        'a.exe\u3000',
        'a.exe\u2028',
        'a.chm',
        'a.xll',
        'a.ws',
        'a.wsc',
        'a.vb',
        'a.scf',
        'a.application',
        'a.appref-ms',
        'a.settingcontent-ms',
        'a.website',
        'a.diagcab',
        'a.iso',
        'a.rdp',
        'a.msu',
        'a.mst',
        'a.ps1xml',
        'a.psd1',
        'a.psc1',
        'a.msh',
        'a.msh1',
        'a.msh2',
        'a.mshxml',
        'a.gadget',
        'a.library-ms',
        'a.search-ms',
        'a.searchconnector-ms',
        'a.wsb',
        'a.py',
        'a.pyw',
        'a.pyz',
        'a.mde',
        'a.ade',
        'a.adp',
        'a.accde',
        'a.hlp',
        'a.shb',
        'a.shs',
        'a.xbap',
        'a.cab',
        'a.img',
        'a.vhd',
        'a.vhdx',
        '/srv/dir/evil.EXE',
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
        // Cut when staged, so what is opened has no extension left.
        '${'x' * 176}.exe.${'a' * 20}',
      ]) {
        expect(windows.canOpenWith(name), isTrue, reason: name);
      }
    });

    test('what the machine runs by name (PATHEXT) is blocked too', () {
      final policy = FilesPlatformPolicy(
        windows: true,
        mark: (_) async {},
        environment: {'PATHEXT': '.COM;.EXE;.PL;.RB'},
      );
      expect(policy.canOpenWith('a.pl'), isFalse);
      expect(policy.canOpenWith('a.RB'), isFalse);
      expect(policy.canOpenWith('a.txt'), isTrue);
    });

    test('other platforms keep it for everything', () {
      expect(const FilesPlatformPolicy.none().canOpenWith('a.exe'), isTrue);
      expect(FilesPlatformPolicy(windows: false).canOpenWith('a.bat'), isTrue);
    });
  });

  group('the controller with no policy given', () {
    test('blocks and marks on Windows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final source = FakeFilesSource();
      final cache = tempDir('files_default_policy');
      final actions = FakeMediaActions();
      final media = MediaStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        actions: actions,
      );
      source.lists['/srv/p'] = () =>
          listing([file('/srv/p/setup.exe'), file('/srv/p/doc.pdf')]);
      source.gitRoots['/srv/p'] = () => ok(null);
      source.downloads['/srv/p/doc.pdf'] = writes([1], length: 1);
      source.downloads['/srv/p/setup.exe'] = writes([1], length: 1);
      final controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
      );
      addTearDown(controller.dispose);
      await controller.start();

      await controller.select(controller.entries.first);
      expect(controller.canOpenWith(controller.entries.first), isFalse);
      await controller.openWith();
      expect(actions.opened, isEmpty);

      await controller.select(controller.entries.last);
      await controller.openWith();
      final opened = actions.opened.single;
      expect(File('$opened:Zone.Identifier').existsSync(), isTrue);
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

    test('the mark is written before every open', () async {
      final events = <String>[];
      final ordered = _OrderedActions(events);
      media = MediaStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        actions: ordered,
      );
      final controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
        policy: FilesPlatformPolicy(
          windows: true,
          mark: (file) async => events.add('mark'),
        ),
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.select(controller.entries.last);
      events.clear();
      await controller.openWith();
      await controller.openWith();

      expect(events.where((e) => e == 'open'), hasLength(2));
      for (var i = 0; i < events.length; i++) {
        if (events[i] == 'open') {
          expect(events[i - 1], 'mark', reason: 'before the open at $i');
        }
      }
    });

    test('a hostile name is saved under its staged name', () async {
      source.lists['/srv/p'] = () => listing([file('/srv/p/fdp\u202eexe.pdf')]);
      source.downloads['/srv/p/fdp\u202eexe.pdf'] = writes([1], length: 1);
      final controller = build();
      await controller.start();
      await controller.select(controller.entries.single);
      await controller.save();

      expect(actions.savedFiles.single.name, isNot(contains('\u202e')));
      expect(actions.savedFiles.single.name, 'fdp_exe.pdf');
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

class _OrderedActions extends FakeMediaActions {
  _OrderedActions(this.events);

  final List<String> events;

  @override
  Future<bool> open(String path) {
    events.add('open');
    return super.open(path);
  }
}
