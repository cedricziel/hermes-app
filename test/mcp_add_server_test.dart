import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_add_server_screen.dart';
import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// The "Add server" form and the review of a command server, against a fake
/// dashboard through the real generated client.
void main() {
  late FakeHermesServer server;
  late McpServersController servers;
  String? closedWith;
  var closed = false;

  const path = '/api/mcp/servers';

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', path, mcpServerListBody([]))
      ..on('POST', path, mcpServerRow(name: 'x'));
  });

  Future<void> openForm(
    WidgetTester tester, {
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    closedWith = null;
    closed = false;
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
              closedWith = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => McpAddServerScreen(servers: servers),
                ),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final addButton = find.byKey(const ValueKey('mcp-add-server-button'));
  final confirm = find.byKey(const ValueKey('mcp-review-confirm'));
  final back = find.byKey(const ValueKey('mcp-review-back'));

  bool addEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(addButton).onPressed != null;

  Finder field(String label) => find.widgetWithText(TextField, label);

  Finder authChoice(String label) => find.descendant(
    of: find.byType(SegmentedButton<McpRemoteAuth>),
    matching: find.text(label),
  );

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Future<void> fillRemote(
    WidgetTester tester, {
    String name = 'linear',
    String url = 'https://mcp.linear.app/mcp',
  }) async {
    await enter(tester, 'Name', name);
    await enter(tester, 'URL', url);
  }

  Future<void> useCommand(WidgetTester tester) async {
    await tester.tap(find.text('Command').first);
    await tester.pumpAndSettle();
  }

  Future<void> fillCommand(
    WidgetTester tester, {
    String name = 'notes-fs',
    String command = 'npx',
    String args = '-y\n@modelcontextprotocol/server-filesystem\n/srv/my notes',
  }) async {
    await enter(tester, 'Name', name);
    await enter(tester, 'Command', command);
    await enter(tester, 'Arguments (one per line)', args);
  }

  Future<void> addVariable(
    WidgetTester tester,
    String name,
    String value,
  ) async {
    await tester.ensureVisible(find.text('Add variable'));
    await tester.tap(find.text('Add variable'));
    await tester.pump();
    await tester.enterText(field('Variable name').last, name);
    await tester.enterText(field('Value').last, value);
    await tester.pump();
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(addButton);
    await tester.pumpAndSettle();
  }

  Object? sent() => jsonBody(server.requestsTo('POST', path).single);

  int posts() => server.requestsTo('POST', path).length;

  group('the header', () {
    testWidgets('names the profile', (tester) async {
      await openForm(tester);

      expect(find.text('Add server'), findsOneWidget);
      expect(find.text('Profile: work'), findsOneWidget);
    });
  });

  group('a remote server', () {
    testWidgets('cannot be added before it has a name and a URL', (
      tester,
    ) async {
      await openForm(tester);
      expect(addEnabled(tester), isFalse);

      await enter(tester, 'Name', '  ');
      await enter(tester, 'URL', 'https://a.test');
      expect(addEnabled(tester), isFalse);

      await enter(tester, 'Name', 'a');
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('sends the name, the URL and no sign-in', (tester) async {
      await openForm(tester);
      await fillRemote(tester, name: ' linear ');

      await tapAdd(tester);

      expect(sent(), {
        'name': 'linear',
        'url': 'https://mcp.linear.app/mcp',
        'auth': 'none',
      });
      expect(
        server.requestsTo('POST', path).single.queryParameters['profile'],
        'work',
      );
    });

    testWidgets('closes with the name of the new server', (tester) async {
      await openForm(tester);
      await fillRemote(tester);

      await tapAdd(tester);

      expect(closed, isTrue);
      expect(closedWith, 'linear');
    });

    testWidgets('needs no review', (tester) async {
      await openForm(tester);
      await fillRemote(tester);

      await tapAdd(tester);

      expect(find.text('Run this on your server?'), findsNothing);
      expect(posts(), 1);
    });

    testWidgets('rejects an address that is not http or https', (tester) async {
      await openForm(tester);
      await enter(tester, 'Name', 'a');

      for (final bad in ['mcp.example.com', 'ftp://a.test', 'https://', 'x']) {
        await enter(tester, 'URL', bad);
        expect(find.text('Enter an http or https address'), findsOneWidget);
        expect(addEnabled(tester), isFalse, reason: bad);
      }
      await enter(tester, 'URL', 'http://localhost:8080/mcp');
      expect(find.text('Enter an http or https address'), findsNothing);
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('a bearer token is asked for only with that sign-in', (
      tester,
    ) async {
      await openForm(tester);
      await fillRemote(tester);
      expect(field('Bearer token'), findsNothing);

      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();

      expect(field('Bearer token'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Bearer token')).obscureText,
        isTrue,
      );
      expect(find.textContaining('never shown again'), findsOneWidget);
      expect(addEnabled(tester), isFalse);
    });

    testWidgets('sends the token as a header sign-in', (tester) async {
      await openForm(tester);
      await fillRemote(tester);
      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();
      await enter(tester, 'Bearer token', 'lin_secret');
      expect(addEnabled(tester), isTrue);

      await tapAdd(tester);

      expect(sent(), {
        'name': 'linear',
        'url': 'https://mcp.linear.app/mcp',
        'auth': 'header',
        'bearer_token': 'lin_secret',
      });
    });

    testWidgets('sends OAuth with no token', (tester) async {
      await openForm(tester);
      await fillRemote(tester);
      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();
      await enter(tester, 'Bearer token', 'left-behind');
      await tester.tap(authChoice('OAuth'));
      await tester.pumpAndSettle();

      expect(field('Bearer token'), findsNothing);
      expect(find.textContaining('sign in from the server'), findsOneWidget);
      await tapAdd(tester);

      expect(sent(), {
        'name': 'linear',
        'url': 'https://mcp.linear.app/mcp',
        'auth': 'oauth',
      });
    });

    testWidgets('leaves out what was typed for a command server', (
      tester,
    ) async {
      await openForm(tester);
      await useCommand(tester);
      await fillCommand(tester);
      await addVariable(tester, 'K', 'v');
      await tester.tap(find.text('Remote (URL)'));
      await tester.pumpAndSettle();
      await fillRemote(tester);

      await tapAdd(tester);

      expect(sent(), {
        'name': 'linear',
        'url': 'https://mcp.linear.app/mcp',
        'auth': 'none',
      });
    });
  });

  group('a command server', () {
    testWidgets('cannot be added before it has a name and a command', (
      tester,
    ) async {
      await openForm(tester);
      await useCommand(tester);
      expect(addEnabled(tester), isFalse);

      await enter(tester, 'Name', 'a');
      expect(addEnabled(tester), isFalse);
      await enter(tester, 'Command', ' ');
      expect(addEnabled(tester), isFalse);
      await enter(tester, 'Command', 'true');
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('sends one argument per line, spaces kept', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await fillCommand(tester, args: '-y\n\n@scope/pkg\n/srv/my notes\n');
      await addVariable(tester, 'NOTES_TOKEN', 'abc');

      await tapAdd(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(sent(), {
        'name': 'notes-fs',
        'command': 'npx',
        'args': ['-y', '@scope/pkg', '/srv/my notes'],
        'env': {'NOTES_TOKEN': 'abc'},
      });
    });

    testWidgets('sends no arguments or environment when there are none', (
      tester,
    ) async {
      await openForm(tester);
      await useCommand(tester);
      await enter(tester, 'Name', 'harmless');
      await enter(tester, 'Command', 'true');

      await tapAdd(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(sent(), {'name': 'harmless', 'command': 'true'});
    });

    testWidgets('leaves out what was typed for a remote server', (
      tester,
    ) async {
      await openForm(tester);
      await fillRemote(tester);
      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();
      await enter(tester, 'Bearer token', 'lin_secret');
      await useCommand(tester);
      await fillCommand(tester);

      await tapAdd(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(sent(), {
        'name': 'notes-fs',
        'command': 'npx',
        'args': [
          '-y',
          '@modelcontextprotocol/server-filesystem',
          '/srv/my notes',
        ],
      });
    });

    testWidgets('an environment row needs a valid name', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await enter(tester, 'Name', 'a');
      await enter(tester, 'Command', 'true');

      await addVariable(tester, '1BAD', 'v');
      expect(find.textContaining('not starting with a digit'), findsOneWidget);
      expect(addEnabled(tester), isFalse);

      await tester.enterText(field('Variable name'), 'GOOD_1');
      await tester.pump();
      expect(find.textContaining('not starting with a digit'), findsNothing);
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('an empty row name is invalid', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await enter(tester, 'Name', 'a');
      await enter(tester, 'Command', 'true');

      await tester.ensureVisible(find.text('Add variable'));
      await tester.tap(find.text('Add variable'));
      await tester.pump();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(addEnabled(tester), isFalse);
    });

    testWidgets('a repeated row name is invalid', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await enter(tester, 'Name', 'a');
      await enter(tester, 'Command', 'true');
      await addVariable(tester, 'K', '1');
      await addVariable(tester, 'K', '2');

      expect(find.text('Already used above'), findsOneWidget);
      expect(addEnabled(tester), isFalse);
    });

    testWidgets('a row can be removed', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await enter(tester, 'Name', 'a');
      await enter(tester, 'Command', 'true');
      await addVariable(tester, '1BAD', '1');
      expect(addEnabled(tester), isFalse);

      await tester.tap(find.byTooltip('Remove variable'));
      await tester.pump();

      expect(field('Variable name'), findsNothing);
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('environment values are obscured', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await addVariable(tester, 'K', 'v');

      expect(tester.widget<TextField>(field('Value')).obscureText, isTrue);
    });
  });

  group('the review', () {
    Future<void> readyCommand(WidgetTester tester, {Size? size}) async {
      await openForm(tester, size: size ?? const Size(420, 900));
      await useCommand(tester);
      await fillCommand(tester);
      await addVariable(tester, 'NOTES_TOKEN', 'env-secret-value');
    }

    testWidgets('comes before any request and shows what runs', (tester) async {
      await readyCommand(tester);

      await tapAdd(tester);

      expect(posts(), 0);
      expect(find.byType(BottomSheet), findsOneWidget);
      Finder inReview(String text) => find.descendant(
        of: find.byType(McpCommandReview),
        matching: find.text(text),
      );
      expect(inReview('Run this on your server?'), findsOneWidget);
      expect(inReview('npx'), findsOneWidget);
      expect(inReview('/srv/my notes'), findsOneWidget);
      expect(inReview('NOTES_TOKEN'), findsOneWidget);
      expect(inReview('env-secret-value'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(McpCommandReview),
          matching: find.textContaining('env-secret-value'),
        ),
        findsNothing,
      );
    });

    testWidgets('is a dialog on a wide layout', (tester) async {
      await readyCommand(tester, size: const Size(1200, 900));

      await tapAdd(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('confirming makes the request', (tester) async {
      await readyCommand(tester);
      await tapAdd(tester);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(posts(), 1);
      expect(closedWith, 'notes-fs');
    });

    testWidgets('going back makes no request and keeps the form', (
      tester,
    ) async {
      await readyCommand(tester);
      await tapAdd(tester);

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(posts(), 0);
      expect(closed, isFalse);
      expect(
        tester.widget<TextField>(field('Name')).controller!.text,
        'notes-fs',
      );
      expect(
        tester.widget<TextField>(field('Command')).controller!.text,
        'npx',
      );
      expect(
        tester.widget<TextField>(field('Value')).controller!.text,
        'env-secret-value',
      );
      expect(addEnabled(tester), isTrue);
    });

    testWidgets('a second tap on Add while it is shown opens nothing', (
      tester,
    ) async {
      await readyCommand(tester);

      await tester.tap(addButton);
      await tester.pump();
      final onPressed = tester.widget<FilledButton>(addButton).onPressed;
      onPressed?.call();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('the keyboard action on a command form asks for the review', (
      tester,
    ) async {
      await readyCommand(tester);

      await tester.tap(field('Command'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Run this on your server?'), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('the keyboard action on the name asks for the review', (
      tester,
    ) async {
      await readyCommand(tester);

      await tester.tap(field('Name'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Run this on your server?'), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('the keyboard action on an environment value asks too', (
      tester,
    ) async {
      await readyCommand(tester);

      await tester.tap(field('Value'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Run this on your server?'), findsOneWidget);
      expect(posts(), 0);
    });

    testWidgets('rebuilding the form in between does not skip it', (
      tester,
    ) async {
      await readyCommand(tester);

      await tapAdd(tester);
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();

      expect(posts(), 0);
    });
  });

  group('sending', () {
    testWidgets('shows progress and takes no second tap', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', path, (_) => answer.future);
      await openForm(tester);
      await fillRemote(tester);

      await tester.tap(addButton);
      await tester.pump();

      expect(
        find.descendant(
          of: addButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(addEnabled(tester), isFalse);
      final onPressed = tester.widget<FilledButton>(addButton).onPressed;
      onPressed?.call();
      answer.complete((status: 200, body: mcpServerRow(name: 'linear')));
      await tester.pumpAndSettle();

      expect(posts(), 1);
    });

    testWidgets('the keyboard action while sending sends nothing more', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', path, (_) => answer.future);
      await openForm(tester);
      await fillRemote(tester);

      await tester.tap(addButton);
      await tester.pump();
      await tester.tap(field('URL'), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      answer.complete((status: 200, body: mcpServerRow(name: 'linear')));
      await tester.pumpAndSettle();

      expect(posts(), 1);
    });

    testWidgets('the keyboard action sends a remote server', (tester) async {
      await openForm(tester);
      await fillRemote(tester);

      await tester.tap(field('URL'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(posts(), 1);
    });
  });

  group('when Hermes refuses', () {
    testWidgets('a duplicate name is shown on the name field', (tester) async {
      server.on('POST', path, {
        'detail': "Server 'linear' already exists",
      }, status: 409);
      await openForm(tester);
      await fillRemote(tester);

      await tapAdd(tester);

      expect(
        find.text('A server with this name already exists'),
        findsOneWidget,
      );
      expect(closed, isFalse);
      await enter(tester, 'Name', 'linear2');
      expect(find.text('A server with this name already exists'), findsNothing);
    });

    testWidgets('a 400 shows its reason and keeps the form', (tester) async {
      server.on('POST', path, {
        'detail': "Server 'x' rejected: suspicious command/args configuration",
      }, status: 400);
      await openForm(tester);
      await useCommand(tester);
      await fillCommand(tester, command: 'bash');

      await tapAdd(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.textContaining('suspicious command/args'), findsOneWidget);
      expect(closed, isFalse);
      expect(
        tester.widget<TextField>(field('Command')).controller!.text,
        'bash',
      );
    });

    testWidgets('any other failure says which server could not be added', (
      tester,
    ) async {
      server.on('POST', path, {'detail': 'boom'}, status: 500);
      await openForm(tester);
      await fillRemote(tester);

      await tapAdd(tester);

      expect(find.text('Could not add linear'), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('clears the token and the values, and keeps the rest', (
      tester,
    ) async {
      server.on('POST', path, {'detail': 'boom'}, status: 500);
      await openForm(tester);
      await fillRemote(tester);
      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();
      await enter(tester, 'Bearer token', 'lin_secret');

      await tapAdd(tester);

      expect(
        tester.widget<TextField>(field('Bearer token')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Name')).controller!.text,
        'linear',
      );
      expect(addEnabled(tester), isFalse);
    });

    testWidgets('clears the environment values after a refusal', (
      tester,
    ) async {
      server.on('POST', path, {'detail': 'no'}, status: 400);
      await openForm(tester);
      await useCommand(tester);
      await fillCommand(tester);
      await addVariable(tester, 'K', 'env-secret-value');

      await tapAdd(tester);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field('Value')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Variable name')).controller!.text,
        'K',
      );
    });
  });

  group('leaving the form', () {
    testWidgets('empties the token and the environment values it held', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(authChoice('Bearer token'));
      await tester.pumpAndSettle();
      await enter(tester, 'Bearer token', 'left-behind-token');
      final token = tester.widget<TextField>(field('Bearer token')).controller!;
      await useCommand(tester);
      await addVariable(tester, 'K', 'left-behind-value');
      final value = tester.widget<TextField>(field('Value')).controller!;
      expect(token.text, 'left-behind-token');
      expect(value.text, 'left-behind-value');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(McpAddServerScreen), findsNothing);
      expect(token.text, isEmpty);
      expect(value.text, isEmpty);
      expect(posts(), 0);
    });

    testWidgets('empties a value whose row was removed', (tester) async {
      await openForm(tester);
      await useCommand(tester);
      await addVariable(tester, 'K', 'removed-value');
      final value = tester.widget<TextField>(field('Value')).controller!;

      await tester.tap(find.byTooltip('Remove variable'));
      await tester.pumpAndSettle();

      expect(value.text, isEmpty);
    });
  });
}
