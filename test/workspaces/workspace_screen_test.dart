import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/pump_chat.dart';

const _catalog = {
  'projects': [
    {
      'id': 'p1',
      'name': 'Demo',
      'folders': [
        {'path': '/srv/demo', 'is_primary': true},
      ],
    },
  ],
  'repos': [],
  'default_cwd': '/srv/home-project',
  'home': '/srv',
  'scan_enabled': false,
};

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late HermesWorkspacesRepository workspaces;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/chat/workspaces', _catalog)
      ..on('GET', '/api/fs/list', {'entries': []});
    transport = FakeChatTransport();
    workspaces = HermesWorkspacesRepository(
      server.client().raw,
      (method, params, {required timeout}) async => {},
    );
  });

  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(findAppIcon(AppIcons.compose).first);
    await tester.pumpAndSettle();
    await idle(tester);
    await tester.tap(find.byType(WorkingDirectoryRow));
    await idle(tester);
    expect(find.byType(WorkspacePickerView), findsOneWidget);
  }

  testWidgets('the picker closes with its close button, picking nothing', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      workspaces: workspaces,
    );
    await openPicker(tester);

    await tester.tap(
      find.byKey(const Key('settings-cancel')).evaluate().isEmpty
          ? find.byType(CloseButton)
          : find.byKey(const Key('settings-cancel')),
    );
    await idle(tester);

    expect(find.byType(WorkspacePickerView), findsNothing);
    expect(find.textContaining('home-project'), findsWidgets);
  });

  testWidgets('taking a project keeps it for the first send and not before', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      workspaces: workspaces,
    );
    await openPicker(tester);

    await tester.tap(find.text('Demo').last);
    await idle(tester);

    expect(find.byType(WorkspacePickerView), findsNothing);
    expect(transport.sends, isEmpty);
    expect(find.textContaining('/srv/demo'), findsWidgets);
  });

  testWidgets('App Lock closes the picker and drops the pick', (tester) async {
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
      providers: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
    );
    await openPicker(tester);

    // The lock as the platform engages it, without pausing the test's frames.
    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    await idle(tester);

    expect(lock.locked, isTrue);
    expect(find.byType(WorkspacePickerView), findsNothing);
  });
}
