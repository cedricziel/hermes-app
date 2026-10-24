import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

class _RetainedApiAuth extends AuthController {
  _RetainedApiAuth(this.client);
  HermesApiClient client;
  void replaceApi(HermesApiClient next) {
    client = next;
    notifyListeners();
  }

  bool authorized = true;
  int epoch = 1;
  VerifiedSessionOwner owner = const VerifiedSessionOwner(
    server: 'server',
    user: 'first',
    organization: 'organization',
    provider: 'provider',
  );
  @override
  int get ownerGeneration => epoch;
  @override
  VerifiedSessionOwner get verifiedOwner => owner;
  void replaceOwner() {
    epoch++;
    owner = const VerifiedSessionOwner(
      server: 'server',
      user: 'other',
      organization: 'organization',
      provider: 'provider',
    );
    notifyListeners();
  }

  @override
  HermesApiClient get api => client;
  @override
  bool get protectedRequestsAllowed => authorized;
  @override
  HermesConnectionState get state => authorized
      ? HermesConnectionState.ready
      : HermesConnectionState.needsLogin;
  void suspend() {
    authorized = false;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test(
    'a scope retired during detail loading notification never issues its read',
    () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/learning/graph', memoryGraph)
        ..on('GET', '/api/learning/node', memoryDetail);
      final controller = MemoryController();
      addTearDown(controller.dispose);
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      final entry = controller.entries.first;
      controller.addListener(() {
        if (controller.loading && controller.selected != null) {
          controller.bind(null, null);
        }
      });
      await controller.open(entry);
      expect(server.requestsTo('GET', '/api/learning/node'), isEmpty);
      expect(controller.detail, isNull);
    },
  );

  testWidgets(
    'protected access suspension hides memories even when the API client is retained',
    (tester) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/profiles', {
          'profiles': [profileRow(name: 'work')],
        })
        ..on('GET', '/api/profiles/active', {
          'active': 'work',
          'current': 'work',
        })
        ..on('GET', '/api/learning/graph', memoryGraph)
        ..on('GET', '/api/learning/node', memoryDetail);
      final client = server.client(), auth = _RetainedApiAuth(server.client());
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<HermesRepositories?>.value(
              value: HermesRepositories(client),
            ),
          ],
          child: const MaterialApp(home: MemoryDestination()),
        ),
      );
      await tester.runAsync(() async => pumpEventQueue());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long memory'));
      await tester.runAsync(() async => pumpEventQueue());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, fullMemory), findsOneWidget);
      auth.suspend();
      await tester.pumpAndSettle();
      expect(find.text('Sign in to read memories.'), findsOneWidget);
      expect(find.widgetWithText(SelectableText, fullMemory), findsNothing);
    },
  );
  testWidgets('a retained-API owner replacement retires the Memory route', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail);
    final client = server.client(), auth = _RetainedApiAuth(server.client());
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(client),
          ),
        ],
        child: const MaterialApp(home: MemoryDestination()),
      ),
    );
    await tester.runAsync(() async => pumpEventQueue());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agent notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long memory'));
    await tester.runAsync(() async => pumpEventQueue());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SelectableText, fullMemory), findsOneWidget);
    auth.replaceOwner();
    await tester.pumpAndSettle();
    expect(find.text('Reopen Memory for this account.'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, fullMemory), findsNothing);
    expect(server.requestsTo('GET', '/api/learning/graph'), hasLength(1));
  });

  testWidgets(
    'a same-owner API replacement retires the awaited old detail before a rebuild',
    (tester) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/profiles', {
          'profiles': [profileRow(name: 'work')],
        })
        ..on('GET', '/api/profiles/active', {
          'active': 'work',
          'current': 'work',
        })
        ..on('GET', '/api/learning/graph', memoryGraph);
      late Completer<FakeResponse> held;
      server.onRequest('GET', '/api/learning/node', (_) => held.future);
      final client = server.client(), auth = _RetainedApiAuth(server.client());
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<HermesRepositories?>.value(
              value: HermesRepositories(client),
            ),
          ],
          child: const MaterialApp(home: MemoryDestination()),
        ),
      );
      await tester.runAsync(() async => pumpEventQueue());
      await tester.pumpAndSettle();
      final controller = tester
          .widget<MemoryScreen>(find.byType(MemoryScreen))
          .controller;
      await tester.runAsync(() async {
        held = Completer<FakeResponse>();
        final opening = controller.open(controller.entries.first);
        await pumpEventQueue();
        auth.replaceApi(FakeHermesServer().client());
        held.complete((status: 200, body: memoryDetail));
        await opening;
        expect(controller.detail, isNull);
        expect(controller.entries, isEmpty);
      });
    },
  );
  test('a scope retired during mutation notification never issues preflight or write', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    controller.bind(MemoryRepository(server.client().raw), 'work');
    await pumpEventQueue();
    await controller.open(controller.entries.first);
    controller.beginEdit();
    controller.setDraft('Updated content');
    final readsBefore = server.requestsTo('GET', '/api/learning/node').length;
    controller.addListener(() {
      if (controller.mutation == MemoryMutation.pending) {
        controller.bind(null, null);
      }
    });
    await controller.mutate(delete: false);
    expect(
      server.requestsTo('GET', '/api/learning/node'),
      hasLength(readsBefore),
    );
    expect(server.requestsTo('PUT', '/api/learning/node'), isEmpty);
    expect(controller.draft, isNull);
  });
}
