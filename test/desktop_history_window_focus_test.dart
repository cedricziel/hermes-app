import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

class _ReadyAuth extends AuthController {
  _ReadyAuth(this.client);
  final HermesApiClient client;
  @override
  HermesConnectionState get state => HermesConnectionState.ready;
  @override
  bool get protectedRequestsAllowed => true;
  @override
  HermesApiClient get api => client;
  @override
  String get baseUrl => 'https://hermes.test';
}

void main() {
  late FakeHermesServer server;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late DesktopNavigationHistory history;
  late NavigatorState navigator;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ]);
    host = FakeConversationWindowHost();
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      ownerKey: () => 'test-owner',
      connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
      headers: ({rejected}) async => const {},
    );
    final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    await tester.runAsync(lock.load);
    addTearDown(() {
      windows.dispose();
      host.dispose();
      lock.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => _ReadyAuth(server.client()),
          ),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: lock),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider<ConversationWindows?>.value(value: windows),
        ],
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();
    navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    history = DesktopNavigationHistoryScope.maybeOf(navigator.context)!;
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            arguments: WorkersNavigationTarget(boardSlug: 'ops'),
          ),
          builder: (_) => const Scaffold(body: Text('original workers')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
  }

  testWidgets('delayed Forward GET cannot cross key conversation focus', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(
      () => windows.open('thread', profile: null, title: 'Auxiliary'),
    );
    late Completer<FakeResponse> boards;
    late Future<void> replay;
    await tester.runAsync(() async {
      boards = Completer<FakeResponse>();
      final requested = Completer<void>();
      server.onRequest('GET', '/api/plugins/kanban/boards', (_) {
        requested.complete();
        return boards.future;
      });
      replay = history.forward();
      await requested.future;
    });
    await host.call('focused', {'window_id': 'w0', 'focused': true});
    await tester.pump();
    await tester.runAsync(() async {
      boards.complete((
        status: 200,
        body: {
          'boards': [
            {'slug': 'ops'},
          ],
        },
      ));
      await replay;
    });
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isFalse);
    expect(history.canGoForward, isFalse);
    expect(
      server.requests.where((r) => r.path.endsWith('/workers/active')),
      isEmpty,
    );
    host.focusMain();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
  });

  testWidgets(
    'brief auxiliary focus cancels pending Forward after main returns',
    (tester) async {
      await pump(tester);
      await tester.runAsync(
        () => windows.open('thread', profile: null, title: 'Auxiliary'),
      );
      late Completer<FakeResponse> boards;
      late Future<void> replay;
      await tester.runAsync(() async {
        boards = Completer<FakeResponse>();
        final requested = Completer<void>();
        server.onRequest('GET', '/api/plugins/kanban/boards', (_) {
          requested.complete();
          return boards.future;
        });
        replay = history.forward();
        await requested.future;
      });
      await host.call('focused', {'window_id': 'w0', 'focused': true});
      await tester.pump();
      host.focusMain();
      await tester.pump();
      await tester.runAsync(() async {
        boards.complete((
          status: 200,
          body: {
            'boards': [
              {'slug': 'ops'},
            ],
          },
        ));
        await replay;
      });
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
      expect(history.canGoForward, isTrue);
      expect(
        server.requests.where((r) => r.path.endsWith('/workers/active')),
        isEmpty,
      );
      host.focusMain();
      await tester.pumpAndSettle();
      expect(history.canGoForward, isTrue);
    },
  );

  testWidgets('native windowless state disables main history', (tester) async {
    await pump(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'hermes_app/app',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('windowless', true),
      ),
      (_) {},
    );
    await tester.pump();
    expect(history.canGoForward, isFalse);
    await history.forward();
    expect(navigator.canPop(), isFalse);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'hermes_app/app',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('windowless', false),
      ),
      (_) {},
    );
    await tester.pump();
    expect(history.canGoForward, isTrue);
  });
}
