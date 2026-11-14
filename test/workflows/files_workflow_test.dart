import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/app/providers/auth_providers.dart';
import 'package:provider/provider.dart';

import '../../widgetbook/files_sample_image.dart';
import '../support/attachment_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _root = '/srv/field-notes';

Map<String, Object?> _entry(
  String name, {
  bool dir = false,
  String at = _root,
}) => {'name': name, 'path': '$at/$name', 'isDirectory': dir};

/// A chat's working folder on a phone and on a desktop: open Files from the
/// Activity panel, go into a folder, preview text, code, Markdown and an
/// image, meet a file that is not shown, a file that may hold secrets, an
/// empty folder and a folder the server cannot reach.
void main() {
  late FakeHermesServer server;
  late Completer<FakeResponse> slowListing;
  late MediaStore media;

  void list(String path, List<Map<String, Object?>> entries) => server.on(
    'GET',
    '/api/fs/list',
    {'entries': entries},
    query: {'path': path, 'profile': 'default'},
  );

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/fs/default-cwd', {'cwd': _root})
      ..on(
        'GET',
        '/api/fs/default-cwd',
        {'cwd': _root},
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {
            ...sessionRow(
              id: 's1',
              title: 'Field notes',
              lastActive: 1780000900,
            ),
            'cwd': _root,
          },
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on(
        'GET',
        '/api/fs/git-root',
        {'root': null},
        query: {'path': _root, 'profile': 'default'},
      );
    list(_root, [
      _entry('analysis.py'),
      _entry('empty', dir: true),
      _entry('offline', dir: true),
      _entry('slow', dir: true),
      _entry('offsite', dir: true),
      _entry('reports', dir: true),
      _entry('big.png'),
      _entry('api_token.txt'),
      _entry('deploy.pem'),
      _entry('chart.png'),
      _entry('export.zip'),
      _entry('README.md'),
    ]);
    list('$_root/reports', [
      _entry('summary.txt', at: '$_root/reports'),
      _entry('2026', dir: true, at: '$_root/reports'),
    ]);
    list('$_root/empty', const []);
    slowListing = Completer<FakeResponse>();
    server
      ..onRequest(
        'GET',
        '/api/fs/list',
        (_) => slowListing.future,
        query: {'path': '$_root/slow', 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/list',
        {'detail': 'Bad gateway'},
        status: 502,
        query: {'path': '$_root/offline', 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/download',
        FakeFile(Uint8List(8), announcedLength: 60 * 1024 * 1024),
        query: {'path': '$_root/big.png', 'profile': 'default'},
      );
    server
      ..on(
        'GET',
        '/api/fs/list',
        {'detail': 'SSH workspace is unavailable'},
        status: 503,
        query: {'path': '$_root/offsite', 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/read-text',
        {
          'binary': false,
          'byteSize': 120,
          'language': 'markdown',
          'mimeType': 'text/markdown',
          'path': '$_root/README.md',
          'text':
              '# Field notes\n\nSoil moisture readings from the **north '
              'field**.\n\n- Sensors: 12\n- Interval: 15 minutes\n\n'
              'See [the method](https://example.org/method).',
          'truncated': false,
        },
        query: {'path': '$_root/README.md', 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/read-text',
        {
          'binary': false,
          'byteSize': 90,
          'language': 'python',
          'mimeType': 'text/x-python',
          'path': '$_root/analysis.py',
          'text':
              'import statistics\n\n\ndef mean_moisture(readings):\n'
              '    """Average of the readings."""\n'
              '    return statistics.mean(readings)\n',
          'truncated': false,
        },
        query: {'path': '$_root/analysis.py', 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/download',
        base64Decode(kFilesSamplePngBase64),
        query: {'path': '$_root/chart.png', 'profile': 'default'},
      );
  });

  /// Lets real file IO and the frames after a tap finish. It does not
  /// settle: a spinner on screen never does.
  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpChat(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    required Brightness brightness,
  }) async {
    final repositories = HermesRepositories(server.client());
    final dir = tempDir('files_workflow');
    media = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => dir,
      actions: FakeMediaActions(),
    );
    await pumpScreen(
      tester,
      shots,
      ChatScreen(
        repository: HermesChatRepository(server.client().raw),
        transport: FakeChatTransport(),
      ),
      size: size,
      brightness: brightness,
      providers: [
        Provider<HermesRepositories?>.value(value: repositories),
        Provider<MediaStore?>.value(value: media),
        // The app's own definition, as `main` builds it.
        filesAvailabilityProvider(),
      ],
    );
  }

  Future<void> openFiles(
    WidgetTester tester, [
    ScreenshotRecorder? shots,
  ]) async {
    await openSidebar(tester);
    await tester.tap(find.byKey(const ValueKey('thread-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pumpAndSettle();
    await idle(tester);
    await shots?.capture(tester, 'activity-row');
    await tester.tap(find.byKey(const Key('activity-files-row')));
    await idle(tester);
  }

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await idle(tester);
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;
    for (final (name, size) in [
      ('phone', phoneSize),
      ('desktop', desktopSize),
    ]) {
      testWidgets('$name ($mode): browse, preview, ask and fail', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('files-$name-$mode');
        await pumpChat(tester, shots, size: size, brightness: brightness);
        await openFiles(tester, shots);
        expect(find.text('field-notes'), findsWidgets);
        expect(find.text('README.md'), findsOneWidget);
        await shots.capture(tester, 'list');

        await tapRow(tester, 'reports');
        expect(find.text('summary.txt'), findsOneWidget);
        await shots.capture(tester, 'folder');
        await tester.tap(find.text('field-notes').first);
        await idle(tester);

        await tapRow(tester, 'README.md');
        expect(
          find.textContaining('Soil moisture', findRichText: true),
          findsOneWidget,
        );
        await shots.capture(tester, 'markdown');
        if (name == 'phone') await popRoute(tester);
        await idle(tester);

        await tapRow(tester, 'analysis.py');
        expect(
          find.textContaining('mean_moisture', findRichText: true),
          findsOneWidget,
        );
        await shots.capture(tester, 'code');
        if (name == 'phone') await popRoute(tester);
        await idle(tester);

        await tapRow(tester, 'chart.png');
        await shots.capture(tester, 'image');
        if (name == 'phone') await popRoute(tester);
        await idle(tester);

        await tapRow(tester, 'export.zip');
        expect(find.text('Save'), findsWidgets);
        await shots.capture(tester, 'other-file');
        if (name == 'phone') await popRoute(tester);
        await idle(tester);

        await tapRow(tester, 'api_token.txt');
        expect(
          find.text(
            'This file may contain passwords or keys. Continue anyway?',
          ),
          findsOneWidget,
        );
        await shots.capture(tester, 'secret-question');
        await tester.tap(find.text('Cancel'));
        await idle(tester);
        expect(find.textContaining('passwords or keys'), findsNothing);

        await tapRow(tester, 'deploy.pem');
        expect(find.textContaining('passwords or keys'), findsOneWidget);
        await shots.capture(tester, 'secret-question-again');
        await tester.tap(find.text('Cancel'));
        await idle(tester);

        await tapRow(tester, 'empty');
        expect(find.text('Nothing here yet'), findsOneWidget);
        await shots.capture(tester, 'empty-folder');
        await tester.tap(find.text('field-notes').first);
        await idle(tester);

        await tapRow(tester, 'offsite');
        expect(find.text('Try again'), findsOneWidget);
        await shots.capture(tester, 'error');
        await tester.tap(find.text('field-notes').first);
        await idle(tester);

        await tapRow(tester, 'offline');
        expect(find.text("Can't reach your Hermes server."), findsOneWidget);
        await shots.capture(tester, 'offline');
        await tester.tap(find.text('field-notes').first);
        await idle(tester);

        await tester.tap(find.text('slow').first);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Loading folder…'), findsOneWidget);
        await shots.capture(tester, 'loading');
        slowListing.complete((status: 200, body: {'entries': const []}));
        await idle(tester);
        await tester.tap(find.text('field-notes').first);
        await idle(tester);

        await tapRow(tester, 'big.png');
        expect(find.textContaining('Download it anyway?'), findsOneWidget);
        await shots.capture(tester, 'size-question');
        await tester.tap(find.text('Cancel'));
        await idle(tester);
      });
    }
  }

  testWidgets('phone (German): list, other file, question, offline', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final shots = ScreenshotRecorder('files-phone-de');
    await pumpChat(
      tester,
      shots,
      size: phoneSize,
      brightness: Brightness.light,
    );
    await openFiles(tester, shots);
    await shots.capture(tester, 'list');

    await tapRow(tester, 'export.zip');
    await shots.capture(tester, 'other-file');
    await popRoute(tester);
    await idle(tester);

    await tapRow(tester, 'api_token.txt');
    await shots.capture(tester, 'secret-question');
    await tester.tap(find.text('Abbrechen'));
    await idle(tester);

    await tapRow(tester, 'offline');
    await shots.capture(tester, 'offline');
  });
}
