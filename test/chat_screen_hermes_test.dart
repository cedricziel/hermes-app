import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bots/bots_screen.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/mock_chat_data.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/profiles_screen.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart' show openSidebarMore, openThread;

/// The chat screen against a fake Hermes dashboard, through the real
/// generated client: HTTP → `DefaultApi` → [HermesChatRepository] → mapper →
/// `flutter_chat_ui`.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
      ]),
    );
    server.on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        messageRow(
          id: 2,
          role: 'assistant',
          content: 'A connection reset during upload.',
          toolCalls: [functionCall('search_logs', '{"window":"02:10"}')],
        ),
      ]),
    );
    server.on(
      'GET',
      '/api/sessions/s2/messages',
      messageListBody('s2', [
        messageRow(id: 3, role: 'user', content: 'Draft the release notes.'),
        messageRow(id: 4, role: 'assistant', content: 'Here is a first pass.'),
      ]),
    );
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
          theme: buildHermesLightTheme(),
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            bots: HermesBotsRepository(server.client().raw),
            plugins: HermesPluginManagerRepository(server.client().raw),
            mcp: HermesMcpRepository(server.client().raw),
          ),
        ),
      ),
    );
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  testWidgets('shows a spinner while the session list loads', (tester) async {
    await pumpChat(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists the sessions the dashboard returned', (tester) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text('Run failure'), findsWidgets);
    expect(find.text('Release notes'), findsOneWidget);
  });

  testWidgets('does not show the mock threads', (tester) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text(buildMockThreads().first.title), findsNothing);
  });

  testWidgets('starts on the welcome view without opening a session', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text('Why did the run fail?'), findsNothing);
    expect(server.requestsTo('GET', '/api/sessions/s1/messages'), isEmpty);
    expect(server.requestsTo('GET', '/api/sessions/s2/messages'), isEmpty);
  });

  testWidgets('opens a session and renders its messages', (tester) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();
    await openThread(tester, 'Run failure');

    expect(inTranscript('Why did the run fail?'), findsOneWidget);
    expect(inTranscript('A connection reset during upload.'), findsOneWidget);
  });

  testWidgets('renders a tool call from the API as a ToolCallCard', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();
    await openThread(tester, 'Run failure');

    final card = tester.widget<ToolCallCard>(find.byType(ToolCallCard));
    expect(card.call.name, 'search_logs');
  });

  testWidgets('does not fetch a session\'s messages until it is opened', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(server.requestsTo('GET', '/api/sessions/s2/messages'), isEmpty);
  });

  testWidgets('opening another session fetches and shows its messages', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();

    expect(inTranscript('Draft the release notes.'), findsOneWidget);
    expect(inTranscript('Why did the run fail?'), findsNothing);
  });

  testWidgets('reopening a session does not fetch its messages again', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run failure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('GET', '/api/sessions/s2/messages'), hasLength(1));
    expect(inTranscript('Draft the release notes.'), findsOneWidget);
  });

  testWidgets('a failed session list shows an error with a working retry', (
    tester,
  ) async {
    server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not load your chats'), findsOneWidget);

    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your chats'), findsNothing);
    expect(find.text('Run failure'), findsWidgets);
  });

  testWidgets('an account with no sessions lands on the welcome view', (
    tester,
  ) async {
    server.on('GET', '/api/sessions', sessionListBody([]));
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text(kStarterPrompts.first), findsOneWidget);
  });

  testWidgets('a failed message fetch tells the user and retries on reopen', (
    tester,
  ) async {
    server.on('GET', '/api/sessions/s2/messages', {'detail': 'x'}, status: 500);
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this chat'), findsOneWidget);

    server.on(
      'GET',
      '/api/sessions/s2/messages',
      messageListBody('s2', [
        messageRow(id: 3, role: 'user', content: 'Draft the release notes.'),
      ]),
    );
    await tester.tap(find.text('Run failure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();

    expect(inTranscript('Draft the release notes.'), findsOneWidget);
  });

  testWidgets('the sidebar opens the profiles of the connected dashboard', (
    tester,
  ) async {
    server
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work', displayName: 'Work')]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await openSidebarMore(tester);

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilesScreen), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('the sidebar opens the bots of the connected dashboard', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([platformRow(id: 'telegram', name: 'Telegram')]),
    );
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await openSidebarMore(tester);

    await tester.tap(find.text('Bots'));
    await tester.pumpAndSettle();

    expect(find.byType(BotsScreen), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
  });

  testWidgets('the sidebar opens the plugins of the connected dashboard', (
    tester,
  ) async {
    server.on('GET', '/api/dashboard/plugins/hub', {
      'plugins': [
        {'name': 'netbox', 'runtime_status': 'enabled'},
      ],
    });
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await openSidebarMore(tester);

    await tester.tap(find.text('Plugins'));
    await tester.pumpAndSettle();

    expect(find.byType(PluginsScreen), findsOneWidget);
    expect(find.text('netbox'), findsOneWidget);
  });

  testWidgets('the management entries stay behind More until it is opened', (
    tester,
  ) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    expect(find.text('Profiles'), findsNothing);
    expect(find.text('Bots'), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Profiles'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Profiles'), findsNothing);
  });

  testWidgets('the Plugins entry follows Profiles and Bots', (tester) async {
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await openSidebarMore(tester);
    final profiles = tester.getTopLeft(find.text('Profiles')).dy;
    final bots = tester.getTopLeft(find.text('Bots')).dy;
    final plugins = tester.getTopLeft(find.text('Plugins')).dy;
    expect(profiles, lessThan(bots));
    expect(bots, lessThan(plugins));
  });

  testWidgets('a narrow layout closes the drawer when it opens the bots', (
    tester,
  ) async {
    server.on('GET', '/api/messaging/platforms', platformListBody([]));
    await pumpChat(tester);
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await openSidebarMore(tester);
    await tester.tap(find.text('Bots'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(BotsScreen), findsNothing);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('the sidebar opens the MCP servers of the active profile', (
    tester,
  ) async {
    server
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.grafana.com/mcp'),
        ]),
      );
    await pumpChat(tester);
    await tester.pumpAndSettle();

    await openSidebarMore(tester);

    await tester.tap(find.text('MCP servers'));
    await tester.pumpAndSettle();

    expect(find.byType(McpServersScreen), findsOneWidget);
    expect(find.text('Profile: work'), findsOneWidget);
    expect(find.text('grafana'), findsWidgets);
  });

  testWidgets(
    'a narrow layout closes the drawer when it opens the MCP servers',
    (tester) async {
      server
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
      await pumpChat(tester);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await openSidebarMore(tester);
      await tester.tap(find.text('MCP servers'));
      await tester.pumpAndSettle();
      expect(find.byType(McpServersScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(McpServersScreen), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    },
  );
}
