import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

import 'support/fake_hermes_server.dart';

/// Signing in to an OAuth server from its detail, against a fake dashboard
/// through the real generated client. Hermes runs the flow; the app opens the
/// browser and watches.
void main() {
  late FakeHermesServer server;
  late List<Uri> launched;
  late bool browserWorks;

  const authPath = '/api/mcp/servers/asana/auth';
  const flowPath = '/api/mcp/oauth/flows/flow-1';
  const testPath = '/api/mcp/servers/asana/test';
  const approvalUrl = 'https://auth.example/authorize?state=s1';

  setUp(() {
    launched = [];
    browserWorks = true;
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(
            name: 'asana',
            url: 'https://mcp.asana.com/sse',
            auth: 'oauth',
          ),
          mcpServerRow(name: 'filesystem', command: 'npx'),
        ]),
      )
      ..on('POST', authPath, mcpFlowBody(authorizationUrl: approvalUrl))
      ..on('GET', flowPath, mcpFlowBody(authorizationUrl: approvalUrl))
      ..on('DELETE', flowPath, {'ok': true, 'status': 'error'})
      ..on(
        'POST',
        testPath,
        mcpTestBody(tools: [mcpToolRow(name: 'list_tasks')]),
      );
  });

  Future<void> pumpServers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: McpServersScreen(
          repository: HermesMcpRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
          launchLink: (uri) async {
            launched.add(uri);
            if (!browserWorks) throw StateError('no browser');
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('mcp-row-$name')));
    await tester.pumpAndSettle();
  }

  /// Lets requests and page transitions get going without waiting for the
  /// spinner, which never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Sign in'));
    await settle(tester);
  }

  Future<void> startSignIn(WidgetTester tester) async {
    await pumpServers(tester);
    await openDetail(tester, 'asana');
    await tapSignIn(tester);
  }

  Future<void> poll(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
    }
  }

  Iterable<Object?> deletes() =>
      server.requests.where((r) => r.method == 'DELETE' && r.path == flowPath);

  group('the button', () {
    testWidgets('is on the detail of an OAuth server, tested or not', (
      tester,
    ) async {
      await pumpServers(tester);
      await openDetail(tester, 'asana');

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('is not on the detail of another server', (tester) async {
      await pumpServers(tester);
      await openDetail(tester, 'filesystem');

      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('is on the Sign in needed banner, once', (tester) async {
      server.on(
        'POST',
        testPath,
        mcpTestFailureBody('OAuth authentication required — no token found.'),
      );
      await pumpServers(tester);
      await openDetail(tester, 'asana');
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in needed'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('signing in', () {
    testWidgets('starts the flow for the profile and opens the browser', (
      tester,
    ) async {
      await startSignIn(tester);

      expect(
        server.requestsTo('POST', authPath).single.queryParameters['profile'],
        'work',
      );
      expect(launched, [Uri.parse(approvalUrl)]);
      expect(find.text('Waiting for you to approve'), findsOneWidget);
      expect(find.text('Open the browser again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows progress on the button while Hermes starts the flow', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', authPath, (_) => answer.future);
      await pumpServers(tester);
      await openDetail(tester, 'asana');

      await tester.tap(find.text('Sign in'));
      await settle(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Sign in'), warnIfMissed: false);
      await settle(tester);
      expect(server.requestsTo('POST', authPath), hasLength(1));

      answer.complete((status: 200, body: mcpFlowBody()));
      await settle(tester);
      expect(find.text('Waiting for you to approve'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('polls about every two seconds', (tester) async {
      await startSignIn(tester);
      expect(server.requestsTo('GET', flowPath), isEmpty);

      await poll(tester, 3);

      expect(server.requestsTo('GET', flowPath), hasLength(3));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('closes, tests the server and shows its tools once approved', (
      tester,
    ) async {
      await startSignIn(tester);
      server.on('GET', flowPath, mcpFlowBody(status: 'approved'));

      await poll(tester);
      await tester.pumpAndSettle();

      expect(find.text('Waiting for you to approve'), findsNothing);
      expect(server.requestsTo('POST', testPath), hasLength(1));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('list_tasks'), findsOneWidget);
      expect(deletes(), isEmpty);
      final polls = server.requestsTo('GET', flowPath).length;
      await tester.pump(const Duration(seconds: 10));
      expect(server.requestsTo('GET', flowPath), hasLength(polls));
    });

    testWidgets('keeps waiting through a status it does not know', (
      tester,
    ) async {
      await startSignIn(tester);
      server.on('GET', flowPath, mcpFlowBody(status: 'surprise'));

      await poll(tester, 2);
      expect(find.text('Waiting for you to approve'), findsOneWidget);

      server.on('GET', flowPath, mcpFlowBody(status: 'approved'));
      await poll(tester);
      await tester.pumpAndSettle();
      expect(find.text('Waiting for you to approve'), findsNothing);
    });

    testWidgets('polls at once when the app comes back from the browser', (
      tester,
    ) async {
      await startSignIn(tester);
      server.on('GET', flowPath, mcpFlowBody(status: 'approved'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(server.requestsTo('POST', testPath), hasLength(1));
    });

    testWidgets('shows Hermes\' error and offers to try again', (tester) async {
      await startSignIn(tester);
      server.on(
        'GET',
        flowPath,
        mcpFlowBody(
          status: 'error',
          authorizationUrl: approvalUrl,
          error: 'Authorization failed',
        ),
      );

      await poll(tester);

      expect(find.text('Authorization failed'), findsOneWidget);
      expect(find.text('Waiting for you to approve'), findsNothing);
      expect(server.requestsTo('GET', flowPath), hasLength(1));

      server.on(
        'POST',
        authPath,
        mcpFlowBody(
          flowId: 'flow-1',
          authorizationUrl: 'https://auth.example/second',
        ),
      );
      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(server.requestsTo('POST', authPath), hasLength(2));
      expect(launched.last, Uri.parse('https://auth.example/second'));
      expect(find.text('Waiting for you to approve'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('says the sign-in expired when Hermes has dropped the flow', (
      tester,
    ) async {
      await startSignIn(tester);
      server.on('GET', flowPath, {
        'detail': 'OAuth flow not found or expired',
      }, status: 404);

      await poll(tester);

      expect(find.text('The sign-in expired'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(deletes(), isEmpty);
    });

    testWidgets('a flow that comes back already failed shows its error', (
      tester,
    ) async {
      server.on(
        'POST',
        authPath,
        mcpFlowBody(
          status: 'error',
          authorizationUrl: null,
          error: 'Discovery failed',
        ),
      );
      await startSignIn(tester);

      expect(find.text('Discovery failed'), findsOneWidget);
      expect(launched, isEmpty);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('Cancel deletes the flow and closes the screen', (
      tester,
    ) async {
      await startSignIn(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deletes(), hasLength(1));
      expect(find.text('Waiting for you to approve'), findsNothing);
      expect(find.text('Test connection'), findsOneWidget);
      expect(server.requestsTo('POST', testPath), isEmpty);
    });

    testWidgets('going back deletes the flow the same way', (tester) async {
      await startSignIn(tester);

      await tester.tap(find.byTooltip('Back').last);
      await tester.pumpAndSettle();

      expect(deletes(), hasLength(1));
    });

    testWidgets('a flow that already failed is not cancelled again', (
      tester,
    ) async {
      await startSignIn(tester);
      server.on('GET', flowPath, mcpFlowBody(status: 'error', error: 'no'));
      await poll(tester);

      await tester.tap(find.byTooltip('Back').last);
      await tester.pumpAndSettle();

      expect(deletes(), isEmpty);
    });
  });

  group('leaving while a sign-in starts', () {
    const secondFlow = '/api/mcp/oauth/flows/flow-2';

    Future<Completer<FakeResponse>> tryAgainHeld(WidgetTester tester) async {
      await startSignIn(tester);
      server.on('GET', flowPath, mcpFlowBody(status: 'error', error: 'no'));
      await poll(tester);
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', authPath, (_) => answer.future);
      server.on('DELETE', secondFlow, {'ok': true});
      await tester.tap(find.text('Try again'));
      await settle(tester);
      return answer;
    }

    testWidgets('cancels the flow that starts after the screen is gone', (
      tester,
    ) async {
      final answer = await tryAgainHeld(tester);

      await tester.pumpWidget(const SizedBox());
      answer.complete((
        status: 200,
        body: mcpFlowBody(flowId: 'flow-2', authorizationUrl: approvalUrl),
      ));
      await settle(tester);

      expect(
        server.requests.where(
          (r) => r.method == 'DELETE' && r.path == secondFlow,
        ),
        hasLength(1),
      );
      expect(launched, hasLength(1));
    });

    testWidgets('offers no way out while the new flow starts', (tester) async {
      final answer = await tryAgainHeld(tester);

      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Back').last);
      await settle(tester);
      expect(find.text('Could not sign in'), findsOneWidget);

      answer.complete((
        status: 200,
        body: mcpFlowBody(flowId: 'flow-2', authorizationUrl: approvalUrl),
      ));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the detail cancels a flow it can no longer show', (
      tester,
    ) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', authPath, (_) => answer.future);
      await pumpServers(tester);
      await openDetail(tester, 'asana');
      await tester.tap(find.text('Sign in'));
      await settle(tester);

      await tester.pumpWidget(const SizedBox());
      answer.complete((
        status: 200,
        body: mcpFlowBody(authorizationUrl: approvalUrl),
      ));
      await settle(tester);

      expect(deletes(), hasLength(1));
    });
  });

  group('when the browser cannot be opened', () {
    testWidgets('still waits, and shows the address to copy', (tester) async {
      browserWorks = false;

      await startSignIn(tester);

      expect(find.text('Waiting for you to approve'), findsOneWidget);
      expect(find.text(approvalUrl), findsOneWidget);
      expect(find.textContaining('Could not open the browser'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('tries again on request', (tester) async {
      browserWorks = false;
      await startSignIn(tester);
      browserWorks = true;

      await tester.tap(find.text('Open the browser again'));
      await settle(tester);

      expect(launched, hasLength(2));
      expect(find.text(approvalUrl), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('does not show the address when the browser opened', (
      tester,
    ) async {
      await startSignIn(tester);

      expect(find.text(approvalUrl), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('refusals', () {
    Future<void> refusedWith(
      WidgetTester tester,
      int status,
      Object? body,
    ) async {
      server.on('POST', authPath, body, status: status);
      await startSignIn(tester);
      await tester.pumpAndSettle();
      expect(find.text('Waiting for you to approve'), findsNothing);
      expect(launched, isEmpty);
    }

    testWidgets('409 says a sign-in is already in progress', (tester) async {
      await refusedWith(tester, 409, {
        'detail': 'MCP OAuth for \'asana\' is already in progress',
      });

      expect(
        find.text(
          'A sign-in for asana is already in progress on your server. Try again in a few minutes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('429 says too many are in progress', (tester) async {
      await refusedWith(tester, 429, {
        'detail': 'Too many MCP OAuth flows are already in progress',
      });

      expect(
        find.text(
          'Too many sign-ins are in progress on your server. Try again in a few minutes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('400 shows Hermes\' reason', (tester) async {
      await refusedWith(tester, 400, {
        'detail': 'stdio servers authenticate via env keys, not OAuth',
      });

      expect(
        find.text('stdio servers authenticate via env keys, not OAuth'),
        findsOneWidget,
      );
    });

    testWidgets('404 reloads the server list', (tester) async {
      await refusedWith(tester, 404, {'detail': 'Server not found'});

      expect(server.requestsTo('GET', '/api/mcp/servers'), hasLength(2));
    });

    testWidgets('any other failure says it could not start', (tester) async {
      await refusedWith(tester, 500, {'detail': 'boom'});

      expect(find.text('Could not start signing in to asana'), findsOneWidget);
    });

    testWidgets('the message goes when the user tries again', (tester) async {
      await refusedWith(tester, 409, {'detail': 'x'});
      server.on('POST', authPath, mcpFlowBody(authorizationUrl: approvalUrl));

      await tapSignIn(tester);

      expect(find.textContaining('already in progress'), findsNothing);
      expect(find.text('Waiting for you to approve'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
