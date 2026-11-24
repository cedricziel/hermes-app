import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart'
    show ExportJsonOffer;
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';

import 'support/fake_hermes_server.dart';
import 'inline_dialog_extraction_expected.dart';

/// Pins the rendered tree of three pieces that screens used to build inline
/// (the Kanban Inspect dialog, the hub skill's install confirmation and the
/// Mac chat toolbar's "…" menu) so that building them from their own widgets
/// changes nothing a user or a screen reader can see. Each dump is the
/// element tree under the piece (each widget's type and its diagnostics
/// properties, indented; callbacks and hashes normalized), its texts and the
/// semantics tree, recorded from the screens as they were before the
/// extraction.

String _props(Widget w) {
  final props = <String>[];
  for (final p in w.toDiagnosticsNode().getProperties()) {
    if (p.level == DiagnosticLevel.hidden) continue;
    props.add('${p.name}: ${p.toDescription()}');
  }
  // Not in the widget's diagnostics: the "…" button's own size request.
  if (w is PopupMenuButton) props.add('iconSize: ${w.iconSize}');
  return props
      .join('; ')
      .replaceAll(RegExp(r'#[0-9a-f]{5}'), '#')
      .replaceAll(RegExp(r'Closure: [^;]*'), 'Closure');
}

String _types(Element root) {
  final out = StringBuffer();
  void walk(Element e, int depth) {
    final box = e.renderObject;
    final size = box is RenderBox && box.hasSize ? ' size=${box.size}' : '';
    out.writeln(
      '${'  ' * depth}${e.widget.runtimeType} {${_props(e.widget)}}$size',
    );
    e.visitChildren((c) => walk(c, depth + 1));
  }

  walk(root, 0);
  return out.toString();
}

String _texts(WidgetTester tester, Finder within) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(
    find.descendant(of: within, matching: find.byType(Text)),
  )) {
    out.add(w.data ?? w.textSpan?.toPlainText() ?? '');
  }
  return out.join('\n---\n');
}

String _semantics(WidgetTester tester) => tester
    .renderObject(find.byType(MaterialApp))
    .owner!
    .semanticsOwner!
    .rootSemanticsNode!
    .toStringDeep()
    .replaceAll(RegExp(r'#[0-9a-f]+'), '#');

String _dump(WidgetTester tester, Finder root) =>
    '== types ==\n${_types(tester.element(root))}'
    '== texts ==\n${_texts(tester, root)}\n'
    '== semantics ==\n${_semantics(tester)}';

void main() {
  testWidgets('Kanban Inspect dialog: a run with a process', (tester) async {
    final handle = tester.ensureSemantics();
    final dump = await _inspect(tester, {
      'alive': true,
      'pid': 4242,
      'cpu_percent': 12.5,
      'memory_rss_bytes': 104857600,
      'num_threads': 9,
      'status': 'sleeping',
      'reason': 'child of dispatcher',
    });
    _check('inspect-alive', dump);
    handle.dispose();
  });

  testWidgets('Kanban Inspect dialog: the process is gone', (tester) async {
    final handle = tester.ensureSemantics();
    final dump = await _inspect(tester, {
      'alive': false,
      'reason': 'process not found',
    });
    _check('inspect-gone', dump);
    handle.dispose();
  });

  testWidgets('Hub skill install confirmation lists the findings', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final server = FakeHermesServer()
      ..on('GET', '/api/skills', [])
      ..on('GET', '/api/skills/hub/official', {'skills': []})
      ..on('GET', '/api/skills/hub/sources', {
        'sources': [
          {'id': 'github', 'label': 'GitHub'},
        ],
        'featured': [],
        'installed': {},
      })
      ..on('GET', '/api/skills/hub/search', {
        'results': [
          hubSkillRow(name: 'web-scraper', description: 'Scrape pages'),
        ],
        'timed_out': [],
        'installed': {},
      })
      ..on('GET', '/api/skills/hub/preview', {
        'name': 'web-scraper',
        'skill_md': '# Web scraper',
        'files': ['SKILL.md'],
      })
      ..on(
        'GET',
        '/api/skills/hub/scan',
        hubScanBody(
          policy: 'ask',
          reason: 'Findings need a look.',
          findings: [
            hubFindingRow(),
            hubFindingRow(
              severity: 'low',
              description: 'Reads the environment',
              file: 'scripts/env.sh',
              line: 3,
            ),
          ],
        ),
      );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => AppThemeScopes(child: child!),
        theme: ThemeData(platform: TargetPlatform.android),
        home: SkillsScreen(
          repository: HermesSkillsRepository(server.client().raw),
          hubRepository: HermesSkillsHubRepository(server.client().raw),
          chatProfile: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'scrape');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('web-scraper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install anyway…'));
    await tester.pumpAndSettle();

    _check('install-confirm', _dump(tester, find.byType(AppAlertDialog)));
    handle.dispose();
  });

  for (final (name, exportJson) in [
    ('idle', ExportJsonOffer(onSelected: () {})),
    ('export running', ExportJsonOffer(onSelected: () {}, enabled: false)),
  ]) {
    testWidgets('Mac chat toolbar "…" menu, $name', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view
        ..physicalSize = const Size(680, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: MacChatToolbar(
                title: 'Plan the release',
                subtitle: 'default · example-model',
                onNewChat: () {},
                onShowConnection: () {},
                onCopyTranscript: () {},
                onShowFiles: () {},
                exportJson: exportJson,
                searchQuery: '',
                searchActive: false,
                onSearchBegin: () {},
                onSearchChanged: (_) {},
                onSearchEnd: () {},
              ),
            ),
          ),
        ),
      );
      final closed = _dump(tester, find.byKey(const Key('toolbar-more')));
      await tester.tap(find.byKey(const Key('toolbar-more')));
      await tester.pumpAndSettle();
      final open = _dump(
        tester,
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('_PopupMenu<'),
        ),
      );
      _check('menu-$name', '== closed ==\n$closed== open ==\n$open');
      handle.dispose();
    });
  }
}

Future<String> _inspect(
  WidgetTester tester,
  Map<String, Object?> inspection,
) async {
  final server = FakeHermesServer()
    ..on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [
        {
          'run_id': 7,
          'task_id': 't1',
          'task_title': 'Migrate webhooks',
          'profile': 'coder',
          'worker_pid': 4242,
          'started_at': 1780000000,
        },
      ],
    })
    ..on('GET', '/api/plugins/kanban/runs/7/inspect', inspection);
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: KanbanWorkersScreen(
        repository: KanbanRepository(server.client()),
        board: 'ops',
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(PopupMenuButton<RowAction>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Inspect process'));
  await tester.pumpAndSettle();
  return _dump(tester, find.byType(AppAlertDialog));
}

/// Compares [actual] with the tree recorded before the extraction. Setting
/// `RECORD_TREES` to a directory writes the dumps there instead.
void _check(String key, String actual) {
  final dir = Platform.environment['RECORD_TREES'];
  if (dir != null) {
    File('$dir/$key.txt').writeAsStringSync(actual);
    return;
  }
  expect(actual, expectedTrees[key]);
}
