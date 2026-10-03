import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// On a narrow shell the chat's own drawer only exists once its threads have
/// loaded, so until then it offers the shell's menu, or the other
/// destinations could not be reached.
void main() {
  late FakeHermesServer server;
  late int opened;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    opened = 0;
  });

  Future<void> pumpChat(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: ShellMenu(
            onOpen: () => opened++,
            child: ChatScreen(
              repository: HermesChatRepository(server.client().raw),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('offers the shell menu while the chats fail to load', (
    tester,
  ) async {
    server.on('GET', '/api/sessions', {'error': 'down'}, status: 500);

    await pumpChat(tester);
    expect(find.text('Could not load your chats'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell-menu')));

    expect(opened, 1);
  });

  testWidgets('offers the shell menu while the chats load', (tester) async {
    final answer = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions', (_) => answer.future);

    await pumpChat(tester, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell-menu')));

    expect(opened, 1);
    answer.complete((status: 200, body: {'sessions': <Object?>[]}));
    await tester.pumpAndSettle();
  });
}
