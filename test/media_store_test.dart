import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/media/quick_look.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';
import 'support/fake_quick_look.dart';

void main() {
  late FakeHermesServer server;
  late Directory cache;
  late FakeMediaActions actions;
  late FakeQuickLook quickLook;

  MediaStore newStore({int imageBudget = 1 << 20}) => MediaStore(
    source: HermesMediaSource(() => server.client()),
    cacheDirectory: () async => cache,
    actions: actions,
    quickLook: quickLook,
    imageBudget: imageBudget,
  );

  setUp(() {
    server = FakeHermesServer();
    cache = tempDir('media_store');
    actions = FakeMediaActions();
    quickLook = FakeQuickLook();
  });

  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 fake'));

  int downloads() => server.requestsTo('GET', '/api/files/download').length;

  List<FileSystemEntity> filesUnder(Directory dir) => dir.existsSync()
      ? dir.listSync(recursive: true).whereType<File>().toList()
      : [];

  group('image', () {
    void serveImage(String path, {Uint8List? bytes}) => server.on(
      'GET',
      '/api/media',
      {'data_url': 'data:image/png;base64,${base64Encode(bytes ?? kTinyPng)}'},
      query: {'path': path},
    );

    test('is fetched once for the same path', () async {
      serveImage('/srv/a.png');
      final store = newStore();

      expect(await store.image('/srv/a.png'), kTinyPng);
      expect(await store.image('/srv/a.png'), kTinyPng);

      expect(server.requestsTo('GET', '/api/media'), hasLength(1));
    });

    test('is fetched once when two widgets ask at the same time', () async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/media', (_) async {
        await gate.future;
        return (
          status: 200,
          body: {'data_url': 'data:image/png;base64,${base64Encode(kTinyPng)}'},
        );
      });
      final store = newStore();

      final first = store.image('/srv/a.png');
      final second = store.image('/srv/a.png');
      gate.complete();

      expect(await first, kTinyPng);
      expect(await second, kTinyPng);
      expect(server.requestsTo('GET', '/api/media'), hasLength(1));
    });

    test('a failure is not remembered', () async {
      server.on('GET', '/api/media', {'detail': 'x'}, status: 500);
      final store = newStore();

      await expectLater(
        store.image('/srv/a.png'),
        throwsA(isA<MediaFetchException>()),
      );
      serveImage('/srv/a.png');

      expect(await store.image('/srv/a.png'), kTinyPng);
    });

    test('drops the least recently used image over its budget', () async {
      final big = Uint8List(600);
      for (final name in ['a', 'b', 'c']) {
        serveImage('/srv/$name.png', bytes: big);
      }
      final store = newStore(imageBudget: 1500);

      await store.image('/srv/a.png');
      await store.image('/srv/b.png');
      await store.image('/srv/a.png'); // a is now newer than b
      await store.image('/srv/c.png'); // over budget: b goes
      await store.image('/srv/a.png');
      await store.image('/srv/b.png');

      final fetched = server
          .requestsTo('GET', '/api/media')
          .map((r) => r.queryParameters['path'])
          .toList();
      expect(fetched, ['/srv/a.png', '/srv/b.png', '/srv/c.png', '/srv/b.png']);
    });
  });

  group('file', () {
    void serveFile(String path, [Uint8List? bytes]) => server.on(
      'GET',
      '/api/files/download',
      bytes ?? pdf,
      query: {'path': path},
    );

    test('is written under the cache directory with its name', () async {
      serveFile('/srv/report.pdf');
      final store = newStore();

      final file = await store.file('/srv/report.pdf', 'report.pdf');

      expect(file.path, startsWith(cache.path));
      expect(file.path, endsWith('/report.pdf'));
      expect(file.readAsBytesSync(), pdf);
    });

    test('is downloaded once, then reused', () async {
      serveFile('/srv/report.pdf');
      final store = newStore();

      final first = await store.file('/srv/report.pdf', 'report.pdf');
      final second = await store.file('/srv/report.pdf', 'report.pdf');

      expect(second.path, first.path);
      expect(downloads(), 1);
    });

    test('is downloaded once when asked twice at the same time', () async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (status: 200, body: pdf);
      });
      final store = newStore();

      final first = store.file('/srv/report.pdf', 'report.pdf');
      final second = store.file('/srv/report.pdf', 'report.pdf');
      gate.complete();

      expect((await first).path, (await second).path);
      expect(downloads(), 1);
    });

    test('keeps two files of the same name apart', () async {
      serveFile('/one/notes.txt', Uint8List.fromList([1]));
      serveFile('/two/notes.txt', Uint8List.fromList([2]));
      final store = newStore();

      final one = await store.file('/one/notes.txt', 'notes.txt');
      final two = await store.file('/two/notes.txt', 'notes.txt');

      expect(one.path, isNot(two.path));
      expect(one.readAsBytesSync(), [1]);
      expect(two.readAsBytesSync(), [2]);
    });

    test('cannot be written outside the cache by its name', () async {
      serveFile('/srv/x');
      final store = newStore();

      final file = await store.file('/srv/x', '../../evil.sh');

      expect(file.path, startsWith(cache.path));
      expect(file.path, isNot(contains('..')));
      expect(file.path, isNot(endsWith('/')));
    });

    test(
      'a failed download leaves nothing behind and can be retried',
      () async {
        server.on('GET', '/api/files/download', {'detail': 'x'}, status: 500);
        final store = newStore();

        await expectLater(
          store.file('/srv/report.pdf', 'report.pdf'),
          throwsA(
            isA<MediaFetchException>().having(
              (e) => e.reason,
              'reason',
              MediaFailure.failed,
            ),
          ),
        );
        expect(filesUnder(cache), isEmpty);

        serveFile('/srv/report.pdf');
        final file = await store.file('/srv/report.pdf', 'report.pdf');
        expect(file.readAsBytesSync(), pdf);
      },
    );
  });

  group('clear', () {
    test('deletes the downloaded files and forgets the images', () async {
      server.on('GET', '/api/files/download', pdf);
      server.on('GET', '/api/media', {
        'data_url': 'data:image/png;base64,${base64Encode(kTinyPng)}',
      });
      final store = newStore();
      await store.file('/srv/report.pdf', 'report.pdf');
      await store.image('/srv/a.png');
      expect(filesUnder(cache), hasLength(1));

      await store.clear();

      expect(filesUnder(cache), isEmpty);
      await store.image('/srv/a.png');
      await store.file('/srv/report.pdf', 'report.pdf');
      expect(server.requestsTo('GET', '/api/media'), hasLength(2));
      expect(downloads(), 2);
    });

    test('deletes what an earlier run left in the cache', () async {
      final leftover = Directory('${cache.path}/hermes_media/abc')
        ..createSync(recursive: true);
      File('${leftover.path}/old.pdf').writeAsBytesSync([1]);

      await newStore().clear();

      expect(filesUnder(cache), isEmpty);
    });

    test('does nothing when nothing was ever downloaded', () async {
      await newStore().clear();
    });

    test('a download that finishes afterwards is not kept', () async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (status: 200, body: pdf);
      });
      final store = newStore();

      final pending = store.file('/srv/report.pdf', 'report.pdf');
      final outcome = expectLater(pending, throwsA(isA<MediaFetchException>()));
      await Future<void>.delayed(Duration.zero);
      await store.clear();
      gate.complete();
      await outcome;

      expect(filesUnder(cache), isEmpty);
    });

    test('runs when the account signs out', () async {
      server.on('GET', '/api/files/download', pdf);
      final signedOut = StreamController<void>.broadcast(sync: true);
      addTearDown(signedOut.close);
      final store = newStore()..clearOnSignOut(signedOut.stream);
      await store.file('/srv/report.pdf', 'report.pdf');

      signedOut.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(filesUnder(cache), isEmpty);
      store.dispose();
    });
  });

  group('stage', () {
    test('shares the folder rule and the in-flight fetch with file', () async {
      final gate = Completer<void>();
      var fetches = 0;
      final store = newStore();

      Future<Uint8List> fetch() async {
        fetches++;
        await gate.future;
        return pdf;
      }

      final first = store.stage('kanban:ops:3', '../../x', fetch);
      final second = store.stage('kanban:ops:3', '../../x', fetch);
      gate.complete();

      expect((await first).path, (await second).path);
      expect(fetches, 1);
      expect((await first).path, startsWith('${cache.path}/hermes_media/'));
      expect((await first).path, isNot(contains('..')));
      expect((await first).readAsBytesSync(), pdf);
    });

    test('an error from the fetch reaches the caller as it is', () async {
      final store = newStore();

      await expectLater(
        store.stage('k', 'a.pdf', () async => throw StateError('nope')),
        throwsStateError,
      );
      expect(filesUnder(cache), isEmpty);
      expect(
        (await store.stage('k', 'a.pdf', () async => pdf)).readAsBytesSync(),
        pdf,
      );
    });

    test('a clear during the fetch leaves no file', () async {
      final gate = Completer<void>();
      final store = newStore();

      final pending = store.stage('k', 'a.pdf', () async {
        await gate.future;
        return pdf;
      });
      final outcome = expectLater(pending, throwsA(isA<MediaFetchException>()));
      await Future<void>.delayed(Duration.zero);
      await store.clear();
      gate.complete();
      await outcome;

      expect(filesUnder(cache), isEmpty);
    });

    test('stageBytes writes the bytes inside the media folder', () async {
      final file = await newStore().stageBytes('m1:0', 'a.png', kTinyPng);

      expect(file.path, startsWith('${cache.path}/hermes_media/'));
      expect(file.readAsBytesSync(), kTinyPng);
    });

    test('stageCopy copies a file from elsewhere into the folder', () async {
      final picked = writeTemp(tempDir('picked'), 'notes.txt', [1, 2, 3]);
      final store = newStore();

      final file = await store.stageCopy('notes.txt', picked);

      expect(file.path, startsWith('${cache.path}/hermes_media/'));
      expect(file.readAsBytesSync(), [1, 2, 3]);
      expect(file.path, isNot(picked.path));
    });

    test('stageCopy copies again when the file changed', () async {
      final picked = writeTemp(tempDir('picked'), 'notes.txt', [1]);
      final store = newStore();
      await store.stageCopy('notes.txt', picked);

      picked.writeAsBytesSync([9, 9]);
      final again = await store.stageCopy('notes.txt', picked);

      expect(again.readAsBytesSync(), [9, 9]);
    });

    test('reuse marks the file as used just now', () async {
      final store = newStore();
      final file = await store.stageBytes('k', 'a.pdf', pdf);
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 3)),
      );

      await store.stageBytes('k', 'a.pdf', pdf);

      expect(
        DateTime.now().difference(file.lastModifiedSync()),
        lessThan(const Duration(minutes: 1)),
      );
    });

    test('two stores over one folder can fill the same file at once', () async {
      final big = Uint8List(2 * 1024 * 1024);
      final stores = [newStore(), newStore(), newStore()];

      final files = await Future.wait([
        for (final store in stores) store.stageBytes('k', 'a.bin', big),
      ]);

      expect(files.map((f) => f.path).toSet(), hasLength(1));
      expect(files.first.lengthSync(), big.length);
      expect(
        cache
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    });

    test('a very long name is cut and keeps its extension', () async {
      final file = await newStore().stageBytes('k', '${'x' * 400}.pdf', pdf);

      expect(file.uri.pathSegments.last.length, lessThan(200));
      expect(file.path, endsWith('.pdf'));
      expect(file.existsSync(), isTrue);
    });

    test('a long name of wide characters is cut by bytes', () async {
      final file = await newStore().stageBytes('k', '${'é' * 300}.txt', pdf);

      expect(file.uri.pathSegments.last.length, lessThan(200));
      expect(file.existsSync(), isTrue);
    });

    test('stageCopy of a file that is gone is missing', () async {
      await expectLater(
        newStore().stageCopy('x.txt', File('${cache.path}/nothing.txt')),
        throwsA(
          isA<MediaFetchException>().having(
            (e) => e.reason,
            'reason',
            MediaFailure.missing,
          ),
        ),
      );
    });

    test('a file downloaded for open is reused by the preview', () async {
      server.on('GET', '/api/files/download', pdf);
      final store = newStore();
      final opened = await store.file('/srv/report.pdf', 'report.pdf');

      final again = await store.file('/srv/report.pdf', 'report.pdf');
      expect(
        await store.showQuickLook(again, toggle: false),
        QuickLookToggle.shown,
      );

      expect(downloads(), 1);
      expect(quickLook.shown, opened.path);
    });
  });

  group('sweep', () {
    File aged(String folder, String name, Duration age) {
      final file = File('${cache.path}/hermes_media/$folder/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      file.setLastModifiedSync(DateTime.now().subtract(age));
      return file;
    }

    test('deletes only what is older than the limit', () async {
      final old = aged('a', 'old.pdf', const Duration(days: 2));
      final fresh = aged('b', 'fresh.pdf', const Duration(hours: 1));

      await newStore().sweep(const Duration(hours: 24));

      expect(old.existsSync(), isFalse);
      expect(old.parent.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('leaves a file that was reused after it was downloaded', () async {
      final store = newStore();
      final file = await store.stageBytes('k', 'a.pdf', pdf);
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 3)),
      );
      await store.stageBytes('k', 'a.pdf', pdf);

      await store.sweep(const Duration(hours: 24));

      expect(file.existsSync(), isTrue);
    });

    test('leaves a file that is asked for while it runs', () async {
      final store = newStore();
      final file = await store.stageBytes('k', 'a.pdf', pdf);
      file.setLastModifiedSync(
        DateTime.now().subtract(const Duration(days: 3)),
      );

      final sweeping = store.sweep(const Duration(hours: 24));
      final reused = store.stageBytes('k', 'a.pdf', pdf);
      await Future.wait([sweeping, reused]);

      expect(file.existsSync(), isTrue);
    });

    test('does not remove the folder of a download in progress', () async {
      final gate = Completer<void>();
      final store = newStore();
      final pending = store.stage('k', 'a.pdf', () async {
        await gate.future;
        return pdf;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await store.sweep(const Duration(hours: 24));
      gate.complete();

      expect((await pending).existsSync(), isTrue);
    });

    test('does nothing when nothing was ever cached', () async {
      await newStore().sweep(const Duration(hours: 24));
    });
  });

  group('quick look', () {
    test('clear closes the panel', () async {
      final store = newStore();
      await store.showQuickLook(File('${cache.path}/a.pdf'), toggle: false);

      await store.clear();

      expect(quickLook.closes, 1);
      expect(quickLook.shown, isNull);
    });

    test('sign-out closes the panel too', () async {
      final signedOut = StreamController<void>.broadcast(sync: true);
      addTearDown(signedOut.close);
      final store = newStore()..clearOnSignOut(signedOut.stream);

      signedOut.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(quickLook.closes, 1);
      store.dispose();
    });
  });

  group('actions', () {
    test('open and save go to the system', () async {
      final store = newStore();

      expect(await store.open(File('/x/report.pdf')), isTrue);
      expect(await store.save('report.pdf', pdf), isTrue);

      expect(actions.opened, ['/x/report.pdf']);
      expect(actions.saved.single.name, 'report.pdf');
    });
  });
}
