import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

class _ReadyAuth extends AuthController {
  @override
  HermesConnectionState get state => HermesConnectionState.ready;
  @override
  bool get protectedRequestsAllowed => true;
}

void main() {
  testWidgets('peer switch clears Forward and adds no Back route', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeHermesServer()
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ]);
    final key = GlobalKey<NavigatorState>();
    final history = DesktopNavigationHistory(
      canNavigate: () => true,
      resolve: (_) async => null,
    );
    addTearDown(history.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(create: (_) => _ReadyAuth()),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          navigatorKey: key,
          navigatorObservers: [history],
          builder: (_, child) =>
              DesktopNavigationHistoryScope(history: history, child: child!),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            kanbanBuilder: (_) => const Scaffold(body: Text('board')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            arguments: WorkersNavigationTarget(boardSlug: 'ops'),
          ),
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
    await tester.tap(find.text('Kanban'));
    await tester.pumpAndSettle();
    expect(find.text('board'), findsOneWidget);
    expect(history.canGoForward, isFalse);
    expect(key.currentState!.canPop(), isFalse);
  });
}
