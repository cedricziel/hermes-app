import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/memory_token_store.dart';
import 'support/screenshot_recorder.dart';
import 'support/workflow_app.dart';

/// A token store whose clear waits, which holds an ungated sign-out between
/// the owner moving and the new API client existing.
class _HeldStore extends MemoryTokenStore {
  Completer<void>? hold;

  @override
  Future<void> clear() async {
    await hold?.future;
    return super.clear();
  }
}

/// An ungated dashboard on a loopback socket that records its requests.
Future<(HttpServer, List<String>)> _ungatedDashboard() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = <String>[];
  server.listen((request) async {
    final path = request.uri.path;
    requests.add(path);
    final Object body = switch (path) {
      '/api/status' => {'auth_required': false, 'version': '0.22.2'},
      '/api/profiles' => profileListBody([profileRow(name: 'work')]),
      '/api/profiles/active' => activeProfileBody(active: 'work'),
      '/api/sessions' => sessionListBody([]),
      _ => {'detail': 'Not Found'},
    };
    request.response
      ..statusCode = body is Map && body['detail'] != null ? 404 : 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  });
  return (server, requests);
}

void main() {
  testWidgets(
    'an owner change while the connection stays ready gives a shell that '
    'works for the new owner',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final (server, requests) = (await tester.runAsync(_ungatedDashboard))!;
      addTearDown(() => server.close(force: true));
      final auth = AuthController(
        devServerUrl: 'http://127.0.0.1:${server.port}',
      );
      addTearDown(auth.dispose);
      await pumpWorkflowApp(tester, ScreenshotRecorder('owner'), auth: auth);
      await tester.runAsync(auth.bootstrap);
      await pumpUntilFound(tester, find.byType(AppShell));
      final first = tester.state(find.byType(AppShell));
      final generation = auth.ownerGeneration;
      requests.clear();

      // An ungated server's sign-out keeps the state `ready`.
      await tester.runAsync(auth.signOut);
      await pumpUntil(tester, () => auth.protectedRequestsAllowed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.state, HermesConnectionState.ready);
      expect(auth.ownerGeneration, isNot(generation));
      expect(find.byType(AppShell), findsOneWidget);
      // The shell that the connection now belongs to is not the one bound to
      // the old owner, and it reads the server like an authorized shell.
      expect(tester.state(find.byType(AppShell)), isNot(same(first)));
      await pumpUntil(tester, () => requests.contains('/api/profiles'));
      await letSocketsIdle(tester);
    },
  );

  testWidgets('the shell is not replaced before the new client exists', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final (server, requests) = (await tester.runAsync(_ungatedDashboard))!;
    addTearDown(() => server.close(force: true));
    final store = _HeldStore();
    final auth = AuthController(
      devServerUrl: 'http://127.0.0.1:${server.port}',
      tokenStore: store,
    );
    addTearDown(auth.dispose);
    await pumpWorkflowApp(tester, ScreenshotRecorder('owner'), auth: auth);
    await tester.runAsync(auth.bootstrap);
    await pumpUntilFound(tester, find.byType(AppShell));
    final first = tester.state(find.byType(AppShell));
    final generation = auth.ownerGeneration;

    store.hold = Completer<void>();
    final signOut = auth.signOut();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The generation moved, the client is still the old one.
    expect(auth.ownerGeneration, isNot(generation));
    expect(auth.protectedRequestsAllowed, isFalse);
    expect(tester.state(find.byType(AppShell)), same(first));

    store.hold!.complete();
    await tester.runAsync(() => signOut);
    await pumpUntil(tester, () => auth.protectedRequestsAllowed);
    await tester.pump(const Duration(milliseconds: 100));
    final last = tester.state(find.byType(AppShell));
    expect(last, isNot(same(first)));
    final repositories = HermesRepositories.maybeOf(
      tester.element(find.byType(AppShell)),
    );
    expect(identical(repositories?.api, auth.api), isTrue);
    requests.clear();
    await pumpUntil(tester, () => requests.contains('/api/profiles'));
    await letSocketsIdle(tester);
  });
}

Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) return;
  }
  throw TestFailure('condition never held');
}
