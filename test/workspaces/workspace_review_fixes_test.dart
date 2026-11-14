import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_guard.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/workspaces/folder_labels.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/pump_chat.dart';

import 'package:hermes_app/src/theme/app_icons.dart';

const _notes = '/srv/notes';
const _other = '/srv/other';

const _catalog = {
  'projects': [
    {
      'id': 'p1',
      'name': 'Notes',
      'folders': [
        {'path': _notes, 'is_primary': true},
      ],
    },
    {
      'id': 'p2',
      'name': 'Other',
      'folders': [
        {'path': _other, 'is_primary': true},
      ],
    },
  ],
  'repos': [],
  'default_cwd': _notes,
  'home': '/srv',
  'scan_enabled': false,
};

Map<String, Object?> _row(String id) => {
  ...sessionRow(id: id, title: 'Chat $id', lastActive: 1780000000),
  'cwd': _notes,
  'git_branch': 'main',
  'git_repo_root': _notes,
};

ChatThread _thread(String id, String? root) => ChatThread(
  id: id,
  title: id,
  updatedAt: DateTime.utc(2026, 1, 1),
  folderPath: root,
);

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late List<String> rpcMethods;
  late HermesWorkspacesRepository workspaces;

  setUp(() {
    rpcMethods = [];
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([_row('s1')]))
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
      ..on('GET', '/api/chat/workspaces', _catalog)
      ..on('GET', '/api/fs/list', {'entries': []});
    workspaces = HermesWorkspacesRepository(server.client().raw, (
      method,
      params, {
      required timeout,
    }) async {
      rpcMethods.add(method);
      return {'cwd': params['cwd']};
    });
  });

  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openChat(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('thread-s1')));
    await tester.pumpAndSettle();
    await idle(tester);
  }

  group('an older server', () {
    for (final oldServer in [true, false]) {
      testWidgets(
        oldServer
            ? 'Change Folder is disabled and sends nothing'
            : 'Change Folder is enabled on a server that has the routes',
        (tester) async {
          if (oldServer) {
            server
              ..on('GET', '/api/chat/workspaces', {
                'detail': 'Not Found',
              }, status: 404)
              ..on('GET', '/api/fs/list', {'detail': 'Not Found'}, status: 404);
          }
          final commands = MacCommandRegistry();
          addTearDown(commands.dispose);
          await pumpChatScreen(
            tester,
            server: server,
            transport: transport,
            workspaces: workspaces,
            platform: TargetPlatform.macOS,
            commands: commands,
          );
          await openChat(tester);

          final handler = commands.handlerFor(MacCommand.changeFolder);
          expect(handler?.enabled, !oldServer);
          if (oldServer) {
            commands.invoke(MacCommand.changeFolder);
            await idle(tester);
            expect(find.byType(WorkingDirectoryDetails), findsNothing);
            expect(find.byType(WorkspacePickerView), findsNothing);
            expect(rpcMethods, isEmpty);
          } else {
            commands.invoke(MacCommand.changeFolder);
            await idle(tester);
            expect(find.byType(WorkspacePickerView), findsOneWidget);
            // Opening the picker sends no move.
            expect(rpcMethods, isEmpty);
          }
        },
      );
    }
  });

  group('App Lock with details, the picker and the confirmation open', () {
    for (final (name, size, platform) in [
      ('a dialog layout', const Size(1400, 900), TargetPlatform.macOS),
      ('a phone sheet', const Size(390, 844), TargetPlatform.android),
    ]) {
      testWidgets('leaves no folder surface behind on $name', (tester) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'hermes.app_lock_enabled': true,
            });
        late AppLockController lock;
        await tester.runAsync(() async {
          lock = AppLockController(
            authenticator: FakeDeviceAuthenticator(),
            coverWhenInactive: false,
          );
          await lock.load();
        });
        addTearDown(lock.dispose);
        await pumpChatScreen(
          tester,
          server: server,
          transport: transport,
          workspaces: workspaces,
          platform: platform,
          size: size,
          providers: [
            ChangeNotifierProvider<AppLockController>.value(value: lock),
          ],
        );
        if (size.width < 500) {
          await tester.tap(find.byKey(const ValueKey('thread-s1')));
        } else {
          await tester.tap(find.byKey(const ValueKey('thread-s1')));
        }
        await tester.pumpAndSettle();
        await idle(tester);
        final mac = platform == TargetPlatform.macOS;
        await tester.tap(
          mac
              ? find.byKey(const Key('folder-toolbar-button'))
              : find.byType(WorkingDirectoryLine).first,
        );
        await idle(tester);
        await tester.tap(find.byKey(const Key('working-directory-change')));
        await idle(tester);
        await tester.tap(find.text('Other').last);
        await idle(tester);
        expect(find.text('Change folder'), findsOneWidget);

        lock.didChangeAppLifecycleState(AppLifecycleState.paused);
        await idle(tester);

        expect(find.text('Change folder'), findsNothing);
        expect(find.byType(WorkspacePickerView), findsNothing);
        expect(find.byType(WorkingDirectoryDetails), findsNothing);
        expect(rpcMethods, isEmpty);
      });
    }
  });

  testWidgets('a confirmed move that a reply overtook says so and sends '
      'nothing', (tester) async {
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      workspaces: workspaces,
    );
    await openChat(tester);
    await tester.tap(find.byType(WorkingDirectoryLine).first);
    await idle(tester);
    await tester.tap(find.byKey(const Key('working-directory-change')));
    await idle(tester);
    await tester.tap(find.text('Other').last);
    await idle(tester);
    expect(find.text('Change folder'), findsOneWidget);

    // A turn Hermes ran on its own starts while the person decides.
    transport.followUpStreams['s1']!.emit(const ReplyStarted());
    await idle(tester);
    await tester.tap(find.text('Change folder'));
    await idle(tester);

    expect(rpcMethods, isEmpty);
    expect(find.byKey(const Key('working-directory-blocked')), findsOneWidget);
  });

  test('a section header and the header line name a folder alike', () {
    // The reviewer's example: C runs below its root, D runs in its root.
    final c = _thread('c', '/x/app')..workingDirectory = '/x/app/src';
    final d = _thread('d', '/y/src')..workingDirectory = '/y/src';
    final universe = folderLabelUniverse([c, d]);

    final sections = {
      for (final s in groupThreadsByFolder([c, d])) s.id: s.label,
    };

    expect(sections['folder:/y/src'], 'src');
    // D's header line says what D's section says; C's different `src` is
    // told apart by its path.
    expect(folderLabelFor('/y/src', among: universe), 'src');
    expect(folderLabelFor('/x/app', among: universe), 'app');
    expect(folderLabelFor('/x/app/src', among: universe), '/x/app/src');
  });

  testWidgets('a draft whose first send failed keeps its picked folder '
      'visible', (tester) async {
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      workspaces: workspaces,
    );
    await tester.tap(findAppIcon(AppIcons.compose).first);
    await tester.pumpAndSettle();
    await idle(tester);
    await tester.tap(find.byType(WorkingDirectoryRow));
    await idle(tester);
    await tester.tap(find.text('Other').last);
    await idle(tester);
    await tester.enterText(composerField, 'hello');
    await tester.pump();
    await tester.tap(findAppIcon(AppIcons.sendArrow).first);
    await tester.pump();
    transport.sends.last
      ..fail()
      ..finish();
    await idle(tester);

    expect(find.byType(WorkingDirectoryRow), findsOneWidget);
    expect(find.textContaining('/srv/other'), findsWidgets);
  });

  test('a pick for a new chat closes when the open draft changes', () async {
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([_row('s1'), _row('s2')]),
    );
    server.on('GET', '/api/sessions/s2/messages', messageListBody('s2', []));
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      workspaces: workspaces,
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    await chat.loadThreads();
    chat.newThread();
    final guard = WorkspaceGuard(chat, trackSelection: true);
    addTearDown(guard.dispose);
    final same = WorkspaceGuard(chat);
    addTearDown(same.dispose);

    // A notification tap opens another chat while the picker is open.
    chat.select('s2');

    expect(guard.closed.value, isTrue);
    expect(
      same.closed.value,
      isFalse,
      reason: 'a guard that does not track the selection stays open',
    );
  });
}
