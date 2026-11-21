import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/files/files_availability.dart';
import 'package:hermes_app/src/files/files_screen.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/tools/tools_availability.dart';
import 'package:hermes_app/src/tools/tools_screen.dart';
import 'package:provider/provider.dart';

import '../bot_screen/bot_screen_repository_test.dart' show statusJson;
import '../support/attachment_fixtures.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/pump_chat.dart';
import '../tools/tools_screen_fixtures.dart';

const _root = '/srv/field-notes';

/// What each entry does with a chat that has no profile of its own, when the
/// screen's own resolver (not a profile list the chat read) decides. The
/// resolver here knows `work` or nothing, so the call site's fallback is what
/// runs: a literal `default` there would send `default`.
void main() {
  late FakeHermesServer server;
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late HermesRepositories repositories;
  late FilesAvailability filesAvailability;
  late ToolsAvailability toolsAvailability;

  DioException notFound() {
    final options = RequestOptions(path: '/api/profiles/active');
    return DioException(
      requestOptions: options,
      response: Response<Object?>(requestOptions: options, statusCode: 404),
    );
  }

  setUp(() {
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['display.status'] = (_) => statusJson();
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      // The chat reads no profile, so its own is null and the screen's
      // resolver is what names one.
      ..on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404)
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {...sessionRow(id: 's1', title: 'Field notes'), 'cwd': _root},
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on('GET', '/api/fs/default-cwd', {'cwd': _root})
      ..on('GET', '/api/fs/git-root', {'root': null})
      ..on('GET', '/api/fs/list', {
        'entries': [
          {'name': 'a.txt', 'path': '$_root/a.txt', 'isDirectory': false},
        ],
      });
    routeTools(server);
    repositories = HermesRepositories(server.client());
    filesAvailability = FilesAvailability.forRepositories(repositories);
    toolsAvailability = ToolsAvailability(repositories.tools);
  });

  tearDown(() {
    filesAvailability.dispose();
    toolsAvailability.dispose();
  });

  Future<void> pump(WidgetTester tester, ProfileResolver resolver) async {
    // The list the shell read earlier, for another profile.
    await tester.runAsync(
      () => toolsAvailability.refresh(resolvedProfile('other')),
    );
    final dir = tempDir('call_site_fallback');
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      profileResolver: resolver,
      providers: [
        Provider<HermesRepositories?>.value(value: repositories),
        Provider<MediaStore?>.value(
          value: MediaStore(
            source: HermesMediaSource(() => server.client()),
            cacheDirectory: () async => dir,
            actions: FakeMediaActions(),
          ),
        ),
        ChangeNotifierProvider<FilesAvailability?>.value(
          value: filesAvailability,
        ),
        ChangeNotifierProvider<ToolsAvailability?>.value(
          value: toolsAvailability,
        ),
      ],
    );
    await openThread(tester, 'Field notes');
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (filesAvailability.support != FilesSupport.unknown) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    server.requests.clear();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openActivity(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('header-activity')));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  Future<void> tapFiles(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('activity-files-row')));
    await settle(tester);
  }

  Future<void> tapTools(WidgetTester tester) async {
    await openSidebarMore(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Tools'),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  Set<String?> profilesOf(Iterable<RequestOptions> requests) => {
    for (final r in requests) r.queryParameters['profile'] as String?,
  };

  Iterable<RequestOptions> fsReads() => server.requests.where(
    (r) => r.path.startsWith('/api/fs/') && r.path != '/api/fs/default-cwd',
  );

  group('a chat with no profile, launch profile work', () {
    testWidgets('Bot Screen asks for work', (tester) async {
      await pump(tester, ProfileResolver.known('work'));
      await openActivity(tester);

      expect(gateway.requestOf('display.status')['params'], {
        'profile': 'work',
      });
      await close(tester);
    });

    testWidgets('Files reads work', (tester) async {
      await pump(tester, ProfileResolver.known('work'));
      await openActivity(tester);
      await tapFiles(tester);

      expect(fsReads(), isNotEmpty);
      expect(profilesOf(fsReads()), {'work'});
      await close(tester);
    });

    testWidgets('Tools reads work, not the profile last read', (tester) async {
      await pump(tester, ProfileResolver.known('work'));
      await tapTools(tester);

      final reads = server.requestsTo('GET', '/api/tools/toolsets');
      expect(reads, isNotEmpty);
      expect(profilesOf(reads), {'work'});
      await close(tester);
    });
  });

  group('a chat with no profile and no launch profile known', () {
    ProfileResolver unknown() =>
        ProfileResolver(() => Future.error(notFound()));

    testWidgets('Bot Screen asks for nothing and shows no card', (
      tester,
    ) async {
      await pump(tester, unknown());
      await openActivity(tester);

      expect(
        gateway.requests.where((r) => r['method'] == 'display.status'),
        [],
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await close(tester);
    });

    testWidgets('Files opens nothing and shows no spinner', (tester) async {
      await pump(tester, unknown());
      await openActivity(tester);
      await tapFiles(tester);

      expect(fsReads(), isEmpty);
      expect(find.byType(FilesScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await close(tester);
    });

    testWidgets('Tools opens nothing and shows no spinner', (tester) async {
      await pump(tester, unknown());
      await tapTools(tester);

      expect(server.requestsTo('GET', '/api/tools/toolsets'), isEmpty);
      expect(find.byType(ToolsScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await close(tester);
    });
  });

  group('the launch profile could not be read the first time', () {
    /// Fails once with a server error, then answers `work`.
    ProfileResolver flaky() {
      var calls = 0;
      return ProfileResolver(() async {
        if (calls++ == 0) {
          final options = RequestOptions(path: '/api/profiles/active');
          throw DioException(
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 500,
            ),
          );
        }
        return (active: 'main', current: 'work');
      });
    }

    testWidgets('Files recovers on the next tap', (tester) async {
      await pump(tester, flaky());
      await openActivity(tester);
      await tapFiles(tester);
      expect(find.byType(FilesScreen), findsNothing);

      await tapFiles(tester);

      expect(find.byType(FilesScreen), findsOneWidget);
      expect(profilesOf(fsReads()), {'work'});
      await close(tester);
    });

    testWidgets('Tools recovers on the next tap', (tester) async {
      await pump(tester, flaky());
      await tapTools(tester);
      expect(find.byType(ToolsScreen), findsNothing);

      await tapTools(tester);

      expect(find.byType(ToolsScreen), findsOneWidget);
      expect(profilesOf(server.requestsTo('GET', '/api/tools/toolsets')), {
        'work',
      });
      await close(tester);
    });
  });
}
