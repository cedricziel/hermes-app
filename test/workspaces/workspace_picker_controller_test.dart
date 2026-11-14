import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';
import 'package:hermes_app/src/workspaces/workspace_catalog_loader.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';
import 'package:hermes_app/src/workspaces/workspace_picker_controller.dart';

import '../support/fake_hermes_server.dart';

import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recorded_breadcrumbs.dart';

import 'package:hermes_app/src/workspaces/workspace_telemetry.dart';

const _catalogBody = {
  'projects': [
    {
      'id': 'p1',
      'name': 'Demo',
      'folders': [
        {'path': '/home/me/code/demo-docs', 'label': 'Docs'},
        {'path': '/home/me/code/demo', 'is_primary': true},
      ],
    },
    {
      'id': 'p2',
      'name': 'Solo',
      'folders': [
        {'path': '/home/me/solo', 'is_primary': true},
      ],
    },
    {
      'id': 'p3',
      'name': 'Old',
      'archived': true,
      'folders': [
        {'path': '/home/me/old'},
      ],
    },
  ],
  'repos': [
    // Under Demo's folder, so it is not Recent.
    {
      'root': '/home/me/code/demo/api',
      'label': 'api',
      'sessions': 3,
      'last_active': 10.0,
    },
    {'root': '/home/me/code/older', 'sessions': 1, 'last_active': 5.0},
    {'root': '/home/me/code/newer', 'sessions': 12, 'last_active': 50.0},
  ],
  'default_cwd': '/home/me',
  'home': '/home/me',
  'scan_enabled': true,
};

Map<String, Object?> _dir(
  Iterable<String> names, {
  String parent = '/home/me',
}) => {
  'entries': [
    for (final name in names)
      {'name': name, 'path': '$parent/$name', 'isDirectory': true},
    {'name': 'notes.txt', 'path': '$parent/notes.txt', 'isDirectory': false},
  ],
};

const _wait = Duration(milliseconds: 80);

void main() {
  late FakeHermesServer server;
  late FutureOr<FakeResponse> Function() catalog;
  late FutureOr<FakeResponse> Function() config;
  late Map<String, FutureOr<FakeResponse> Function()> fs;
  late Future<Map<String, Object?>> Function(Map<String, Object?> params)
  complete;
  late List<String> fsReads;
  late List<Map<String, Object?>> completes;
  late HermesWorkspacesRepository repository;
  late WorkspaceCatalogLoader loader;
  late WorkspacePickerController picker;
  late RecordedBreadcrumbs crumbs;

  FakeResponse ok(Object? body) => (status: 200, body: body);
  FakeResponse status(int code, [Object? body]) =>
      (status: code, body: body ?? {'detail': 'x'});
  const boundary = 'Path is outside the managed read boundary';

  Future<void> settle([int ms = 40]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  WorkspacePickerController open({
    String? current,
    String? picked,
    bool awaitCatalog = true,
  }) {
    picker = WorkspacePickerController(
      repository: repository,
      loader: loader,
      profile: 'work',
      current: current,
      picked: picked,
      wait: _wait,
      debounce: const Duration(milliseconds: 5),
      telemetry: WorkspaceTelemetry(
        const ConnectionTelemetry(),
        crumbs.breadcrumbs,
      ),
    );
    return picker;
  }

  setUp(() {
    crumbs = RecordedBreadcrumbs();
    fsReads = [];
    completes = [];
    fs = {};
    catalog = () => ok(_catalogBody);
    config = () => ok({
      'desktop': {
        'repo_scan_roots': ['/home/me/code'],
      },
    });
    complete = (_) async => {'items': <Object?>[]};
    server = FakeHermesServer()
      ..onRequest('GET', '/api/chat/workspaces', (_) => catalog())
      ..onRequest('GET', '/api/config', (_) => config())
      ..onRequest('GET', '/api/fs/list', (request) {
        final path = '${request.queryParameters['path']}';
        fsReads.add(path);
        final answer = fs[path];
        return answer == null
            ? ok({'entries': [], 'error': 'ENOENT'})
            : answer();
      });
    repository = HermesWorkspacesRepository(server.client().raw, (
      method,
      params, {
      required timeout,
    }) {
      completes.add(params);
      return complete(params);
    });
    loader = WorkspaceCatalogLoader(
      repository: repository,
      profile: 'work',
      slowAfter: _wait,
    );
    fs['/home/me'] = () => ok(_dir(['code', 'solo']));
  });

  tearDown(() {
    picker.dispose();
    loader.dispose();
  });

  group('the list', () {
    test('is loading, then ready, with the server default first', () async {
      final gate = Completer<FakeResponse>();
      catalog = () => gate.future;
      open();
      expect(picker.status, WorkspacePickerStatus.loading);
      expect(picker.serverDefault, isNull);

      gate.complete(ok(_catalogBody));
      await settle();

      expect(picker.status, WorkspacePickerStatus.ready);
      expect(picker.serverDefault?.path, '/home/me');
      expect(picker.serverDefault?.title, 'me');
    });

    test('lists a project folder per row, the primary first, with its label '
        'when it has several, and skips an archived project', () async {
      open();
      await settle();

      expect(picker.projects.map((r) => (r.title, r.label, r.path)), [
        ('Demo', 'demo', '/home/me/code/demo'),
        ('Demo', 'Docs', '/home/me/code/demo-docs'),
        ('Solo', null, '/home/me/solo'),
      ]);
    });

    test('Recent is newest first and leaves out a repo under a project '
        'folder', () async {
      open();
      await settle();

      expect(picker.recent.map((r) => r.path), [
        '/home/me/code/newer',
        '/home/me/code/older',
      ]);
      expect(picker.recent.first.chatCount, 12);
    });

    test('searches only above eight rows and filters by name, label and '
        'path', () async {
      open();
      await settle();
      expect(picker.searchable, isFalse);

      catalog = () => ok({
        ..._catalogBody,
        'repos': [
          for (var i = 0; i < 7; i++)
            {'root': '/srv/r$i', 'sessions': i, 'last_active': i.toDouble()},
        ],
      });
      picker.retryCatalog();
      await settle();
      expect(picker.searchable, isTrue);

      picker.setQuery('r3');
      expect(picker.recent.map((r) => r.path), ['/srv/r3']);
      expect(picker.projects, isEmpty);
      picker.setQuery('docs');
      expect(picker.projects.map((r) => r.label), ['Docs']);
    });

    test('a read that gets no answer in time is partial, then a late answer '
        'applies and nothing was sent again', () async {
      final gate = Completer<FakeResponse>();
      catalog = () => gate.future;
      open();
      await settle(_wait.inMilliseconds + 40);

      expect(picker.status, WorkspacePickerStatus.partial);
      expect(server.requestsTo('GET', '/api/chat/workspaces'), hasLength(1));

      gate.complete(ok(_catalogBody));
      await settle();

      expect(picker.status, WorkspacePickerStatus.ready);
      expect(server.requestsTo('GET', '/api/chat/workspaces'), hasLength(1));
    });

    test('a failed read is partial while browsing works, with Try again as '
        'the only way to read again', () async {
      catalog = () => status(500);
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.partial);
      expect(picker.browseLocked, isFalse);

      catalog = () => ok(_catalogBody);
      picker.retryCatalog();
      await settle();
      expect(picker.status, WorkspacePickerStatus.ready);
    });

    test('a failed read is failed when the server does not let the app '
        'browse either', () async {
      catalog = () => status(500);
      // With no default known the probe asks about `~`.
      fs['~'] = () => status(403, {'detail': boundary});
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.failed);
      expect(picker.browseLocked, isTrue);
    });

    test('an old server is unsupported, hides Browse and is not read again '
        'by opening', () async {
      catalog = () => status(404, {'detail': 'Not Found'});
      fs.clear();
      await loader.reload();
      await settle();
      final before = server.requestsTo('GET', '/api/chat/workspaces').length;
      // The probe at "~" answers 404 as an old server does.
      fs['~'] = () => status(404, {'detail': 'Not Found'});
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.unsupported);
      expect(picker.browseAccess, WorkspaceBrowseAccess.unsupported);
      expect(picker.browseLocked, isTrue);
      expect(
        server.requestsTo('GET', '/api/chat/workspaces'),
        hasLength(before),
      );
    });

    test('offline when the server cannot be reached', () async {
      catalog = () => throw Exception('down');
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.offline);
      expect(picker.offline, isTrue);
    });

    test('an unknown profile is its own state', () async {
      catalog = () => status(404, {'detail': "Profile 'x' does not exist."});
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.unknownProfile);
    });

    test('keeps the list it had while it reads again', () async {
      await loader.load();
      final gate = Completer<FakeResponse>();
      catalog = () => gate.future;
      open();
      await settle();

      expect(picker.status, WorkspacePickerStatus.ready);
      expect(picker.projects, isNotEmpty);
      gate.complete(ok(_catalogBody));
    });
  });

  group('choosing', () {
    test('the server default of a new chat sends nothing', () async {
      open();
      await settle();

      final pick = picker.pick(kPickerDefaultId)!;

      expect(pick.isServerDefault, isTrue);
      expect(pick.choice, isNull);
    });

    test('a project row picks its folder with the project name', () async {
      open();
      await settle();

      final pick = picker.pick(picker.projects.first.id)!;

      expect(pick.path, '/home/me/code/demo');
      expect(pick.choice?.projectName, 'Demo');
      expect(pick.choice?.source, WorkspaceChoiceSource.project);
    });

    test('a recent row picks its folder', () async {
      open();
      await settle();

      final pick = picker.pick(picker.recent.first.id)!;

      expect(pick.choice?.source, WorkspaceChoiceSource.recent);
      expect(pick.choice?.projectName, isNull);
    });

    test('shows the earlier pick chosen, and nothing when no list holds '
        'it', () async {
      open(picked: '/home/me/solo');
      await settle();
      expect(picker.selectedId, picker.projects.last.id);

      picker.dispose();
      open(picked: '/elsewhere');
      await settle();
      expect(picker.selectedId, '');
    });

    test('an unknown row picks nothing', () async {
      open();
      await settle();

      expect(picker.pick('nope'), isNull);
    });
  });

  group('moving a chat', () {
    test('marks the chat\'s folder on the row that holds it', () async {
      open(current: '/home/me/code/newer');
      await settle();

      expect(picker.recent.where((r) => r.isCurrent).map((r) => r.path), [
        '/home/me/code/newer',
      ]);
      expect(picker.selectedId, picker.recent.first.id);
    });

    test('adds a folder no list holds to the top of Projects when a '
        'project holds it', () async {
      open(current: '/home/me/solo/sub');
      await settle();

      expect(picker.projects.first.isCurrent, isTrue);
      expect(picker.projects.first.title, 'Solo');
      expect(picker.projects.first.path, '/home/me/solo/sub');
      expect(picker.selectedId, kPickerCurrentId);
    });

    test('adds it to the top of Recent when no project holds it', () async {
      open(current: '/srv/else');
      await settle();

      expect(picker.recent.first.isCurrent, isTrue);
      expect(picker.recent.first.title, 'else');
      expect(picker.projects.any((r) => r.isCurrent), isFalse);
    });

    test('the server default row is the chat folder when they are the '
        'same', () async {
      open(current: '/home/me');
      await settle();

      expect(picker.serverDefault?.isCurrent, isTrue);
      expect(picker.selectedId, kPickerDefaultId);
      expect(picker.recent.any((r) => r.isCurrent), isFalse);
    });

    test('the server default is a folder to move to, not "nothing"', () async {
      open(current: '/srv/else');
      await settle();

      expect(picker.pick(kPickerDefaultId)?.path, '/home/me');
    });
  });

  group('scanning', () {
    test('is offered only when the server can scan', () async {
      catalog = () => ok({..._catalogBody, 'scan_enabled': false});
      open();
      await settle();

      expect(picker.scanAvailable, isFalse);
      await picker.scan();
      expect(
        server.requests.any((r) => r.queryParameters['scan'] == true),
        isFalse,
      );
    });

    test('reads the scan folders first and sends no scan when there are '
        'none', () async {
      config = () => ok({
        'desktop': {'repo_scan_roots': <String>[]},
      });
      open();
      await settle();

      await picker.scan();

      expect(picker.scanOutcome, WorkspacePickerScanOutcome.nothingToScan);
      expect(picker.scanning, isFalse);
      expect(
        server
            .requestsTo('GET', '/api/chat/workspaces')
            .where((r) => r.queryParameters['scan'] == true),
        isEmpty,
      );
    });

    test('says how many new folders it found, one included', () async {
      open();
      await settle();
      catalog = () => ok({
        ..._catalogBody,
        'repos': [
          ...(_catalogBody['repos']! as List),
          {'root': '/home/me/code/fresh', 'sessions': 0, 'last_active': 1.0},
        ],
      });

      await picker.scan();
      await settle();

      expect(picker.scanOutcome, WorkspacePickerScanOutcome.found);
      expect(picker.scanFound, 1);
      expect(
        picker.recent.firstWhere((r) => r.isNew).path,
        '/home/me/code/fresh',
      );
      expect(
        server
            .requestsTo('GET', '/api/chat/workspaces')
            .last
            .queryParameters['scan'],
        true,
      );
    });

    test('says when nothing is new', () async {
      open();
      await settle();

      await picker.scan();
      await settle();

      expect(picker.scanOutcome, WorkspacePickerScanOutcome.nothingNew);
    });

    test('a scan that gets no answer ends with the list unchanged, and a '
        'late answer still applies', () async {
      open();
      await settle();
      final before = picker.recent.map((r) => r.path).toList();
      final gate = Completer<FakeResponse>();
      catalog = () => gate.future;

      unawaited(picker.scan());
      await settle(_wait.inMilliseconds + 40);

      expect(picker.scanning, isFalse);
      expect(picker.scanOutcome, WorkspacePickerScanOutcome.tooSlow);
      expect(picker.recent.map((r) => r.path), before);

      gate.complete(
        ok({
          ..._catalogBody,
          'repos': [
            {'root': '/home/me/code/late', 'sessions': 1, 'last_active': 99.0},
          ],
        }),
      );
      await settle();

      expect(picker.recent.map((r) => r.path), contains('/home/me/code/late'));
    });
  });

  group('scanning races', () {
    test('a read that answers while the scan folders are read does not end '
        'the scan', () async {
      await loader.load();
      final openRead = Completer<FakeResponse>();
      final roots = Completer<FakeResponse>();
      var reads = 0;
      catalog = () {
        reads++;
        if (reads == 1) return openRead.future;
        return ok({
          ..._catalogBody,
          'repos': [
            ...(_catalogBody['repos']! as List),
            {'root': '/home/me/code/fresh', 'sessions': 0, 'last_active': 1.0},
          ],
        });
      };
      config = () => roots.future;
      open();
      await settle(15);

      unawaited(picker.scan());
      await settle(15);
      openRead.complete(ok(_catalogBody));
      await settle(15);

      expect(picker.scanning, isTrue);
      expect(picker.scanOutcome, isNull);

      roots.complete(
        ok({
          'desktop': {
            'repo_scan_roots': ['/home/me/code'],
          },
        }),
      );
      await settle(15);

      expect(picker.scanOutcome, WorkspacePickerScanOutcome.found);
      expect(picker.scanFound, 1);
    });

    test('Try again during a scan reads nothing and leaves the scan its '
        'answer', () async {
      await loader.load();
      final scanRead = Completer<FakeResponse>();
      var reads = 0;
      catalog = () {
        reads++;
        return reads <= 1 ? ok(_catalogBody) : scanRead.future;
      };
      open();
      await settle(15);
      final before = server.requestsTo('GET', '/api/chat/workspaces').length;

      unawaited(picker.scan());
      await settle(15);
      final during = server.requestsTo('GET', '/api/chat/workspaces').length;
      picker.retryCatalog();
      await settle(15);

      expect(
        server.requestsTo('GET', '/api/chat/workspaces').length,
        during,
        reason: 'only the scan\'s read is out (was $before)',
      );
      expect(picker.scanning, isTrue);
      scanRead.complete(ok(_catalogBody));
      await settle(15);
      expect(picker.scanOutcome, WorkspacePickerScanOutcome.nothingNew);
    });
  });

  group('a lost probe', () {
    test('does not disable Browse and Type after Try again reads the '
        'projects', () async {
      await loader.load();
      var probes = 0;
      fs['/home/me'] = () =>
          ++probes == 1 ? throw Exception('down') : ok(_dir(['code']));
      open();
      await settle();
      expect(picker.offline, isTrue);

      picker.retryCatalog();
      await settle();

      expect(picker.offline, isFalse);
      expect(picker.browseAccess, WorkspaceBrowseAccess.available);
      expect(probes, 2);
    });
  });

  group('browsing', () {
    test('asks once when it opens, at the server default', () async {
      open();
      await settle();

      expect(fsReads, ['/home/me']);
      expect(picker.browseAccess, WorkspaceBrowseAccess.available);
    });

    test('a 404 after a probe that answered is a missing folder, not an old '
        'server', () async {
      open();
      await settle();
      fs['/home/me/gone'] = () => status(404, {'detail': 'File not found'});

      picker.openFolder(ServerPath.tryParse('/home/me/gone')!);
      await settle();

      expect(picker.browseLevel, FolderBrowserLevel.missing);
      expect(picker.browseAccess, WorkspaceBrowseAccess.available);
      expect(picker.useBrowsed(), isNull);
    });

    test('lists folders only and walks up and down', () async {
      fs['/home/me/code'] = () => ok(_dir(['demo'], parent: '/home/me/code'));
      fs['/home'] = () => ok(_dir(['me'], parent: '/home'));
      open();
      await settle();

      picker.startBrowse();
      await settle();
      expect(picker.browsePath?.value, '/home/me');
      expect(picker.browseFolders.map((f) => f.name), ['code', 'solo']);

      picker.openFolder(ServerPath.tryParse('/home/me/code')!);
      await settle();
      expect(picker.browseFolders.map((f) => f.name), ['demo']);

      picker.browseUp();
      picker.browseUp();
      await settle();
      expect(picker.browsePath?.value, '/home');
      expect(picker.useBrowsed()?.path, '/home');
      expect(
        picker.useBrowsed()?.choice?.source,
        WorkspaceChoiceSource.browsed,
      );
    });

    test('in a move it starts at the chat\'s folder\'s parent', () async {
      fs['/home/me/code'] = () => ok(_dir(['a'], parent: '/home/me/code'));
      open(current: '/home/me/code/demo');
      await settle();

      picker.startBrowse();
      await settle();

      expect(picker.browsePath?.value, '/home/me/code');
    });

    test('the boundary on the first read hides Browse', () async {
      fs['/home/me'] = () => status(403, {'detail': boundary});
      open();
      await settle();

      expect(picker.browseAccess, WorkspaceBrowseAccess.locked);
      expect(picker.browseLocked, isTrue);
    });

    test('the boundary on a later level is only that level', () async {
      fs['/home'] = () => status(403, {'detail': boundary});
      open();
      await settle();

      picker.startBrowse();
      await settle();
      picker.browseUp();
      await settle();

      expect(picker.browseLevel, FolderBrowserLevel.outside);
      expect(picker.useBrowsed(), isNull);
      expect(picker.browseLocked, isFalse);
    });

    test('the boundary on the first browse read, while the probe has not '
        'answered, hides Browse', () async {
      await loader.load();
      fs['/home/me'] = () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return status(403, {'detail': boundary});
      };
      open();
      picker.startBrowse();
      await settle(60);

      expect(picker.browseLocked, isTrue);
    });

    test('EACCES keeps Use enabled, any other 403 text does not', () async {
      fs['/home/me/private'] = () => ok({'entries': [], 'error': 'EACCES'});
      fs['/home/me/ssh'] = () =>
          status(403, {'detail': 'File is not readable'});
      fs['/home/me/other'] = () => status(403, {'detail': 'nope'});
      open();
      await settle();

      picker.openFolder(ServerPath.tryParse('/home/me/private')!);
      await settle();
      expect(picker.browseLevel, FolderBrowserLevel.notAllowed);
      expect(picker.useBrowsed(), isNotNull);

      picker.openFolder(ServerPath.tryParse('/home/me/ssh')!);
      await settle();
      expect(picker.browseLevel, FolderBrowserLevel.notAllowed);
      expect(picker.useBrowsed(), isNotNull);

      picker.openFolder(ServerPath.tryParse('/home/me/other')!);
      await settle();
      expect(picker.browseLevel, FolderBrowserLevel.outside);
      expect(picker.useBrowsed(), isNull);
    });

    test('Use is refused for a level still opening or one that timed out, '
        'and allowed for one Hermes may not read', () async {
      open();
      await settle();
      final gate = Completer<FakeResponse>();
      fs['/home/me/slow'] = () => gate.future;

      picker.openFolder(ServerPath.tryParse('/home/me/slow')!);
      expect(picker.browseLevel, FolderBrowserLevel.opening);
      expect(picker.useBrowsed(), isNull);

      await settle(_wait.inMilliseconds + 40);
      expect(picker.browseLevel, FolderBrowserLevel.unreachable);
      expect(picker.useBrowsed(), isNull);

      fs['/home/me/private'] = () => ok({'entries': [], 'error': 'EACCES'});
      picker.openFolder(ServerPath.tryParse('/home/me/private')!);
      await settle();
      expect(picker.useBrowsed(), isNotNull);
      gate.complete(ok(_dir([])));
    });

    test('a level with no answer ends as "couldn\'t open", is read again '
        'only on retry, and a late answer applies', () async {
      open();
      await settle();
      final gate = Completer<FakeResponse>();
      fs['/home/me/slow'] = () => gate.future;
      final reads = fsReads.length;

      picker.openFolder(ServerPath.tryParse('/home/me/slow')!);
      expect(picker.browseLevel, FolderBrowserLevel.opening);
      await settle(_wait.inMilliseconds + 40);
      expect(picker.browseLevel, FolderBrowserLevel.unreachable);
      expect(fsReads.length, reads + 1);

      gate.complete(ok(_dir(['x'], parent: '/home/me/slow')));
      await settle();
      expect(picker.browseLevel, FolderBrowserLevel.ready);
      expect(fsReads.length, reads + 1);
    });

    test('an answer for a level the person left is dropped', () async {
      open();
      await settle();
      final gate = Completer<FakeResponse>();
      fs['/home/me/slow'] = () => gate.future;
      picker.openFolder(ServerPath.tryParse('/home/me/slow')!);
      picker.openFolder(ServerPath.tryParse('/home/me')!);
      await settle();

      gate.complete(ok(_dir(['x'], parent: '/home/me/slow')));
      await settle();

      expect(picker.browsePath?.value, '/home/me');
      expect(picker.browseFolders.map((f) => f.name), ['code', 'solo']);
    });

    test('unreachable on the level is "couldn\'t open"', () async {
      open();
      await settle();
      fs['/home/me/down'] = () => throw Exception('down');

      picker.openFolder(ServerPath.tryParse('/home/me/down')!);
      await settle();

      expect(picker.browseLevel, FolderBrowserLevel.unreachable);
    });
  });

  group('typing', () {
    Map<String, Object?> items(List<(String, String, String)> rows) => {
      'items': [
        for (final (text, display, meta) in rows)
          {'text': text, 'display': display, 'meta': meta},
      ],
    };

    test('never accepts or asks about a relative path', () async {
      open();
      await settle();
      final reads = fsReads.length;

      picker.setTyped('code/demo');
      await settle();

      expect(picker.check, PathEntryCheck.relative);
      expect(picker.canUseTyped, isFalse);
      expect(picker.useTyped(), isNull);
      expect(completes, isEmpty);
      expect(fsReads.length, reads);
    });

    test('suggests folders and checks the path after the pause', () async {
      fs['/home/me/co'] = () => ok({'entries': [], 'error': 'ENOENT'});
      complete = (_) async => items([
        ('../me/code/', 'code/', 'dir'),
        ('../me/notes.txt', 'notes.txt', ''),
      ]);
      open();
      await settle();

      picker.setTyped('/home/me/co');
      await settle();

      expect(picker.suggestions.map((s) => (s.name, s.path)), [
        ('code', '/home/me/code/'),
      ]);
      expect(picker.check, PathEntryCheck.missing);
      expect(picker.useTyped(), isNull);
    });

    test('found enables Use, which sends the path without a trailing '
        'slash', () async {
      open();
      await settle();

      picker.setTyped('/home/me/');
      await settle();

      expect(picker.check, PathEntryCheck.found);
      final pick = picker.useTyped()!;
      expect(pick.path, '/home/me');
      expect(pick.choice?.source, WorkspaceChoiceSource.typed);
    });

    test('taking a suggestion asks at once', () async {
      fs['/home/me/code'] = () => ok(_dir(['demo'], parent: '/home/me/code'));
      open();
      await settle();

      picker.takeSuggestion(
        const PathEntrySuggestion(name: 'code', path: '/home/me/code/'),
      );
      await settle();

      expect(picker.typedText, '/home/me/code/');
      expect(picker.check, PathEntryCheck.found);
    });

    test('keeps only the latest answer', () async {
      final slow = Completer<Map<String, Object?>>();
      complete = (params) => params['word'] == '/a'
          ? slow.future
          : Future.value(items([('x', 'late/', 'dir')]));
      open();
      await settle();

      picker.setTyped('/a');
      await settle(20);
      picker.setTyped('/ab');
      await settle(20);
      slow.complete(items([('x', 'stale/', 'dir')]));
      await settle();

      expect(picker.suggestions.map((s) => s.name), ['late']);
    });

    test('30 items with no folder show only the note', () async {
      complete = (_) async =>
          items([for (var i = 0; i < 30; i++) ('f$i', 'f$i.txt', '')]);
      open();
      await settle();

      picker.setTyped('/home/me/');
      await settle();

      expect(picker.suggestions, isEmpty);
      expect(picker.suggestionsCapped, isTrue);
    });

    test(
      'EACCES leaves Use enabled, a locked server accepts the choice',
      () async {
        fs['/home/me/private'] = () => ok({'entries': [], 'error': 'EACCES'});
        fs['/locked'] = () => status(403, {'detail': boundary});
        open();
        await settle();

        picker.setTyped('/home/me/private');
        await settle();
        expect(picker.check, PathEntryCheck.notAllowed);
        expect(picker.canUseTyped, isTrue);

        picker.setTyped('/locked');
        await settle();
        expect(picker.check, PathEntryCheck.cannotCheck);
        expect(picker.canUseTyped, isTrue);
      },
    );

    test('a check with no answer says so, disables Use, is asked again only '
        'on request and a late answer applies', () async {
      open();
      await settle();
      final gate = Completer<FakeResponse>();
      fs['/home/me/slow'] = () => gate.future;
      final reads = fsReads.length;

      picker.setTyped('/home/me/slow');
      await settle(_wait.inMilliseconds + 40);

      expect(picker.check, PathEntryCheck.tooSlow);
      expect(picker.canUseTyped, isFalse);
      expect(fsReads.length, reads + 1);

      gate.complete(ok(_dir([], parent: '/home/me/slow')));
      await settle();
      expect(picker.check, PathEntryCheck.found);
    });

    test('Check again reads the path once more', () async {
      open();
      await settle();
      var answers = 0;
      fs['/home/me/flaky'] = () =>
          ++answers == 1 ? throw Exception('down') : ok(_dir([]));

      picker.setTyped('/home/me/flaky');
      await settle();
      expect(picker.check, PathEntryCheck.tooSlow);

      picker.checkAgain();
      await settle();
      expect(picker.check, PathEntryCheck.found);
    });

    test('a `~` path is asked about', () async {
      fs['~'] = () => ok(_dir([]));
      open();
      await settle();

      picker.setTyped('~');
      await settle();

      expect(picker.check, PathEntryCheck.found);
    });
  });

  group('ending', () {
    test('a profile change closes it and drops answers on their way', () async {
      final gate = Completer<FakeResponse>();
      catalog = () => gate.future;
      open();
      await settle();

      var notified = 0;
      picker.addListener(() => notified++);
      picker.profileChanged('other');
      final closing = notified;
      expect(picker.closed, isTrue);
      gate.complete(ok(_catalogBody));
      await settle();

      expect(notified, closing);
      expect(picker.pick(kPickerDefaultId), isNull);
      picker.startBrowse();
      expect(picker.browsePath, isNull);
    });

    test('the same profile does not close it', () async {
      open();
      picker.profileChanged('work');
      expect(picker.closed, isFalse);
    });

    test('a disposed picker drops late answers without notifying', () async {
      final gate = Completer<FakeResponse>();
      fs['/home/me/slow'] = () => gate.future;
      open();
      await settle();
      picker.openFolder(ServerPath.tryParse('/home/me/slow')!);
      var notified = 0;
      picker.addListener(() => notified++);
      picker.dispose();

      gate.complete(ok(_dir([])));
      await settle();

      expect(notified, 0);
    });
  });

  group('telemetry', () {
    test(
      'notes the picker opened and what was chosen, and no folder',
      () async {
        open(current: '/home/me/secret-client');
        await settle();
        picker.pick(picker.projects.first.id);
        picker.pick(kPickerDefaultId);

        expect(crumbs.named('workspace.picker.opened'), [
          {'mode': 'move'},
        ]);
        expect(crumbs.named('workspace.chosen'), [
          {'source': 'project'},
          {'source': 'default'},
        ]);
        final values = [
          for (final (_, attributes) in crumbs.all) ...attributes.values,
        ];
        expect(values, everyElement(isIn(['move', 'project', 'default'])));
        for (final secret in ['secret-client', 'Demo', '/home']) {
          expect(crumbs.text, isNot(contains(secret)));
        }
      },
    );
  });
}
