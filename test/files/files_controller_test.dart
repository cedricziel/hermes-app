import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/files/files_controller.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/files_state.dart';
import 'package:hermes_app/src/files/files_telemetry.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_files_source.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/recording_tracer.dart';

const _mb = 1024 * 1024;

/// A store whose [evict] can be held back, to open the window between a
/// request deciding to evict and the eviction ending.
class _GatedEvictStore extends MediaStore {
  _GatedEvictStore({
    required super.source,
    required super.cacheDirectory,
    required super.actions,
  });

  Completer<void>? gate;
  var evicts = 0;

  @override
  Future<void> evict(String key) async {
    evicts++;
    final held = gate;
    if (held != null) await held.future;
    await super.evict(key);
  }
}

void main() {
  late FakeFilesSource source;
  late Directory cache;
  late FakeMediaActions actions;
  late MediaStore media;
  late BreadcrumbTrail trail;
  late RecordingTracer tracer;
  late FilesController controller;
  var notified = 0;

  FilesController build({String? cwd = '/srv/p', Duration? timeout}) {
    controller = FilesController(
      source: source,
      media: media,
      profile: 'work',
      cwd: cwd == null ? null : p(cwd),
      openedFrom: FilesOpenedFrom.header,
      answerTimeout: timeout ?? kFilesAnswerTimeout,
      telemetry: FilesTelemetry(
        ConnectionTelemetry(tracer: tracer, serverAttributes: const {}),
        Breadcrumbs.of(trail),
      ),
    )..addListener(() => notified++);
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    source = FakeFilesSource();
    cache = tempDir('files_controller');
    actions = FakeMediaActions();
    media = MediaStore(
      source: HermesMediaSource(() => FakeHermesServer().client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
    trail = BreadcrumbTrail();
    tracer = RecordingTracer();
    notified = 0;
  });

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  List<File> cached() => cache.existsSync()
      ? cache.listSync(recursive: true).whereType<File>().toList()
      : [];

  /// `/srv/p` with [entries], and no git root.
  void folder(List<FsEntry> entries, {String at = '/srv/p', String? git}) {
    source.lists[at] = () => listing(entries);
    source.gitRoots[at] = () => ok<ServerPath?>(git == null ? null : p(git));
  }

  group('start folder', () {
    test('lists the stored cwd and never asks for default-cwd', () async {
      folder([folderEntry('/srv/p/reports'), file('/srv/p/a.txt')]);
      await build().start();

      expect(controller.folderState, isA<FolderReady>());
      expect(controller.entries.map((e) => e.name), ['reports', 'a.txt']);
      expect(controller.folder!.value, '/srv/p');
      expect(controller.startedFromServerDefault, isFalse);
      expect(source.count('defaultCwd'), 0);
    });

    test('a new chat starts at default-cwd for its profile', () async {
      source.onDefaultCwd = () => ok(p('/srv/default'));
      folder([file('/srv/default/x.txt')], at: '/srv/default');
      await build(cwd: null).start();

      expect(controller.folder!.value, '/srv/default');
      expect(controller.startedFromServerDefault, isTrue);
      expect(controller.entries, hasLength(1));
    });

    test('a default-cwd failure is a failure the page can retry', () async {
      source.onDefaultCwd = () => failed(FilesFailure.unreachable);
      await build(cwd: null).start();
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.unreachable,
      );

      source.onDefaultCwd = () => ok(p('/srv/default'));
      folder([], at: '/srv/default');
      await controller.refresh();
      expect(controller.folderState, isA<FolderReady>());
    });

    test('a failed first listing is shown with its kind', () async {
      source.lists['/srv/p'] = () => failed(FilesFailure.missing);
      source.gitRoots['/srv/p'] = () => ok<ServerPath?>(null);
      await build().start();
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.missing,
      );
      expect(controller.canGoUp, isFalse);
    });
  });

  group('highest folder', () {
    setUp(() {
      source.lists['/srv/p/app/sub'] = () =>
          listing([file('/srv/p/app/sub/a.txt')]);
      source.gitRoots['/srv/p/app/sub'] = () => ok<ServerPath?>(p('/srv/p'));
      source.lists['/srv/p/app'] = () =>
          listing([folderEntry('/srv/p/app/sub')]);
      source.lists['/srv/p'] = () => listing([folderEntry('/srv/p/app')]);
    });

    test('is the git root; Up stops there', () async {
      await build(cwd: '/srv/p/app/sub').start();
      expect(controller.root!.value, '/srv/p');
      expect(source.highestFolder!.value, '/srv/p');
      expect(controller.canGoUp, isTrue);

      await controller.up();
      expect(controller.folder!.value, '/srv/p/app');
      await controller.up();
      expect(controller.folder!.value, '/srv/p');
      expect(controller.canGoUp, isFalse);

      final before = source.calls.length;
      await controller.up();
      expect(source.calls.length, before, reason: 'Up at the top asks nothing');
    });

    test('is the working folder without a git root', () async {
      source.gitRoots['/srv/p/app/sub'] = () => ok<ServerPath?>(null);
      await build(cwd: '/srv/p/app/sub').start();
      expect(controller.root!.value, '/srv/p/app/sub');
      expect(controller.canGoUp, isFalse);
    });

    test(
      'is the working folder when git-root fails or is no ancestor',
      () async {
        source.gitRoots['/srv/p/app/sub'] = () =>
            failed(FilesFailure.unreachable);
        await build(cwd: '/srv/p/app/sub').start();
        expect(controller.root!.value, '/srv/p/app/sub');

        source.gitRoots['/srv/p/app/sub'] = () =>
            ok<ServerPath?>(p('/elsewhere'));
        await controller.refresh();
        expect(controller.root!.value, '/srv/p/app/sub');
      },
    );

    test('is the folder the server resolved, not the stored text', () async {
      source.lists['/tmp/p'] = () => listing([file('/private/tmp/p/a.txt')]);
      source.gitRoots['/tmp/p'] = () => ok<ServerPath?>(null);
      await build(cwd: '/tmp/p').start();

      expect(controller.folderState, isA<FolderReady>());
      expect(controller.entries.single.name, 'a.txt');
      expect(controller.root!.value, '/private/tmp/p');
      expect(controller.folder!.value, '/private/tmp/p');
    });

    test('uses the git root the server resolved too', () async {
      source.lists['/tmp/p'] = () => listing([file('/private/tmp/p/a.txt')]);
      source.gitRoots['/tmp/p'] = () => ok<ServerPath?>(p('/private/tmp'));
      await build(cwd: '/tmp/p').start();
      expect(controller.root!.value, '/private/tmp');
      expect(controller.canGoUp, isTrue);
    });

    test('a listing with every row outside is not shown as empty', () async {
      await build(cwd: '/srv/p/app/sub').start();
      source.lists['/srv/p/app'] = () => Future.value(
        const FilesOk(FsListing(entries: [], skipped: 2, skippedOutside: 2)),
      );
      await controller.up();
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.outside,
      );
    });

    test('a folder outside is refused without a request', () async {
      await build(cwd: '/srv/p/app/sub').start();
      final before = source.calls.length;
      await controller.openFolder(folderEntry('/srv/p-secrets/key'));
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.outside,
      );
      expect(source.calls.length, before);
    });
  });

  group('symlink to a folder', () {
    setUp(() => folder([file('/srv/p/link'), file('/srv/p/a.zip')]));

    test('a 400 on a text read lists it as a folder, once', () async {
      source.texts['/srv/p/link.txt'] = () => failed(FilesFailure.notAFile);
      folder([file('/srv/p/link.txt')]);
      source.lists['/srv/p/link.txt'] = () =>
          listing([file('/srv/p/link.txt/x')]);
      await build().start();

      await controller.select(controller.entries.single);
      expect(controller.folder!.value, '/srv/p/link.txt');
      expect(source.count('list /srv/p/link.txt'), 1);
      expect(controller.preview, isA<PreviewIdle>());

      // The same row again does not loop.
      await controller.up();
      await controller.select(controller.entries.single);
      expect(controller.preview, isA<PreviewFailed>());
      expect((controller.preview as PreviewFailed).kind, FilesFailure.notAFile);
      expect(source.count('list /srv/p/link.txt'), 1);
    });

    test('the SSH 400 on an image download takes the same road', () async {
      folder([file('/srv/p/shots.png')]);
      source.downloads['/srv/p/shots.png'] = (_, _, _, _) =>
          failed(FilesFailure.notAFile);
      source.lists['/srv/p/shots.png'] = () => listing([]);
      await build().start();
      await controller.select(controller.entries.single);
      expect(controller.folder!.value, '/srv/p/shots.png');
      expect(cached(), isEmpty);
    });

    test('a link whose folder lies outside asks nothing more', () async {
      source.lists['/srv/p'] = () => listing([
        FsEntry(name: 'out', path: p('/srv/p/out'), isDirectory: false),
      ]);
      await build().start();
      // The server resolved the link elsewhere: the row's path is outside.
      final outside = FsEntry(
        name: 'lnk.txt',
        path: p('/mnt/other/lnk.txt'),
        isDirectory: false,
      );
      source.texts['/mnt/other/lnk.txt'] = () => failed(FilesFailure.notAFile);
      final before = source.count('list');
      await controller.select(outside);
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.outside,
      );
      expect(source.count('list'), before);
    });
  });

  group('late answers', () {
    test('a folder the user left is dropped', () async {
      folder([folderEntry('/srv/p/a'), folderEntry('/srv/p/b')]);
      final a = Completer<FilesResult<FsListing>>();
      source.lists['/srv/p/a'] = () => a.future;
      source.lists['/srv/p/b'] = () => listing([file('/srv/p/b/b.txt')]);
      await build().start();

      final rows = controller.entries;
      final openA = controller.openFolder(rows[0]);
      await controller.openFolder(rows[1]);
      a.complete(FilesOk(FsListing(entries: [file('/srv/p/a/a.txt')])));
      await openA;

      expect(controller.folder!.value, '/srv/p/b');
      expect(controller.entries.single.name, 'b.txt');
    });

    test('a file the user left is dropped', () async {
      folder([file('/srv/p/a.txt'), file('/srv/p/b.txt')]);
      final a = Completer<FilesResult<FsTextFile>>();
      source.texts['/srv/p/a.txt'] = () => a.future;
      source.texts['/srv/p/b.txt'] = () =>
          ok(const FsTextFile(text: 'bee', byteSize: 3));
      await build().start();

      final openA = controller.select(controller.entries[0]);
      await controller.select(controller.entries[1]);
      a.complete(const FilesOk(FsTextFile(text: 'ay', byteSize: 2)));
      await openA;

      expect((controller.preview as PreviewText).file.text, 'bee');
    });

    test('answers after the page ended change nothing', () async {
      folder([folderEntry('/srv/p/a'), file('/srv/p/b.txt')]);
      final list = Completer<FilesResult<FsListing>>();
      final text = Completer<FilesResult<FsTextFile>>();
      source.lists['/srv/p/a'] = () => list.future;
      source.texts['/srv/p/b.txt'] = () => text.future;
      await build().start();

      final rows = controller.entries;
      final f1 = controller.openFolder(rows[0]);
      final f2 = controller.select(rows[1]);
      controller.cancelAll(); // a profile switch, sign-out or server change
      final seen = notified;
      list.complete(FilesOk(FsListing(entries: [file('/srv/p/a/x.txt')])));
      text.complete(const FilesOk(FsTextFile(text: 't', byteSize: 1)));
      await f1;
      await f2;

      expect(notified, seen);
      expect(controller.entries, isEmpty);
    });
  });

  group('lost answers', () {
    test('a listing ends in a failure after 10 s and is never resent', () {
      fakeAsync((async) {
        folder([]);
        source.lists['/srv/p'] = () =>
            Completer<FilesResult<FsListing>>().future;
        build().start();
        async.elapse(const Duration(seconds: 9));
        expect(controller.folderState, isA<FolderLoading>());
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(
          (controller.folderState as FolderFailed).kind,
          FilesFailure.unreachable,
        );
        async.elapse(const Duration(minutes: 5));
        expect(source.count('list'), 1);

        // Only the user's Try again asks again.
        source.lists['/srv/p'] = () => listing([file('/srv/p/a.txt')]);
        controller.refresh();
        async.flushMicrotasks();
        expect(controller.folderState, isA<FolderReady>());
        expect(source.count('list'), 2);
      });
    });

    test('a file read ends in a failure after 10 s and is never resent', () {
      fakeAsync((async) {
        folder([file('/srv/p/a.txt')]);
        source.texts['/srv/p/a.txt'] = () =>
            Completer<FilesResult<FsTextFile>>().future;
        build().start();
        async.flushMicrotasks();
        controller.select(controller.entries.single);
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(
          (controller.preview as PreviewFailed).kind,
          FilesFailure.unreachable,
        );
        async.elapse(const Duration(minutes: 5));
        expect(source.count('readText'), 1);
      });
    });

    test('a refresh that gets no answer keeps the list, marked stale', () {
      fakeAsync((async) {
        folder([file('/srv/p/a.txt')]);
        build().start();
        async.flushMicrotasks();
        source.lists['/srv/p'] = () =>
            Completer<FilesResult<FsListing>>().future;
        controller.refresh();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(controller.stale, isTrue);
        expect(controller.entries, hasLength(1));
        expect(controller.folderState, isA<FolderReady>());
      });
    });
  });

  group('hidden files', () {
    test(
      'are listed only after the toggle, and the toggle is a crumb',
      () async {
        folder([file('/srv/p/.gitignore'), file('/srv/p/notes.md')]);
        await build().start();
        expect(controller.entries.map((e) => e.name), ['notes.md']);
        expect(controller.hasHiddenEntries, isTrue);

        controller.toggleHidden();
        expect(controller.entries.map((e) => e.name), [
          '.gitignore',
          'notes.md',
        ]);
        expect(controller.hasHiddenEntries, isFalse);
        controller.toggleHidden();

        final crumbs = trail.recent.where(
          (c) => c.name == 'files.hidden.toggled',
        );
        expect(crumbs.map((c) => c.attributes['on']), [true, false]);
      },
    );

    test(
      'only the first 2,000 rows are shown, and the count is known',
      () async {
        folder([for (var i = 0; i < 2300; i++) file('/srv/p/f$i.txt')]);
        await build().start();
        expect(controller.shownEntries, hasLength(kFilesMaxRows));
        expect(controller.entryCount, 2300);
      },
    );
  });

  group('refresh', () {
    test(
      'keeps the selection while the file exists, drops it when gone',
      () async {
        folder([file('/srv/p/a.txt'), file('/srv/p/b.txt')]);
        source.texts['/srv/p/a.txt'] = () =>
            ok(const FsTextFile(text: 'a', byteSize: 1));
        await build().start();
        await controller.select(controller.entries.first);

        await controller.refresh();
        expect(controller.selected?.name, 'a.txt');
        expect(controller.preview, isA<PreviewText>());

        source.lists['/srv/p'] = () => listing([file('/srv/p/b.txt')]);
        await controller.refresh();
        expect(controller.selected, isNull);
        expect(controller.preview, isA<PreviewIdle>());
      },
    );

    test('a failed refresh leaves the list under a banner', () async {
      folder([file('/srv/p/a.txt')]);
      await build().start();
      source.lists['/srv/p'] = () => failed(FilesFailure.unreachable);
      await controller.refresh();
      expect(controller.stale, isTrue);
      expect(controller.entries, hasLength(1));
    });
  });

  group('text preview', () {
    setUp(() => folder([file('/srv/p/app.py'), file('/srv/p/big.log')]));

    test('reads the text with its size', () async {
      source.texts['/srv/p/app.py'] = () => ok(
        const FsTextFile(text: 'print(1)', byteSize: 1834, language: 'python'),
      );
      await build().start();
      await controller.select(controller.entries.first);
      final text = controller.preview as PreviewText;
      expect(text.file.byteSize, 1834);
      expect(text.file.language, 'python');
      expect(text.kind.name, 'code');
    });

    test('413 offers the file as an other file with Save', () async {
      source.texts['/srv/p/big.log'] = () => failed(FilesFailure.tooLarge);
      await build().start();
      await controller.select(controller.entries.last);
      final details = controller.preview as PreviewDetails;
      expect(details.tooLargeForText, isTrue);
      expect(source.count('download'), 0, reason: 'only Save downloads');
    });

    test('binary after all is an other file', () async {
      folder([file('/srv/p/data.txt')]);
      source.texts['/srv/p/data.txt'] = () =>
          ok(const FsTextFile(text: '', byteSize: 9, binary: true));
      await build().start();
      await controller.select(controller.entries.single);
      expect((controller.preview as PreviewDetails).kind.name, 'other');
      expect(source.count('download'), 0);
    });

    test('statuses become failure kinds the page words', () async {
      for (final kind in [
        FilesFailure.notAllowed,
        FilesFailure.missing,
        FilesFailure.busy,
      ]) {
        source.texts['/srv/p/app.py'] = () => failed(kind);
        await build().start();
        await controller.select(controller.entries.first);
        expect((controller.preview as PreviewFailed).kind, kind);
      }
    });
  });

  group('secret-looking names', () {
    setUp(
      () => folder([
        file('/srv/p/.env.local'),
        file('/srv/p/key.pem'),
        file('/srv/p/secrets.txt'),
      ]),
    );

    test('ask before any request, and Cancel requests nothing', () async {
      await build().start();
      controller.toggleHidden();
      await controller.select(controller.entries.first);
      expect(controller.preview, isA<PreviewConfirmSecret>());
      controller.declineSecret();
      expect(controller.preview, isA<PreviewIdle>());
      expect(
        source.calls.where(
          (c) => !c.startsWith('list') && !c.startsWith('gitRoot'),
        ),
        isEmpty,
      );
    });

    test('Continue runs the normal preview', () async {
      source.texts['/srv/p/secrets.txt'] = () =>
          ok(const FsTextFile(text: 'A=1', byteSize: 3));
      await build().start();
      controller.toggleHidden();
      await controller.select(controller.entries.last);
      await controller.confirmSecret();
      expect(controller.preview, isA<PreviewText>());
      expect(source.count('readText'), 1);
    });

    test('a secret asks even for a file that is only details', () async {
      await build().start();
      await controller.select(controller.entries.last);
      expect(controller.preview, isA<PreviewConfirmSecret>());
      expect(source.count('download'), 0);
    });

    test(
      'a copy fetched after Continue is deleted when the preview closes',
      () async {
        folder([file('/srv/p/token.png')]);
        source.downloads['/srv/p/token.png'] = writes([1, 2], length: 2);
        await build().start();
        await controller.select(controller.entries.single);
        await controller.confirmSecret();
        expect(controller.preview, isA<PreviewImage>());
        expect(cached(), hasLength(1));

        controller.closePreview();
        await until(() => cached().isEmpty);
      },
    );

    test('the question is a breadcrumb without the name', () async {
      await build().start();
      await controller.select(controller.entries.first);
      final crumb = trail.recent.singleWhere(
        (c) => c.name == 'files.secret.warned',
      );
      expect(crumb.attributes, isEmpty);
    });
  });

  group('downloads', () {
    setUp(
      () => folder([
        file('/srv/p/chart.png'),
        file('/srv/p/report.pdf'),
        file('/srv/p/export.zip'),
      ]),
    );

    test('PDFs and other files download nothing until an action', () async {
      await build().start();
      await controller.select(controller.entries[1]);
      await controller.select(controller.entries[2]);
      expect(controller.preview, isA<PreviewDetails>());
      expect(source.count('download'), 0);
      expect(source.count('readText'), 0);
    });

    test('Save downloads, then opens the save dialog with the name', () async {
      source.downloads['/srv/p/export.zip'] = writes([1, 2, 3], length: 3);
      await build().start();
      await controller.select(controller.entries[2]);
      await controller.save();

      expect(actions.savedFiles.single.name, 'export.zip');
      expect(File(actions.savedFiles.single.path).readAsBytesSync(), [1, 2, 3]);
      expect(controller.preview, isA<PreviewDetails>());
      final crumb = trail.recent.singleWhere((c) => c.name == 'files.saved');
      expect(crumb.attributes, {'action': 'save'});
    });

    test('Open with and Share go through the staged file', () async {
      source.downloads['/srv/p/export.zip'] = writes([1], length: 1);
      final shared = <String>[];
      controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
        share: (f) async => shared.add(f.path),
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.select(controller.entries[2]);
      await controller.openWith();
      await controller.shareFile();

      expect(actions.opened, hasLength(1));
      expect(shared, hasLength(1));
      expect(source.count('download'), 1, reason: 'the second use is cached');
    });

    test('a cancelled save saves nothing and says nothing', () async {
      actions.saves = false;
      source.downloads['/srv/p/export.zip'] = writes([1], length: 1);
      await build().start();
      await controller.select(controller.entries[2]);
      await controller.save();
      expect(trail.recent.where((c) => c.name == 'files.saved'), isEmpty);
    });

    test('the size question comes from headers, 50 MB and up', () async {
      source.downloads['/srv/p/chart.png'] = (sink, token, allow, progress) {
        if (!allow) {
          return ok(
            const FsDownload(
              bytes: 0,
              contentLength: 212 * _mb,
              declined: true,
            ),
          );
        }
        sink.add([1]);
        return ok(const FsDownload(bytes: 1, contentLength: 212 * _mb));
      };
      await build().start();
      await controller.select(controller.entries.first);
      expect((controller.preview as PreviewConfirmSize).bytes, 212 * _mb);
      expect(cached(), isEmpty);

      await controller.confirmSize();
      expect(source.count('download'), 2);
      expect(controller.preview, isA<PreviewImage>());
    });

    test('declining the size question keeps the details', () async {
      source.downloads['/srv/p/chart.png'] = (sink, token, allow, progress) =>
          ok(
            const FsDownload(bytes: 0, contentLength: 60 * _mb, declined: true),
          );
      await build().start();
      await controller.select(controller.entries.first);
      controller.declineSize();
      final details = controller.preview as PreviewDetails;
      expect(details.size, 60 * _mb);
      expect(source.count('download'), 1);
    });

    test('an unknown length asks no size question', () async {
      source.downloads['/srv/p/chart.png'] = writes([1, 2], length: null);
      await build().start();
      await controller.select(controller.entries.first);
      expect(controller.preview, isA<PreviewImage>());
    });

    test('progress reaches the preview while it downloads', () async {
      final gate = Completer<void>();
      source.downloads['/srv/p/chart.png'] =
          (sink, token, allow, progress) async {
            progress!(10, 100);
            await gate.future;
            sink.add([1]);
            return const FilesOk(FsDownload(bytes: 1, contentLength: 100));
          };
      await build().start();
      final opening = controller.select(controller.entries.first);
      await until(
        () =>
            controller.preview is PreviewLoading &&
            (controller.preview as PreviewLoading).received == 10,
      );
      gate.complete();
      await opening;
    });

    test(
      'Cancel deletes the partial file and returns to the details',
      () async {
        final gate = Completer<void>();
        source.downloads['/srv/p/chart.png'] = holds(gate);
        await build().start();
        final opening = controller.select(controller.entries.first);
        await until(() => source.count('download') == 1);
        await until(() => cached().any((f) => f.path.endsWith('.part')));

        controller.cancelDownload();
        await opening;

        expect(controller.preview, isA<PreviewDetails>());
        expect(cached(), isEmpty);
      },
    );

    test('a failed download leaves nothing and says why', () async {
      source.downloads['/srv/p/chart.png'] =
          (sink, token, allow, progress) async {
            sink.add([1, 2]);
            return const FilesFailed(FilesFailure.unreachable);
          };
      await build().start();
      await controller.select(controller.entries.first);
      expect(
        (controller.preview as PreviewFailed).kind,
        FilesFailure.unreachable,
      );
      expect(cached(), isEmpty);
    });

    test('a cached file is reused, and Reload fetches it again', () async {
      var version = 0;
      source.downloads['/srv/p/chart.png'] = (sink, token, allow, progress) {
        sink.add([++version]);
        return ok(FsDownload(bytes: 1, contentLength: 1));
      };
      await build().start();
      await controller.select(controller.entries.first);
      expect((controller.preview as PreviewImage).file.readAsBytesSync(), [1]);

      await controller.select(controller.entries.first);
      expect(source.count('download'), 1);

      await controller.reload();
      expect(source.count('download'), 2);
      expect((controller.preview as PreviewImage).file.readAsBytesSync(), [2]);
    });

    test('profile switch and dispose cancel and delete everything', () async {
      for (final end in [
        () => controller.cancelAll(),
        () => controller.dispose(),
      ]) {
        final gate = Completer<void>();
        source = FakeFilesSource();
        folder([file('/srv/p/chart.png')]);
        source.downloads['/srv/p/chart.png'] = holds(gate);
        await build().start();
        final opening = controller.select(controller.entries.single);
        await until(() => cached().any((f) => f.path.endsWith('.part')));

        end();
        await opening;
        await until(() => cached().isEmpty);
        expect(
          gate.isCompleted,
          isFalse,
          reason: 'ended by cancel, not by data',
        );
      }
    });
  });

  group('SSH downloads (no Content-Length)', () {
    setUp(() => folder([file('/srv/p/app.py')]));

    Future<void> fullFile(int bytes) async {
      source.texts['/srv/p/app.py'] = () =>
          ok(const FsTextFile(text: 'x', byteSize: 100, truncated: true));
      source.downloads['/srv/p/app.py'] = writes(List.filled(bytes, 7));
      await build().start();
      await controller.select(controller.entries.single);
      await controller.save();
    }

    test('an empty body for a file with a known size is a failure', () async {
      await fullFile(0);
      expect(
        (controller.preview as PreviewFailed).kind,
        FilesFailure.unreadable,
      );
      expect(cached(), isEmpty);
      expect(actions.savedFiles, isEmpty);
    });

    test('a short body is a failure', () async {
      await fullFile(40);
      expect(
        (controller.preview as PreviewFailed).kind,
        FilesFailure.unreadable,
      );
      expect(cached(), isEmpty);
    });

    test('a body as long as read-text said is kept', () async {
      await fullFile(100);
      expect(actions.savedFiles, hasLength(1));
    });

    test(
      'is not remembered as complete: the next open downloads again',
      () async {
        folder([file('/srv/p/chart.png')]);
        source.downloads['/srv/p/chart.png'] = writes([1, 2]);
        await build().start();
        await controller.select(controller.entries.single);
        controller.closePreview();
        await controller.select(controller.entries.single);
        expect(source.count('download'), 2);
      },
    );
  });

  group('telemetry', () {
    test('spans and crumbs carry no path, name, profile or content', () async {
      const secrets = ['quarterly-plan', 'hunter2', 'work', '/srv/p'];
      folder([
        file('/srv/p/quarterly-plan.md'),
        file('/srv/p/quarterly-plan.png'),
        file('/srv/p/secrets.txt'),
      ]);
      source.texts['/srv/p/quarterly-plan.md'] = () =>
          ok(const FsTextFile(text: 'hunter2', byteSize: 7));
      source.downloads['/srv/p/quarterly-plan.png'] = writes([1], length: 1);
      source.texts['/srv/p/secrets.txt'] = () =>
          ok(const FsTextFile(text: 'hunter2', byteSize: 7));
      await build().start();
      controller.toggleHidden();
      final rows = controller.entries;
      await controller.select(rows[0]);
      await controller.select(rows[1]);
      await controller.select(rows[2]);
      await controller.confirmSecret();

      final spans = tracer.spans
          .where((s) => s.name == 'files.preview')
          .toList();
      expect(spans, hasLength(3));
      for (final span in spans) {
        expect(span.ended, isTrue);
        expect(
          span.attributes.keys.toSet().difference({'kind', 'outcome', 'size'}),
          isEmpty,
        );
        expect(span.attributes['outcome'], 'ok');
      }
      expect(spans.map((s) => s.attributes['kind']), [
        'markdown',
        'image',
        'text',
      ]);
      expect(spans.first.attributes['size'], '<100KB');

      final names = trail.recent.map((c) => c.name).toSet();
      expect(
        names,
        containsAll({
          'files.opened',
          'files.preview.opened',
          'files.secret.warned',
          'files.hidden.toggled',
        }),
      );
      final everything = [
        for (final c in trail.recent) ...[
          c.name,
          ...c.attributes.keys,
          ...c.attributes.values.map((v) => '$v'),
        ],
        for (final s in tracer.spans) ...[
          s.name,
          ...s.attributes.keys,
          ...s.attributes.values.map((v) => '$v'),
        ],
      ].join(' ');
      for (final secret in secrets) {
        expect(everything, isNot(contains(secret)));
      }
      expect(
        trail.recent.singleWhere((c) => c.name == 'files.opened').attributes,
        {'source': 'header'},
      );
    });

    test('a failed preview ends its span as failed', () async {
      folder([file('/srv/p/a.txt')]);
      source.texts['/srv/p/a.txt'] = () => failed(FilesFailure.missing);
      await build().start();
      await controller.select(controller.entries.single);
      final span = tracer.spans.singleWhere((s) => s.name == 'files.preview');
      expect(span.attributes['outcome'], 'failed');
      expect(span.ended, isTrue);
    });

    test('a throwing tracer never reaches the page', () async {
      folder([file('/srv/p/a.txt')]);
      source.texts['/srv/p/a.txt'] = () =>
          ok(const FsTextFile(text: 't', byteSize: 1));
      controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
        telemetry: FilesTelemetry(
          ConnectionTelemetry(tracer: ThrowingTracer()),
        ),
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.select(controller.entries.single);
      expect(controller.preview, isA<PreviewText>());
    });
  });
  group('first listing and the highest folder', () {
    test('an empty folder reached through a link is provisional', () async {
      source.lists['/tmp/p'] = () => listing([]);
      source.gitRoots['/tmp/p'] = () => ok<ServerPath?>(null);
      await build(cwd: '/tmp/p').start();
      expect(controller.entries, isEmpty);
      expect(controller.canGoUp, isFalse);

      // The agent writes a file; the server lists the resolved folder.
      source.lists['/tmp/p'] = () => listing([file('/private/tmp/p/a.txt')]);
      await controller.refresh();

      expect(controller.folderState, isA<FolderReady>());
      expect(controller.entries.single.name, 'a.txt');
      expect(controller.root!.value, '/private/tmp/p');
      expect(controller.folder!.value, '/private/tmp/p');
      expect(source.highestFolder!.value, '/private/tmp/p');
    });

    test('an empty folder takes the git root that answered', () async {
      folder([], at: '/srv/p/app', git: '/srv/p');
      await build(cwd: '/srv/p/app').start();
      expect(controller.root!.value, '/srv/p');
      expect(controller.canGoUp, isTrue);
    });

    test('a first listing with rows in different folders is refused', () async {
      folder([file('/srv/p/a.txt'), file('/etc/passwd')]);
      await build().start();
      expect(
        (controller.folderState as FolderFailed).kind,
        FilesFailure.unreadable,
      );
      expect(controller.root, isNull);
      expect(controller.entries, isEmpty);
    });

    test('rows at the filesystem root do not widen the page to /', () async {
      folder([file('/a.txt'), file('/b.txt')]);
      await build().start();
      expect(controller.folderState, isA<FolderFailed>());
      expect(controller.root, isNull);
    });

    test('a start folder that is the root may list the root', () async {
      folder([file('/a.txt')], at: '/');
      await build(cwd: '/').start();
      expect(controller.folderState, isA<FolderReady>());
      expect(controller.root!.value, '/');
    });

    test('a git root at the filesystem root is ignored', () async {
      folder([file('/srv/p/a.txt')], git: '/');
      await build().start();
      expect(controller.root!.value, '/srv/p');
      expect(controller.canGoUp, isFalse);
    });

    test('a git root that is no ancestor of the folder is ignored', () async {
      folder([file('/srv/p/a.txt')], git: '/srv/other');
      await build().start();
      expect(controller.root!.value, '/srv/p');
    });

    test('the file name comes from its path, not the row name', () async {
      folder([
        FsEntry(
          name: 'notes.md',
          path: p('/srv/p/shot.png'),
          isDirectory: false,
        ),
      ]);
      source.downloads['/srv/p/shot.png'] = writes([1], length: 1);
      await build().start();
      await controller.select(controller.entries.single);
      expect(controller.preview, isA<PreviewImage>());
      await controller.save();
      expect(actions.savedFiles.single.name, 'shot.png');
    });

    test('ENOTDIR on a folder lists its parent and opens the file', () async {
      folder([folderEntry('/srv/p/note.txt')]);
      await build().start();
      // The row said folder; the server says it is a file.
      source.lists['/srv/p/note.txt'] = () => failed(FilesFailure.notAFile);
      source.lists['/srv/p'] = () => listing([file('/srv/p/note.txt')]);
      source.texts['/srv/p/note.txt'] = () =>
          ok(const FsTextFile(text: 'hi', byteSize: 2));
      await controller.openFolder(controller.entries.single);

      expect(controller.folder!.value, '/srv/p');
      expect(controller.folderState, isA<FolderReady>());
      expect((controller.preview as PreviewText).file.text, 'hi');
      expect(controller.selected!.name, 'note.txt');
    });

    test(
      'ENOTDIR for a row the parent still lists as a folder stops',
      () async {
        folder([folderEntry('/srv/p/odd')]);
        await build().start();
        source.lists['/srv/p/odd'] = () => failed(FilesFailure.notAFile);
        await controller.openFolder(controller.entries.single);
        expect(controller.folder!.value, '/srv/p');
        expect(controller.preview, isA<PreviewIdle>());
        expect(source.count('list /srv/p/odd'), 1);
      },
    );

    test('ending the page cancels the start requests', () async {
      folder([]);
      source.lists['/srv/p'] = () => Completer<FilesResult<FsListing>>().future;
      final starting = build(timeout: const Duration(milliseconds: 100))
          .start();
      await until(() => source.count('gitRoot') == 1);
      controller.cancelAll();
      expect(source.tokens['list /srv/p']!.isCancelled, isTrue);
      expect(source.tokens['gitRoot /srv/p']!.isCancelled, isTrue);
      await starting;
    });
  });

  group('actions that fail', () {
    setUp(() {
      folder([file('/srv/p/export.zip')]);
      source.downloads['/srv/p/export.zip'] = writes([1], length: 1);
    });

    String everything() => [
      '${controller.preview}',
      for (final c in trail.recent) ...[
        c.name,
        ...c.attributes.values.map((v) => '$v'),
      ],
      for (final s in tracer.spans) ...[
        s.name,
        ...s.attributes.values.map((v) => '$v'),
      ],
    ].join(' ');

    test('a Save that throws is a failure kind and leaks nothing', () async {
      actions.saveError = FileSystemException('cannot write', cache.path);
      await build().start();
      await controller.select(controller.entries.single);
      await controller.save();

      expect(
        (controller.preview as PreviewFailed).kind,
        FilesFailure.unreadable,
      );
      expect(trail.recent.where((c) => c.name == 'files.saved'), isEmpty);
      expect(everything(), isNot(contains(cache.path)));
      expect(everything(), isNot(contains('export')));
    });

    test(
      'an Open with that throws is a failure kind and leaks nothing',
      () async {
        actions.openError = FileSystemException('cannot open', cache.path);
        await build().start();
        await controller.select(controller.entries.single);
        await controller.openWith();

        expect(
          (controller.preview as PreviewFailed).kind,
          FilesFailure.unreadable,
        );
        expect(everything(), isNot(contains(cache.path)));
        expect(everything(), isNot(contains('export')));
      },
    );
  });

  group('unknown-length copies', () {
    test('do not outlive the page that fetched them', () async {
      folder([file('/srv/p/chart.png')]);
      source.downloads['/srv/p/chart.png'] = writes([1, 2]);
      await build().start();
      await controller.select(controller.entries.single);
      expect(cached(), hasLength(1));
      controller.dispose();
      await until(() => cached().isEmpty);

      // A second page must not take the first one's copy for complete.
      await build().start();
      await controller.select(controller.entries.single);
      expect(source.count('download'), 2);
    });
  });

  group('races around eviction', () {
    late _GatedEvictStore gated;

    setUp(() {
      gated = _GatedEvictStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        actions: actions,
      );
      media = gated;
      folder([file('/srv/p/chart.png'), file('/srv/p/c.txt')]);
      source.downloads['/srv/p/chart.png'] = writes([1, 2]);
    });

    late Future<void> again;

    Future<void> openAgainWhileEvicting() async {
      await build().start();
      await controller.select(controller.entries.first);
      controller.closePreview();
      gated.gate = Completer<void>();
      final before = gated.evicts;
      again = controller.select(controller.entries.first);
      await until(() => gated.evicts == before + 1);
    }

    test('a download is not started after the page ended', () async {
      await openAgainWhileEvicting();
      controller.cancelAll();
      gated.gate!.complete();
      await again;

      expect(source.count('download'), 1);
      await until(() => cached().isEmpty);
    });

    test(
      'a stale fetch does not cancel the request that replaced it',
      () async {
        final text = Completer<FilesResult<FsTextFile>>();
        source.texts['/srv/p/c.txt'] = () => text.future;
        await openAgainWhileEvicting();
        final reading = controller.select(controller.entries.last);
        await until(() => source.count('readText') == 1);

        gated.gate!.complete();
        await again;

        expect(source.tokens['readText /srv/p/c.txt']!.isCancelled, isFalse);
        expect(source.count('download'), 1);
        text.complete(const FilesOk(FsTextFile(text: 'x', byteSize: 1)));
        await reading;
        expect(controller.preview, isA<PreviewText>());
      },
    );
  });

  group('questions', () {
    setUp(() {
      folder([
        file('/srv/p/big.png'),
        file('/srv/p/b.txt'),
        file('/srv/p/.env'),
      ]);
      source.downloads['/srv/p/big.png'] = (sink, token, allow, progress) {
        if (!allow) {
          return ok(
            const FsDownload(bytes: 0, contentLength: 90 * _mb, declined: true),
          );
        }
        sink.add([1]);
        return ok(const FsDownload(bytes: 1, contentLength: 90 * _mb));
      };
      source.texts['/srv/p/b.txt'] = () =>
          ok(const FsTextFile(text: 'b', byteSize: 1));
    });

    test(
      'a stale Download press does not download into another file',
      () async {
        await build().start();
        controller.toggleHidden();
        final rows = controller.entries;
        await controller.select(rows.firstWhere((e) => e.name == 'big.png'));
        expect(controller.preview, isA<PreviewConfirmSize>());

        await controller.select(rows.firstWhere((e) => e.name == 'b.txt'));
        await controller.confirmSize();

        expect(source.count('download'), 1);
        expect(controller.preview, isA<PreviewText>());
      },
    );

    test('a stale Download press does not skip the secret question', () async {
      await build().start();
      controller.toggleHidden();
      final rows = controller.entries;
      await controller.select(rows.firstWhere((e) => e.name == 'big.png'));
      await controller.select(rows.firstWhere((e) => e.name == '.env'));
      await controller.confirmSize();

      expect(controller.preview, isA<PreviewConfirmSecret>());
      expect(source.count('download'), 1);
      expect(source.count('readText'), 0);
    });

    test('a stale Continue does not answer the size question', () async {
      await build().start();
      controller.toggleHidden();
      final rows = controller.entries;
      await controller.select(rows.firstWhere((e) => e.name == '.env'));
      await controller.select(rows.firstWhere((e) => e.name == 'big.png'));
      await controller.confirmSecret();

      expect(controller.preview, isA<PreviewConfirmSize>());
      expect(source.count('download'), 1);
    });
  });

  group('actions in flight', () {
    setUp(() => folder([file('/srv/p/app.py')]));

    test('Save while the text preview loads keeps the preview', () async {
      final text = Completer<FilesResult<FsTextFile>>();
      source.texts['/srv/p/app.py'] = () => text.future;
      await build().start();
      final opening = controller.select(controller.entries.single);
      await until(() => controller.preview is PreviewLoading);

      await controller.save();
      expect(source.count('download'), 0);

      text.complete(const FilesOk(FsTextFile(text: 'x', byteSize: 1)));
      await opening;
      expect(controller.preview, isA<PreviewText>());
    });

    test('a second tap while Save downloads is ignored', () async {
      source.texts['/srv/p/app.py'] = () =>
          ok(const FsTextFile(text: 'x', byteSize: 1));
      final gate = Completer<void>();
      source.downloads['/srv/p/app.py'] = holds(gate);
      await build().start();
      await controller.select(controller.entries.single);

      final first = controller.save();
      await until(() => source.count('download') == 1);
      await controller.save();
      expect(source.count('download'), 1);

      gate.complete();
      await first;
      expect(controller.preview, isA<PreviewText>());
      expect(actions.savedFiles, hasLength(1));
    });
  });

  group('secret copies', () {
    test('live under a folder the next launch wipes', () async {
      folder([file('/srv/p/token.png'), file('/srv/p/chart.png')]);
      source.downloads['/srv/p/token.png'] = writes([1], length: 1);
      source.downloads['/srv/p/chart.png'] = writes([2], length: 1);
      await build().start();
      await controller.select(controller.entries.last);
      await controller.select(controller.entries.first);
      await controller.confirmSecret();
      expect(cached(), hasLength(2));

      final folders = cached().map((f) => f.parent.path.split('/').last);
      expect(folders.where((n) => n.startsWith('s')), hasLength(1));
      await media.wipeSecretCopies();
      expect(cached(), hasLength(1));
    });
  });
}
