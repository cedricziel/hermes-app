import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoMenuItem;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/pump_chat.dart' show composerField;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _notes = '/srv/field-notes';
const _soil = '/srv/soil-survey';
const _weather = '/srv/code/weather-station';

const _catalog = {
  'projects': [
    {
      'id': 'p_notes',
      'name': 'Field notes',
      'folders': [
        {'path': _notes, 'is_primary': true},
      ],
    },
    {
      'id': 'p_soil',
      'name': 'Soil survey',
      'folders': [
        {'path': _soil, 'is_primary': true},
      ],
    },
  ],
  'repos': [
    {
      'root': _weather,
      'label': 'weather-station',
      'sessions': 8,
      'last_active': 1780000500.0,
    },
  ],
  'default_cwd': _notes,
  'home': '/srv',
  'scan_enabled': true,
};

Map<String, Object?> _row(String id, String title, String cwd, double at) => {
  ...sessionRow(id: id, title: title, lastActive: at),
  'cwd': cwd,
  'git_branch': 'main',
  'git_repo_root': cwd,
};

/// A new chat in a chosen folder and moving it, on a phone, an iPad and a
/// desktop window, on the Mac and with Android chrome, light and dark; the
/// states of the picker (loading, offline, error); and an older server where
/// nothing about folders shows.
///
/// It mounts [ChatScreen] rather than the whole app: the app shell needs a
/// signed-in `AuthController` and a real gateway socket, and the folder row,
/// header line, picker and details all belong to the chat screen.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late List<(String, Map<String, Object?>)> rpcCalls;
  late Future<Map<String, Object?>> Function(String, Map<String, Object?>) rpc;
  late Completer<FakeResponse> catalogGate;

  setUp(() {
    rpcCalls = [];
    rpc = (method, params) async => method == 'session.workspace.move'
        ? {
            'cwd': params['cwd'],
            'git_repo_root': params['cwd'],
            'branch': 'main',
          }
        : {'items': <Object?>[]};
    transport = FakeChatTransport();
    catalogGate = Completer<FakeResponse>();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          _row('s1', 'Soil moisture notes', _notes, 1780000900),
          _row('s2', 'Station firmware', _weather, 1780000500),
        ]),
      )
      ..on('GET', '/api/chat/workspaces', _catalog)
      ..on('GET', '/api/config', {
        'desktop': {
          'repo_scan_roots': ['/srv/code'],
        },
      })
      ..on('GET', '/api/fs/list', {
        'entries': [
          {'name': 'field-notes', 'path': _notes, 'isDirectory': true},
          {'name': 'soil-survey', 'path': _soil, 'isDirectory': true},
          {'name': 'code', 'path': '/srv/code', 'isDirectory': true},
          {'name': 'README.md', 'path': '/srv/README.md', 'isDirectory': false},
        ],
      });
    for (final id in ['s1', 's2', 's9']) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
  });

  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
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
    Brightness brightness = Brightness.light,
    TargetPlatform? platform,
  }) => pumpScreen(
    tester,
    shots,
    ChatScreen(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      workspaces: HermesWorkspacesRepository(server.client().raw, (
        method,
        params, {
        required timeout,
      }) {
        rpcCalls.add((method, params));
        return rpc(method, params);
      }),
    ),
    size: size,
    brightness: brightness,
    platform: platform,
  );

  Future<void> newChat(WidgetTester tester) async {
    await tester.tap(findAppIcon(AppIcons.compose).first);
    await tester.pumpAndSettle();
    await idle(tester);
  }

  Future<void> startAndPick(
    WidgetTester tester,
    ScreenshotRecorder shots,
  ) async {
    await newChat(tester);
    expect(find.byType(WorkingDirectoryRow), findsOneWidget);
    await shots.capture(tester, 'new-chat');
    await tester.tap(find.byType(WorkingDirectoryRow));
    await idle(tester);
    await shots.capture(tester, 'picker');
    await tester.tap(find.text('Soil survey').last);
    await idle(tester);
    await shots.capture(tester, 'picked');
  }

  Future<void> sendAndBind(
    WidgetTester tester,
    ScreenshotRecorder shots,
  ) async {
    await tester.enterText(composerField, 'Summarise the soil moisture data');
    await tester.pump();
    await tester.tap(findAppIcon(AppIcons.sendArrow).first);
    await tester.pump();
    final send = transport.sends.last;
    expect(send.workspace?.path, _soil);
    send
      ..emit(const ThreadBound('s9'))
      ..emit(const WorkspaceBound(cwd: _soil, branch: 'main'))
      ..emit(const ReplyCompleted('The readings look healthy.'))
      ..finish();
    await idle(tester);
    await shots.capture(tester, 'sent');
  }

  Future<void> openDetails(WidgetTester tester) async {
    final button = find.byKey(const Key('folder-toolbar-button'));
    await tester.tap(
      button.evaluate().isNotEmpty ? button : find.byType(WorkingDirectoryLine),
    );
    await idle(tester);
  }

  Future<void> moveChat(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required String confirm,
  }) async {
    await openDetails(tester);
    await shots.capture(tester, 'details');
    await tester.tap(find.byKey(const Key('working-directory-change')));
    await idle(tester);
    await shots.capture(tester, 'move-picker');
    await tester.tap(find.text('Field notes').last);
    await idle(tester);
    await shots.capture(tester, 'confirm');
    await tester.tap(find.text(confirm));
    await idle(tester);
    await shots.capture(tester, 'moved');
    expect(
      rpcCalls.where((c) => c.$1 == 'session.workspace.move'),
      hasLength(1),
    );
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('working-directory-close')));
    await idle(tester);
  }

  Future<void> showFolderGrouping(
    WidgetTester tester,
    ScreenshotRecorder shots,
  ) async {
    if (find.byType(ThreadSidebar).evaluate().isEmpty &&
        find.byType(BackButton).evaluate().isNotEmpty) {
      // A phone's chat is a page over the list.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await openSidebar(tester);
    final group = find.byTooltip('Group chats');
    if (group.evaluate().isNotEmpty) {
      await tester.tap(group.first);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text('Folder'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is CheckedPopupMenuItem<ThreadGrouping> ||
                    w is CupertinoMenuItem,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }
    await shots.capture(tester, 'regrouped');
    expect(find.text('field-notes'), findsWidgets);
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;
    for (final (name, size, platform, confirm) in [
      ('android', phoneSize, TargetPlatform.android, 'Change folder'),
      ('desktop', desktopSize, TargetPlatform.windows, 'Change folder'),
      ('mac', desktopSize, TargetPlatform.macOS, 'Change folder'),
      if (!dark)
        ('ipad', const Size(820, 1180), TargetPlatform.iOS, 'Change folder'),
    ]) {
      testWidgets('$name ($mode): pick a project, send, move', (tester) async {
        final shots = ScreenshotRecorder('working-directory-$name-$mode');
        await pumpChat(
          tester,
          shots,
          size: size,
          brightness: brightness,
          platform: platform,
        );
        await startAndPick(tester, shots);
        await sendAndBind(tester, shots);
        await moveChat(tester, shots, confirm: confirm);
        await closeSheet(tester);
        await shots.capture(tester, 'after');
        await showFolderGrouping(tester, shots);
      });
    }
  }

  testWidgets('phone (German): row, picker and details', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final shots = ScreenshotRecorder('working-directory-phone-de');
    await pumpChat(tester, shots, size: phoneSize);
    await newChat(tester);
    await shots.capture(tester, 'new-chat');
    await tester.tap(find.byType(WorkingDirectoryRow));
    await idle(tester);
    await shots.capture(tester, 'picker');
  });

  testWidgets('phone: loading, then the projects could not be read', (
    tester,
  ) async {
    server.onRequest('GET', '/api/chat/workspaces', (_) => catalogGate.future);
    final shots = ScreenshotRecorder('working-directory-phone-states');
    await pumpChat(tester, shots, size: phoneSize);
    await tester.tap(findAppIcon(AppIcons.compose).first);
    await tester.pump();
    await idle(tester);
    await shots.capture(tester, 'row-loading');
    catalogGate.complete((status: 500, body: {'detail': 'nope'}));
    await idle(tester);
    await shots.capture(tester, 'row-failed');
    // Opening the picker reads the projects again.
    final second = Completer<FakeResponse>();
    server.onRequest('GET', '/api/chat/workspaces', (_) => second.future);
    await tester.tap(find.byType(WorkingDirectoryRow));
    await tester.pump(const Duration(milliseconds: 300));
    await idle(tester);
    await shots.capture(tester, 'picker-loading');
    second.complete((status: 500, body: {'detail': 'nope'}));
    await idle(tester);
    await shots.capture(tester, 'picker-error');
    expect(find.textContaining('t load your projects'), findsOneWidget);
  });

  testWidgets('phone: offline', (tester) async {
    server.onRequest(
      'GET',
      '/api/chat/workspaces',
      (_) => throw Exception('no connection'),
    );
    server.onRequest(
      'GET',
      '/api/fs/list',
      (_) => throw Exception('no connection'),
    );
    final shots = ScreenshotRecorder('working-directory-phone-offline');
    await pumpChat(tester, shots, size: phoneSize);
    await newChat(tester);
    await shots.capture(tester, 'new-chat');
    await tester.tap(find.byType(WorkingDirectoryRow));
    await idle(tester);
    await shots.capture(tester, 'picker');
    expect(find.textContaining('offline'), findsWidgets);
  });

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: an older server shows no row and no picker', (
      tester,
    ) async {
      server
        ..on('GET', '/api/chat/workspaces', {
          'detail': 'Not Found',
        }, status: 404)
        ..on('GET', '/api/fs/list', {'detail': 'Not Found'}, status: 404);
      final shots = ScreenshotRecorder('working-directory-$name-old-server');
      await pumpChat(tester, shots, size: size);
      await newChat(tester);
      await shots.capture(tester, 'new-chat');

      expect(find.byType(WorkingDirectoryRow), findsNothing);
      expect(find.textContaining('Runs in'), findsNothing);
      expect(find.textContaining('Couldn'), findsNothing);
      expect(rpcCalls, isEmpty);
    });
  }
}
