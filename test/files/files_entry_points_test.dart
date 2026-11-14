import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/files/files_availability.dart';
import 'package:hermes_app/src/files/files_screen.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/pump_chat.dart';

const _root = '/srv/field-notes';

void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;
  late FilesAvailability availability;

  setUp(() {
    trail = BreadcrumbTrail();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {...sessionRow(id: 's1', title: 'Field notes'), 'cwd': _root},
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on('GET', '/api/fs/default-cwd', {'cwd': '/elsewhere'})
      ..on(
        'GET',
        '/api/fs/git-root',
        {'root': null},
        query: {'path': _root, 'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/fs/list',
        {
          'entries': [
            {'name': 'a.txt', 'path': '$_root/a.txt', 'isDirectory': false},
          ],
        },
        query: {'path': _root, 'profile': 'default'},
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    MacCommandRegistry? commands,
    TargetPlatform? platform,
    Size size = const Size(1400, 900),
  }) async {
    final repositories = HermesRepositories(server.client());
    availability = FilesAvailability.forRepositories(repositories);
    addTearDown(availability.dispose);
    final dir = tempDir('files_entry');
    await pumpChatScreen(
      tester,
      server: server,
      transport: FakeChatTransport(),
      commands: commands,
      platform: platform,
      size: size,
      providers: [
        Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
        Provider<HermesRepositories?>.value(value: repositories),
        Provider<MediaStore?>.value(
          value: MediaStore(
            source: HermesMediaSource(() => server.client()),
            cacheDirectory: () async => dir,
            actions: FakeMediaActions(),
          ),
        ),
        ChangeNotifierProvider<FilesAvailability?>.value(value: availability),
      ],
    );
  }

  Future<void> probeAndSettle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (availability.support != FilesSupport.unknown) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  Future<void> openActivity(WidgetTester tester) async {
    await openThread(tester, 'Field notes');
    await probeAndSettle(tester);
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pumpAndSettle();
  }

  const row = Key('activity-files-row');

  group('on a server with the routes', () {
    testWidgets('the Activity panel lists Files with the folder name', (
      tester,
    ) async {
      await pump(tester);
      await openActivity(tester);

      expect(find.byKey(row), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(row),
          matching: find.text('field-notes'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the row opens the page and notes where from', (tester) async {
      await pump(tester);
      await openActivity(tester);
      await tester.tap(find.byKey(row));
      await probeAndSettle(tester);

      expect(find.byType(FilesScreen), findsOneWidget);
      expect(find.text('a.txt'), findsOneWidget);
      final opened = trail.recent.singleWhere((c) => c.name == 'files.opened');
      expect(opened.attributes, {'source': 'activity'});
    });

    testWidgets('the chat header menu has a Files item', (tester) async {
      await pump(tester, size: const Size(1100, 800));
      await openThread(tester, 'Field notes');
      await probeAndSettle(tester);
      await tester.tap(find.byKey(const Key('header-thread-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files').last);
      await probeAndSettle(tester);

      expect(find.byType(FilesScreen), findsOneWidget);
      expect(
        trail.recent.singleWhere((c) => c.name == 'files.opened').attributes,
        {'source': 'header'},
      );
    });

    testWidgets('View > Show Files opens the chat in front', (tester) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pump(tester, commands: commands);
      await openThread(tester, 'Field notes');
      await probeAndSettle(tester);

      expect(commands.handlerFor(MacCommand.showFiles)?.enabled, isTrue);
      expect(commands.invoke(MacCommand.showFiles), isTrue);
      await probeAndSettle(tester);

      expect(find.byType(FilesScreen), findsOneWidget);
      expect(
        trail.recent.singleWhere((c) => c.name == 'files.opened').attributes,
        {'source': 'menu'},
      );
    });

    test('the menu offers it with the chord shift-command-F', () {
      final view = menuLayout.singleWhere((s) => s.id == 'view');
      final entry = [for (final group in view.groups) ...group]
          .singleWhere((e) => e.command == MacCommand.showFiles);
      expect(entry.label, 'Show Files');
      final chord = entry.shortcut!;
      expect(chord.shift, isTrue);
      expect(chord.meta, isTrue);
      // No other entry takes the chord.
      final same = [
        for (final section in menuLayout)
          for (final group in section.groups)
            for (final e in group)
              if (e.shortcut?.trigger == chord.trigger &&
                  e.shortcut?.shift == chord.shift &&
                  e.shortcut?.meta == chord.meta)
                e,
      ];
      expect(same, [entry]);
    });
  });

  group('on an old server', () {
    setUp(() {
      server.on('GET', '/api/fs/default-cwd', {
        'detail': 'Not Found',
      }, status: 404);
    });

    testWidgets('no row, no menu item, a disabled command, no error', (
      tester,
    ) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pump(tester, commands: commands);
      await openActivity(tester);

      expect(availability.support, FilesSupport.unsupported);
      expect(find.byKey(row), findsNothing);
      expect(commands.handlerFor(MacCommand.showFiles)?.enabled, isFalse);
      await tester.tap(find.byKey(const Key('header-thread-actions')));
      await tester.pumpAndSettle();
      expect(find.text('Files'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('while the probe has not answered, or failed', () {
    testWidgets('a failing probe still shows the entry points', (tester) async {
      server.on('GET', '/api/fs/default-cwd', {'detail': 'boom'}, status: 500);
      await pump(tester);
      await openActivity(tester);

      expect(availability.support, FilesSupport.supported);
      expect(find.byKey(row), findsOneWidget);
    });
  });
}
