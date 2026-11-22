import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_share_inbox.dart';
import '../support/pump_chat.dart' show openSidebarMore;

/// The MCP servers screen opened from the sidebar works on the chat's own
/// profile, and only a chat with none falls back to the launch profile.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'home', isDefault: true),
          profileRow(name: 'work', displayName: 'Work assistant'),
        ]),
      )
      ..on('POST', '/api/profiles/active', {'ok': true})
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'home'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
  });

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
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
          builder: (_, child) => AppThemeScopes(child: child!),
          theme: buildHermesLightTheme(),
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            mcp: HermesMcpRepository(server.client().raw),
            transport: FakeChatTransport(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Set<String?> mcpProfiles() => {
    for (final r in server.requestsTo('GET', '/api/mcp/servers'))
      r.queryParameters['profile'] as String?,
  };

  Future<void> openMcp(WidgetTester tester) async {
    await openSidebarMore(tester);
    await tester.tap(find.text('MCP servers'));
    await tester.pumpAndSettle();
    expect(find.byType(McpServersScreen), findsOneWidget);
  }

  testWidgets('a chat with no profile of its own lists the launch profile', (
    tester,
  ) async {
    await pumpChat(tester);
    await openMcp(tester);

    expect(mcpProfiles(), {'home'});
  });

  testWidgets('a chat on work lists work while the launch profile is home', (
    tester,
  ) async {
    await pumpChat(tester);
    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await openSidebarMore(tester);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work assistant'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openMcp(tester);

    expect(mcpProfiles(), {'work'});
  });
}
