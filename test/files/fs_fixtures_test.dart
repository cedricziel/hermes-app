import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/hermes_files_repository.dart';
import 'package:hermes_app/src/files/server_path.dart';

import '../support/fake_hermes_server.dart';

/// The answers a real Hermes gave to `/api/fs/*` (see the fixture's note),
/// served by the fake and read by the repository.
final _cases =
    ((jsonDecode(File('test/fixtures/files/fs_routes.json').readAsStringSync())
                as Map<String, Object?>)['cases']!
            as Map)
        .cast<String, Map<String, Object?>>();

ServerPath _p(String text) => ServerPath.tryParse(text)!;

void main() {
  late FakeHermesServer server;
  late HermesFilesRepository files;

  /// Serves the recorded answer of [name] on its route.
  void serve(String name) {
    final c = _cases[name]!;
    final request = (c['request']! as Map).cast<String, Object?>();
    server.on(
      'GET',
      request['route']! as String,
      c['body'],
      status: c['status']! as int,
    );
  }

  T ok<T>(FilesResult<T> result) {
    expect(result, isA<FilesOk<T>>(), reason: '$result');
    return (result as FilesOk<T>).value;
  }

  FilesFailure failure<T>(FilesResult<T> result) {
    expect(result, isA<FilesFailed<T>>(), reason: '$result');
    return (result as FilesFailed<T>).kind;
  }

  setUp(() {
    server = FakeHermesServer();
    files = HermesFilesRepository(server.client(), profile: 'default')
      ..highestFolder = _p('/srv/demo');
  });

  test('the fixture holds every case these tests name', () {
    expect(
      _cases.keys,
      containsAll([
        'list_folder',
        'list_through_symlink',
        'list_empty',
        'list_missing',
        'list_file',
        'list_profile_missing',
        'list_profile_invalid',
        'read_text_markdown',
        'read_text_truncated',
        'read_text_binary',
        'read_text_directory',
        'read_text_symlinked_folder',
        'read_text_secret',
        'read_text_missing',
        'read_text_live_database',
        'download_markdown',
        'download_secret',
        'download_missing',
        'download_directory',
        'download_live_database',
        'default_cwd',
        'default_cwd_named_profile',
        'default_cwd_profile_missing',
        'git_root_inside',
        'git_root_outside',
        'git_root_missing_path',
        'locked_list_outside',
        'locked_list_inside',
        'locked_read_text_outside',
        'locked_read_text_secret',
        'locked_default_cwd',
        'locked_git_root',
      ]),
    );
  });

  group('list', () {
    test('a folder lists directories first, shows a symlinked folder as a '
        'file and keeps dot entries', () async {
      serve('list_folder');
      final listing = ok(await files.list(_p('/srv/demo/proj')));
      final byName = {for (final e in listing.entries) e.name: e};
      expect(listing.skipped, 0);
      expect(listing.entries.map((e) => e.name).take(4), [
        '.hiddendir',
        'empty',
        'real',
        'src',
      ]);
      expect(byName['link']!.isDirectory, isFalse, reason: 'the symlink');
      expect(byName['.dotnote'], isNotNull);
      for (final hidden in ['.git', '.env', 'node_modules']) {
        expect(byName, isNot(contains(hidden)));
      }
    });

    test('a symlink path lists its target, whose entries carry the resolved '
        'path', () async {
      serve('list_through_symlink');
      final listing = ok(await files.list(_p('/srv/demo/proj/link')));
      expect(listing.entries.map((e) => e.name), ['inside.txt']);
      expect(
        listing.entries.single.path.value,
        '/srv/demo/proj/real/inside.txt',
      );
      expect(listing.skipped, 0);
    });

    test('an empty folder is a listing, not a failure', () async {
      serve('list_empty');
      expect(ok(await files.list(_p('/srv/demo/proj/empty'))).entries, isEmpty);
    });

    test('a missing folder and a file are failures (HTTP 200 with error)', () {
      serve('list_missing');
      return files
          .list(_p('/srv/demo/proj/nope'))
          .then((r) {
            expect(failure(r), FilesFailure.missing);
            serve('list_file');
            return files.list(_p('/srv/demo/proj/README.md'));
          })
          .then((r) => expect(failure(r), FilesFailure.notAFile));
    });

    test('a profile the server does not have, or that is not a valid name, '
        'is badRequest', () async {
      serve('list_profile_missing');
      expect(
        failure(await files.list(_p('/srv/demo/proj'))),
        FilesFailure.badRequest,
      );
      serve('list_profile_invalid');
      expect(
        failure(await files.list(_p('/srv/demo/proj'))),
        FilesFailure.badRequest,
      );
    });
  });

  group('readText', () {
    test('reads a text file with its language', () async {
      serve('read_text_markdown');
      final text = ok(await files.readText(_p('/srv/demo/proj/README.md')));
      expect(text.text, 'hi\n');
      expect(text.language, 'markdown');
      expect(text.truncated, isFalse);
      expect(text.binary, isFalse);
    });

    test('knows a truncated file and its full size', () async {
      serve('read_text_truncated');
      final text = ok(await files.readText(_p('/srv/demo/proj/big.txt')));
      expect(text.truncated, isTrue);
      expect(text.byteSize, 750000);
    });

    test('flags a binary file although the server still sends text', () async {
      serve('read_text_binary');
      final text = ok(await files.readText(_p('/srv/demo/proj/blob.bin')));
      expect(text.binary, isTrue);
      expect(text.byteSize, 2000);
    });

    test('maps each refusal to its kind', () async {
      final kinds = {
        'read_text_directory': FilesFailure.notAFile,
        'read_text_symlinked_folder': FilesFailure.notAFile,
        'read_text_secret': FilesFailure.notAllowed,
        'read_text_missing': FilesFailure.missing,
        'read_text_live_database': FilesFailure.busy,
      };
      for (final MapEntry(:key, :value) in kinds.entries) {
        serve(key);
        expect(
          failure(await files.readText(_p('/srv/demo/proj/x'))),
          value,
          reason: key,
        );
      }
    });
  });

  group('default-cwd and git-root', () {
    test('the start folder and the repository root', () async {
      serve('default_cwd');
      expect(ok(await files.defaultCwd()).value, '/srv/demo/launch');

      serve('git_root_inside');
      expect(
        ok(await files.gitRoot(_p('/srv/demo/proj/src')))?.value,
        '/srv/demo/proj',
      );
      serve('git_root_outside');
      expect(ok(await files.gitRoot(_p('/srv/demo/plain'))), isNull);
    });

    test('a named profile still gets the launch folder, not its own', () async {
      serve('default_cwd_named_profile');
      expect(ok(await files.defaultCwd()).value, '/srv/demo/launch');
    });

    test('a profile the server does not have is badRequest', () async {
      serve('default_cwd_profile_missing');
      expect(failure(await files.defaultCwd()), FilesFailure.badRequest);
    });
  });

  group('a deployment locked to one folder', () {
    // No highest folder yet: the first read is the one the server refuses.
    late HermesFilesRepository any;
    setUp(
      () => any = HermesFilesRepository(server.client(), profile: 'default'),
    );

    test('outside the root is fixedFolder on list and read-text, inside '
        'lists', () async {
      serve('locked_list_outside');
      expect(
        failure(await any.list(_p('/srv/elsewhere'))),
        FilesFailure.fixedFolder,
      );
      serve('locked_read_text_outside');
      expect(
        failure(await any.readText(_p('/srv/elsewhere/x.txt'))),
        FilesFailure.fixedFolder,
      );
      serve('locked_read_text_secret');
      expect(
        failure(await any.readText(_p('/srv/locked/inside/.env'))),
        FilesFailure.fixedFolder,
        reason: 'a secret name in the root reads as outside it',
      );
      serve('locked_list_inside');
      final listing = ok(await any.list(_p('/srv/locked/inside')));
      expect(listing.entries.map((e) => e.name), ['a.txt']);
    });

    test('the start folder and git-root still answer', () async {
      serve('locked_default_cwd');
      expect(ok(await any.defaultCwd()).value, '/srv/demo/launch');
      serve('locked_git_root');
      expect(ok(await any.gitRoot(_p('/srv/demo/x'))), isNull);
    });
  });

  test('the recorded download headers name the file and its length', () {
    final ok = _cases['download_markdown']!;
    final headers = (ok['headers']! as Map).cast<String, String>();
    expect(headers['content-length'], '3');
    expect(headers['content-disposition'], 'attachment; filename="README.md"');
  });

  test('a download maps each recorded refusal to its kind', () async {
    final temp = Directory.systemTemp.createTempSync('fs_fixture_download');
    addTearDown(() => temp.deleteSync(recursive: true));
    final kinds = {
      'download_live_database': FilesFailure.busy,
      'download_secret': FilesFailure.notAllowed,
      'download_missing': FilesFailure.missing,
      'download_directory': FilesFailure.notAFile,
    };
    for (final MapEntry(:key, :value) in kinds.entries) {
      serve(key);
      final sink = File('${temp.path}/$key').openWrite();
      final result = await files.download(_p('/srv/demo/proj/x'), sink: sink);
      await sink.close();
      expect(failure(result), value, reason: key);
    }
  });
}
