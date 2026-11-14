import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/settings/helper_models_screen.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/tools/widgets/tools_difference_sheet.dart';

import 'hermes_plugin_manager_repository_test.dart' show hubBody, hubRow;
import 'support/fake_hermes_server.dart';

/// The "What's the difference?" link that ends the Skills, Plugins, MCP
/// servers and Helper models screens opens the same sheet as the Tools one.
void main() {
  late FakeHermesServer server;
  setUp(() => server = FakeHermesServer());

  Future<void> pumpScreen(WidgetTester t, Widget screen) async {
    t.view
      ..physicalSize = const Size(420, 1000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: screen));
    await t.pumpAndSettle();
  }

  Future<void> expectLinkOpensTheSheet(WidgetTester t) async {
    final link = find.text("What's the difference?");
    expect(link, findsOneWidget);
    await t.ensureVisible(link);
    await t.tap(link);
    await t.pumpAndSettle();
    expect(find.byType(ToolsDifferenceSheet), findsOneWidget);
    expect(find.text('Tools, skills, plugins and MCP servers'), findsOneWidget);
    for (final term in ['Tools:', 'Skills:', 'Plugins:', 'MCP servers:']) {
      expect(
        t
            .widgetList<RichText>(find.byType(RichText))
            .where((w) => w.text.toPlainText().startsWith(term)),
        hasLength(1),
        reason: term,
      );
    }
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.byType(ToolsDifferenceSheet), findsNothing);
  }

  testWidgets('Skills', (t) async {
    server.on('GET', '/api/skills', [
      skillRow(name: 'apple-notes', description: 'Read', category: 'apple'),
    ]);
    await pumpScreen(
      t,
      SkillsScreen(
        repository: HermesSkillsRepository(server.client().raw),
        chatProfile: 'default',
      ),
    );
    await expectLinkOpensTheSheet(t);
  });

  testWidgets('Plugins', (t) async {
    server.on('GET', '/api/dashboard/plugins/hub', hubBody([hubRow('netbox')]));
    await pumpScreen(
      t,
      PluginsScreen(
        repository: HermesPluginManagerRepository(server.client().raw),
      ),
    );
    await expectLinkOpensTheSheet(t);
  });

  testWidgets('MCP servers keep their note and add the link under it', (
    t,
  ) async {
    server
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.example.com/mcp'),
        ]),
      );
    await pumpScreen(
      t,
      McpServersScreen(
        repository: HermesMcpRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
      ),
    );
    final note = find.textContaining('Changes apply from the next chat');
    expect(note, findsOneWidget);
    expect(
      t.getTopLeft(find.text("What's the difference?")).dy,
      greaterThan(t.getBottomLeft(note).dy),
    );
    await expectLinkOpensTheSheet(t);
  });

  testWidgets('Helper models', (t) async {
    server
      ..on('GET', '/api/model/auxiliary', {
        'tasks': [
          {'task': 'vision', 'provider': 'auto', 'model': ''},
        ],
      })
      ..on('GET', '/api/model/options', {'providers': []});
    await pumpScreen(
      t,
      HelperModelsScreen(
        repository: HermesModelsRepository(server.client().raw),
        profile: 'work',
      ),
    );
    await expectLinkOpensTheSheet(t);
  });
}
