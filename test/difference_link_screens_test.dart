import 'dart:async';

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

  testWidgets('Plugins without plugins have no link', (t) async {
    server.on('GET', '/api/dashboard/plugins/hub', hubBody([]));
    await pumpScreen(
      t,
      PluginsScreen(
        repository: HermesPluginManagerRepository(server.client().raw),
      ),
    );
    expect(find.text('No plugins installed'), findsOneWidget);
    expect(find.text("What's the difference?"), findsNothing);
  });

  testWidgets('MCP servers without servers have no link', (t) async {
    server
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
    await pumpScreen(
      t,
      McpServersScreen(
        repository: HermesMcpRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
      ),
    );
    expect(find.text('No MCP servers on "work"'), findsOneWidget);
    expect(find.text("What's the difference?"), findsNothing);
  });

  /// The link ends a loaded list, so none of the states without one show it.
  group('has no link without a list', () {
    final link = find.text("What's the difference?");

    /// Mounts [screen] and lets it settle, or, for a held-back answer, runs a
    /// few frames only, since the spinner never settles.
    Future<void> mount(
      WidgetTester t,
      Widget screen, {
      bool settle = true,
    }) async {
      t.view
        ..physicalSize = const Size(420, 1000)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: screen));
      if (settle) {
        await t.pumpAndSettle();
      } else {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    Widget skills() => SkillsScreen(
      repository: HermesSkillsRepository(server.client().raw),
      chatProfile: 'default',
    );
    Widget helperModels() => HelperModelsScreen(
      repository: HermesModelsRepository(server.client().raw),
      profile: 'work',
    );
    Widget plugins() => PluginsScreen(
      repository: HermesPluginManagerRepository(server.client().raw),
    );
    Widget mcp() => McpServersScreen(
      repository: HermesMcpRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );

    // A held-back answer, completed at the end so no request is left open.
    Completer<FakeResponse> hold(String path) {
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', path, (_) => answer.future);
      addTearDown(() {
        if (!answer.isCompleted) answer.complete((status: 500, body: null));
      });
      return answer;
    }

    testWidgets('Skills while loading', (t) async {
      hold('/api/skills');
      await mount(t, skills(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Skills that failed to load', (t) async {
      server.on('GET', '/api/skills', {'detail': 'boom'}, status: 500);
      await mount(t, skills());
      expect(find.text('Could not load skills'), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Skills without skills', (t) async {
      server.on('GET', '/api/skills', []);
      await mount(t, skills());
      expect(find.text('This profile has no skills yet.'), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Skills with a search that matches nothing', (t) async {
      server.on('GET', '/api/skills', [
        skillRow(name: 'apple-notes', description: 'Read', category: 'apple'),
      ]);
      await mount(t, skills());
      expect(link, findsOneWidget);
      await t.enterText(find.byType(TextField), 'zzz');
      await t.pumpAndSettle();
      expect(find.text('No skills match.'), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Helper models while loading', (t) async {
      hold('/api/model/auxiliary');
      server.on('GET', '/api/model/options', {'providers': []});
      await mount(t, helperModels(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Helper models that failed to load', (t) async {
      server.on('GET', '/api/model/auxiliary', {'detail': 'x'}, status: 500);
      server.on('GET', '/api/model/options', {'providers': []});
      await mount(t, helperModels());
      expect(find.text('Retry'), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Plugins while loading', (t) async {
      hold('/api/dashboard/plugins/hub');
      await mount(t, plugins(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('Plugins that failed to load', (t) async {
      server.on('GET', '/api/dashboard/plugins/hub', {
        'detail': 'x',
      }, status: 500);
      await mount(t, plugins());
      expect(find.text('Could not load plugins'), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('MCP servers while loading', (t) async {
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );
      hold('/api/mcp/servers');
      await mount(t, mcp(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(link, findsNothing);
    });

    testWidgets('MCP servers that failed to load', (t) async {
      server
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on('GET', '/api/mcp/servers', {'detail': 'x'}, status: 500);
      await mount(t, mcp());
      expect(find.text('Could not load MCP servers'), findsOneWidget);
      expect(link, findsNothing);
    });
  });
}
