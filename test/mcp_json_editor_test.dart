import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/mcp_json_editor_screen.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// The JSON editor: what it loads, what it checks on the device and what it
/// asks before it replaces the profile's servers.
void main() {
  late FakeHermesServer server;
  late McpServersController servers;
  bool? closedWith;

  const serversPath = '/api/mcp/servers';
  const configPath = '/api/config';

  Map<String, Object?> stored() => {
    'grafana': {
      'url': 'https://mcp.grafana.com/mcp',
      'auth': 'oauth',
      'timeout': 45,
      'headers': {'X-Team': 'infra'},
    },
    'fs': {
      'command': 'npx',
      'args': ['-y', 'pkg'],
      'env': {'FS_TOKEN': 'env-secret-value'},
      'enabled': false,
    },
  };

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', serversPath, mcpServerListBody([]))
      ..on('GET', configPath, {'model': 'x', 'mcp_servers': stored()})
      ..on('PUT', serversPath, {'ok': true});
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    closedWith = null;
    servers = McpServersController(
      repository: HermesMcpRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
    addTearDown(servers.dispose);
    unawaited(servers.load());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              closedWith = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => McpJsonEditorScreen(servers: servers),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) await tester.pumpAndSettle();
  }

  final editor = find.byKey(const ValueKey('mcp-json-text'));
  final saveButton = find.byKey(const ValueKey('mcp-json-save'));
  final confirm = find.byKey(const ValueKey('mcp-review-confirm'));
  final back = find.byKey(const ValueKey('mcp-review-back'));

  String text(WidgetTester tester) =>
      tester.widget<TextField>(editor).controller!.text;

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton).onPressed != null;

  Future<void> edit(WidgetTester tester, Object? value) async {
    await tester.enterText(
      editor,
      value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value),
    );
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  Object? sent() => jsonBody(server.requestsTo('PUT', serversPath).single);

  int puts() => server.requestsTo('PUT', serversPath).length;

  group('loading', () {
    testWidgets('shows a progress indicator while it loads', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('GET', configPath, (_) => answer.future);

      await open(tester, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      answer.complete((status: 200, body: {'mcp_servers': stored()}));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(editor, findsOneWidget);
    });

    testWidgets('shows the whole stored map, every field, as JSON', (
      tester,
    ) async {
      await open(tester);

      expect(jsonDecode(text(tester)), stored());
      expect(text(tester), contains('\n  "grafana": {'));
      expect(text(tester), contains('"timeout": 45'));
      expect(text(tester), contains('"X-Team": "infra"'));
    });

    testWidgets('reads the profile from /api/config, not the servers route', (
      tester,
    ) async {
      await open(tester);

      expect(
        server.requestsTo('GET', configPath).single.queryParameters['profile'],
        'work',
      );
    });

    testWidgets('names the profile and warns about secrets and replacing', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Edit as JSON'), findsOneWidget);
      expect(find.text('Profile: work · mcp_servers'), findsOneWidget);
      expect(find.textContaining('Replaces all servers'), findsOneWidget);
      expect(find.textContaining('secrets'), findsOneWidget);
    });

    testWidgets('shows {} when the config has no servers', (tester) async {
      server.on('GET', configPath, {'model': 'x'});

      await open(tester);

      expect(text(tester), '{}');
    });

    testWidgets('offers a retry when loading fails', (tester) async {
      server.on('GET', configPath, {'detail': 'boom'}, status: 500);
      await open(tester);

      expect(find.text('Could not load the configuration'), findsOneWidget);
      expect(editor, findsNothing);

      server.on('GET', configPath, {'mcp_servers': stored()});
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(editor, findsOneWidget);
      expect(find.text('Could not load the configuration'), findsNothing);
    });

    testWidgets('fails when the profile could not be learned', (tester) async {
      server.on('GET', '/api/profiles/active', {'detail': 'boom'}, status: 500);

      await open(tester);

      expect(find.text('Could not load the configuration'), findsOneWidget);
      expect(server.requestsTo('GET', configPath), isEmpty);
    });
  });

  group('checks', () {
    testWidgets('keeps Save off while the text is unchanged', (tester) async {
      await open(tester);
      expect(saveEnabled(tester), isFalse);

      await edit(tester, '${text(tester)} ');
      expect(saveEnabled(tester), isTrue);

      await edit(tester, text(tester).trimRight());
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('shows a syntax error with its line and blocks Save', (
      tester,
    ) async {
      await open(tester);

      await edit(tester, '{\n  "a": {\n    "url": "x"\n    "b": 1\n  }\n}');

      expect(find.textContaining('Line 4: '), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('says each server must be an object', (tester) async {
      await open(tester);

      await edit(tester, '[]');
      expect(find.textContaining('must be an object'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await edit(tester, '{"a": "text"}');
      expect(find.textContaining('"a" must be an object'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('never quotes the text in an error', (tester) async {
      await open(tester);

      await edit(tester, '{"a": {"env": {"K": "typed-secret" "x": 1}}}');

      expect(find.textContaining('Line 1: '), findsOneWidget);
      expect(find.textContaining('typed-secret'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mcp-json-error')),
          matching: find.textContaining('typed-secret'),
        ),
        findsNothing,
      );
    });
  });

  group('saving', () {
    testWidgets('sends the whole edited map, keeping fields nobody touched', (
      tester,
    ) async {
      await open(tester);
      final edited = stored();
      (edited['grafana']! as Map)['url'] = 'https://other.test/mcp';

      await edit(tester, edited);
      await tapSave(tester);

      expect(sent(), {'servers': edited, 'profile': 'work'});
      expect(
        server.requestsTo('PUT', serversPath).single.queryParameters['profile'],
        'work',
      );
      expect(closedWith, isTrue);
    });

    testWidgets('closes and lists the servers again', (tester) async {
      await open(tester);
      final before = server.requestsTo('GET', serversPath).length;
      final edited = stored();
      (edited['grafana']! as Map)['url'] = 'https://other.test/mcp';

      await edit(tester, edited);
      await tapSave(tester);

      expect(find.byType(McpJsonEditorScreen), findsNothing);
      expect(server.requestsTo('GET', serversPath).length, before + 1);
    });

    testWidgets('shows progress and takes no second tap', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('PUT', serversPath, (_) => answer.future);
      await open(tester);
      await edit(tester, '{}');

      // Deleting everything asks first; confirm it.
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete and save'));
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: saveButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse);
      answer.complete((status: 200, body: {'ok': true}));
      await tester.pumpAndSettle();

      expect(puts(), 1);
    });

    testWidgets('a 400 lists each problem and keeps the text', (tester) async {
      server.on('PUT', serversPath, {
        'detail': "Server 'fs': expected an object; Server 'x': needs a url",
      }, status: 400);
      await open(tester);
      final edited = stored()..['x'] = <String, Object?>{};
      await edit(tester, edited);
      final typed = text(tester);

      await tapSave(tester);

      expect(find.text("Server 'fs': expected an object"), findsOneWidget);
      expect(find.text("Server 'x': needs a url"), findsOneWidget);
      expect(text(tester), typed);
      expect(closedWith, isNull);
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);
    });

    testWidgets('any other failure says it could not save', (tester) async {
      server.on('PUT', serversPath, {'detail': 'boom'}, status: 500);
      await open(tester);
      final edited = stored();
      (edited['grafana']! as Map)['url'] = 'https://other.test/mcp';
      await edit(tester, edited);

      await tapSave(tester);

      expect(find.text('Could not save'), findsOneWidget);
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);
    });
  });

  group('removing servers', () {
    Future<void> removeGrafana(WidgetTester tester) async {
      final edited = stored()..remove('grafana');
      await edit(tester, edited);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, naming the server and saying it is deleted', (
      tester,
    ) async {
      await open(tester);

      await removeGrafana(tester);

      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.textContaining('"grafana"')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('deleted, not just switched off'),
        ),
        findsOneWidget,
      );
      expect(puts(), 0);
    });

    testWidgets('cancelling makes no request and keeps the text', (
      tester,
    ) async {
      await open(tester);
      await removeGrafana(tester);
      final typed = text(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(puts(), 0);
      expect(text(tester), typed);
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);
    });

    testWidgets('confirming saves', (tester) async {
      await open(tester);
      await removeGrafana(tester);

      await tester.tap(find.text('Delete and save'));
      await tester.pumpAndSettle();

      expect(puts(), 1);
      expect((sent()! as Map)['servers'], {'fs': stored()['fs']});
    });

    testWidgets('a rename counts as a removal', (tester) async {
      await open(tester);
      final edited = <String, Object?>{
        'grafana2': stored()['grafana'],
        'fs': stored()['fs'],
      };
      await edit(tester, edited);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(puts(), 0);
    });

    testWidgets('a second tap while the question is open asks nothing more', (
      tester,
    ) async {
      await open(tester);
      await edit(tester, stored()..remove('grafana'));

      await tester.tap(saveButton);
      await tester.pump();
      tester.widget<FilledButton>(saveButton).onPressed?.call();
      await tester.pumpAndSettle();

      expect(find.text('Delete and save'), findsOneWidget);
    });
  });

  group('the review', () {
    testWidgets('lists a new command server before any request', (
      tester,
    ) async {
      await open(tester);
      final edited = stored()
        ..['fresh'] = {
          'command': 'bash',
          'args': ['-c', 'echo hi'],
          'env': {'API_KEY': 'typed-env-secret'},
        };
      await edit(tester, edited);

      await tapSave(tester);

      Finder inReview(String text) => find.descendant(
        of: find.byType(McpCommandReview),
        matching: find.text(text),
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inReview('fresh'), findsOneWidget);
      expect(inReview('bash'), findsOneWidget);
      expect(inReview('echo hi'), findsOneWidget);
      expect(inReview('API_KEY'), findsOneWidget);
      expect(inReview('typed-env-secret'), findsNothing);
      expect(find.text('Save and run on server'), findsOneWidget);
      expect(puts(), 0);
    });

    testWidgets('confirming saves', (tester) async {
      await open(tester);
      await edit(tester, stored()..['fresh'] = {'command': 'true'});
      await tapSave(tester);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(puts(), 1);
      expect(closedWith, isTrue);
    });

    testWidgets('going back makes no request and keeps the text', (
      tester,
    ) async {
      await open(tester);
      await edit(tester, stored()..['fresh'] = {'command': 'true'});
      final typed = text(tester);
      await tapSave(tester);

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(puts(), 0);
      expect(text(tester), typed);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('is a dialog on a wide layout', (tester) async {
      await open(tester, size: const Size(1200, 900));
      await edit(tester, stored()..['fresh'] = {'command': 'true'});

      await tapSave(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(puts(), 0);
    });

    testWidgets('a changed environment value counts as a change', (
      tester,
    ) async {
      await open(tester);
      final edited = stored();
      ((edited['fs']! as Map)['env'] as Map)['FS_TOKEN'] = 'other';
      await edit(tester, edited);

      await tapSave(tester);

      expect(find.byType(McpCommandReview), findsOneWidget);
      expect(puts(), 0);
    });

    Future<void> loadStored(Map<String, Object?> config) async {
      server.on('GET', configPath, {'mcp_servers': config});
    }

    testWidgets('a changed working directory is reviewed and shown before '
        'any request', (tester) async {
      await loadStored({
        'py': {
          'command': 'python',
          'args': ['server.py'],
          'cwd': '/srv/mcp',
        },
      });
      await open(tester);
      await edit(tester, {
        'py': {
          'command': 'python',
          'args': ['server.py'],
          'cwd': '/tmp/elsewhere',
        },
      });

      await tapSave(tester);

      expect(find.byType(McpCommandReview), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(McpCommandReview),
          matching: find.text('/tmp/elsewhere'),
        ),
        findsOneWidget,
      );
      expect(puts(), 0);
    });

    testWidgets('removing the url of an entry that has a url and a command is '
        'reviewed, since Hermes then runs the command', (tester) async {
      await loadStored({
        'both': {'url': 'https://a.test/mcp', 'command': 'bash'},
      });
      await open(tester);
      await edit(tester, {
        'both': {'command': 'bash'},
      });

      await tapSave(tester);

      expect(find.byType(McpCommandReview), findsOneWidget);
      expect(puts(), 0);
    });

    testWidgets('flipping enabled alone is not reviewed', (tester) async {
      await loadStored({
        'py': {'command': 'python', 'cwd': '/srv/mcp', 'enabled': true},
      });
      await open(tester);
      await edit(tester, {
        'py': {'command': 'python', 'cwd': '/srv/mcp', 'enabled': false},
      });

      await tapSave(tester);

      expect(find.byType(McpCommandReview), findsNothing);
      expect(puts(), 1);
    });

    for (final (label, status) in [('400', 400), ('500', 500)]) {
      testWidgets('after a failed save ($label) the review is asked again on '
          'the retry, since nothing was saved', (tester) async {
        server.on('PUT', serversPath, {'detail': 'no'}, status: status);
        await open(tester);
        await edit(tester, stored()..['fresh'] = {'command': 'true'});
        await tapSave(tester);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(puts(), 1);
        expect(find.byType(McpCommandReview), findsNothing);

        await tapSave(tester);

        expect(find.byType(McpCommandReview), findsOneWidget);
        expect(puts(), 1);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(puts(), 2);
      });
    }

    testWidgets('an unchanged command server is not reviewed again', (
      tester,
    ) async {
      await open(tester);
      final edited = stored();
      (edited['grafana']! as Map)['url'] = 'https://other.test/mcp';
      (edited['fs']! as Map)['enabled'] = true;
      await edit(tester, edited);

      await tapSave(tester);

      expect(find.byType(McpCommandReview), findsNothing);
      expect(puts(), 1);
    });

    testWidgets('asks about the deletion first and then the review', (
      tester,
    ) async {
      await open(tester);
      final edited = stored()
        ..remove('grafana')
        ..['fresh'] = {'command': 'true'};
      await edit(tester, edited);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.byType(McpCommandReview), findsNothing);
      await tester.tap(find.text('Delete and save'));
      await tester.pumpAndSettle();

      expect(find.byType(McpCommandReview), findsOneWidget);
      expect(puts(), 0);
    });
  });

  group('leaving', () {
    testWidgets('asks before discarding unsaved changes', (tester) async {
      await open(tester);
      await edit(tester, '{}');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(McpJsonEditorScreen), findsOneWidget);
      expect(text(tester), '{}');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(McpJsonEditorScreen), findsNothing);
      expect(puts(), 0);
    });

    testWidgets('leaves without asking when nothing changed', (tester) async {
      await open(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(McpJsonEditorScreen), findsNothing);
    });

    testWidgets('drops the text: a new visit loads it again', (tester) async {
      await open(tester);
      await edit(tester, '{}');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(jsonDecode(text(tester)), stored());
      expect(server.requestsTo('GET', configPath), hasLength(2));
    });
  });
}
