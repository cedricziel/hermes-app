import 'dart:async';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_guard.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_picker_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

const _demo = '/home/me/code/demo';
const _other = '/home/me/code/other';

/// A resolver that knows the launch profile but whose own read finds none,
/// as the chat's first list sees it: the chat has no profile of its own and
/// the call sites' fallback is what names one.
class _Unlisted extends ProfileResolver {
  _Unlisted(super.name) : super.known();

  @override
  Future<String?> load() async => null;
}

ProfileResolver _unknown() {
  final options = RequestOptions(path: '/api/profiles/active');
  return ProfileResolver(
    () => Future.error(
      DioException(
        requestOptions: options,
        response: Response<Object?>(requestOptions: options, statusCode: 404),
      ),
    ),
  );
}

/// The workspace catalog, a move and the re-read after a lost move answer,
/// for a chat with no profile of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late ChatController chat;
  late AttentionNotifier attention;
  late List<Map<String, Object?>> moves;

  Future<void> open(ProfileResolver resolver) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    moves = [];
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'detail': 'x'}, status: 404)
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {
            ...sessionRow(id: 's1', title: 'Chat s1', lastActive: 1780000000),
            'cwd': _demo,
            'git_repo_root': _demo,
          },
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on('GET', '/api/chat/workspaces', {
        'projects': [],
        'repos': [],
        'default_cwd': _demo,
        'home': '/home/me',
        'scan_enabled': true,
      })
      ..on('GET', '/api/config', {
        'desktop': {'repo_scan_roots': <Object?>[]},
      })
      ..on('GET', '/api/sessions/s1', {
        ...sessionRow(id: 's1', title: 'Chat s1'),
        'cwd': _demo,
        'git_repo_root': _demo,
      });
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      profileResolver: resolver,
      repository: HermesChatRepository(server.client().raw),
      workspaces: HermesWorkspacesRepository(server.client().raw, (
        method,
        params, {
        required timeout,
      }) {
        moves.add({'method': method, ...params});
        // The answer is lost: the controller reads the chat's row again.
        return Completer<Map<String, Object?>>().future.timeout(timeout);
      }, timeout: const Duration(milliseconds: 50)),
      activity: ValueNotifier(true),
      transport: FakeChatTransport(),
      attention: attention,
      report: (_) {},
    );
    await chat.loadThreads();
    expect(chat.profile, isNull);
  }

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  Set<String?> profilesOf(Iterable<RequestOptions> requests) => {
    for (final r in requests) r.queryParameters['profile'] as String?,
  };

  group('launch profile work', () {
    test('the catalog is read for work', () async {
      await open(_Unlisted('work'));

      expect(chat.workspaceCatalog(), isNotNull);
      await pumpEventQueue();

      final reads = server.requestsTo('GET', '/api/chat/workspaces');
      expect(reads, isNotEmpty);
      expect(profilesOf(reads), {'work'});
    });

    test('a move names work, and so does the re-read after it', () async {
      await open(_Unlisted('work'));
      chat.select('s1');
      await pumpEventQueue();

      await chat.moveWorkspace(chat.threads.single, _other);

      expect(moves.map((m) => m['profile']).toSet(), {'work'});
      final rereads = server.requestsTo('GET', '/api/sessions/s1');
      expect(rereads, isNotEmpty);
      expect(profilesOf(rereads), {'work'});
    });
  });

  group('no profile known', () {
    test('the catalog is not read', () async {
      await open(_unknown());

      expect(chat.workspaceCatalog(), isNull);
      await pumpEventQueue();

      expect(server.requestsTo('GET', '/api/chat/workspaces'), isEmpty);
    });

    test('a move sends nothing and reads nothing', () async {
      await open(_unknown());
      chat.select('s1');
      await pumpEventQueue();

      final block = await chat.moveWorkspace(chat.threads.single, _other);

      expect(block, WorkspaceMoveBlock.notAvailable);
      expect(moves, isEmpty);
      expect(server.requestsTo('GET', '/api/sessions/s1'), isEmpty);
    });
  });

  group('the picker sheet', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.runAsync(() => open(_Unlisted('work')));
      chat.workspaceCatalog();
      await tester.runAsync(() => pumpEventQueue());
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      unawaited(
        showWorkspacePicker(
          context,
          chat: chat,
          guard: WorkspaceGuard(chat),
          onPick: (_) async => true,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('browses the folder in work', (tester) async {
      await openPicker(tester);

      final reads = server.requestsTo('GET', '/api/fs/list');
      expect(reads, isNotEmpty);
      expect(profilesOf(reads), {'work'});
      await tester.pumpWidget(const SizedBox());
    });
  });
}
