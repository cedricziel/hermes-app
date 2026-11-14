import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';
import 'package:hermes_app/src/handoff/handoff_controller.dart';
import 'package:hermes_app/src/handoff/handoff_gate.dart';
import 'package:hermes_app/src/navigation/connection_pages.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_session_auth.dart';

class _Auth extends FakeSessionAuth {
  void poke() => notifyListeners();

  void retire() {
    generation++;
    notifyListeners();
  }
}

void main() {
  late _Auth auth;
  late PushedRoutes pushed;
  late ConnectionPageCloser closer;
  late BreadcrumbTrail trail;
  final nestedKey = GlobalKey<NavigatorState>();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = _Auth();
    pushed = PushedRoutes();
    closer = ConnectionPageCloser(pushed);
    trail = BreadcrumbTrail();
    closer
      ..breadcrumbs = Breadcrumbs.of(trail)
      ..bind(auth);
  });
  tearDown(() {
    closer.dispose();
    auth.dispose();
  });

  Future<NavigatorState> pumpApp(
    WidgetTester tester, {
    List<NavigatorObserver> observers = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [...observers, pushed],
        home: Navigator(
          key: nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    return Navigator.of(tester.element(find.text('home')), rootNavigator: true);
  }

  Route<void> page(String text) =>
      MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(text)));

  testWidgets('it records one breadcrumb with a count and nothing else', (
    tester,
  ) async {
    final root = await pumpApp(tester);
    unawaited(root.push(page('one')));
    await tester.pumpAndSettle();
    unawaited(root.push(page('two')));
    await tester.pumpAndSettle();

    auth.retire();
    await tester.pump();
    await tester.pump();

    final crumbs = trail.recent.toList();
    expect(crumbs.single.name, 'nav.connection_pages_closed');
    expect(crumbs.single.attributes, {'count': 2});
    expect(find.text('one', skipOffstage: false), findsNothing);
    expect(find.text('two', skipOffstage: false), findsNothing);
  });

  testWidgets('a route still sliding in is closed at once, without settling', (
    tester,
  ) async {
    final root = await pumpApp(tester);
    unawaited(root.push(page('sliding')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('sliding'), findsOneWidget);

    auth.retire();
    await tester.pump();

    expect(find.text('sliding', skipOffstage: false), findsNothing);
    expect(root.canPop(), isFalse);
  });

  testWidgets('nothing closes while the state is ready and the owner is the '
      'same', (tester) async {
    final root = await pumpApp(tester);
    unawaited(root.push(page('kept')));
    await tester.pumpAndSettle();

    auth.poke();
    auth.poke();
    await tester.pump();

    expect(find.text('kept'), findsOneWidget);
    expect(trail.recent, isEmpty);
  });

  testWidgets('a sign-out that leaves the state ready closes the root routes; '
      'a route on the shell\'s nested navigator stays', (tester) async {
    final root = await pumpApp(tester);
    unawaited(root.push(page('root page')));
    await tester.pumpAndSettle();
    final nested = nestedKey.currentState!;
    unawaited(nested.push(page('nested page')));
    await tester.pumpAndSettle();
    expect(auth.state, HermesConnectionState.ready);

    auth.retire();
    await tester.pumpAndSettle();

    expect(find.text('root page', skipOffstage: false), findsNothing);
    expect(auth.state, HermesConnectionState.ready);
    // The closer alone only sweeps the root navigator, and this test has a
    // fake auth and no shell. In the app `_RootRouter` also replaces the
    // shell once the new client is in place, which takes its nested
    // navigator with it; only the token-clear window keeps it.
    expect(find.text('nested page'), findsOneWidget);
  });

  testWidgets('nothing closes while the state is not ready, nor on entering '
      'ready', (tester) async {
    final root = await pumpApp(tester);
    unawaited(root.push(page('setup guide')));
    await tester.pumpAndSettle();
    // A page the setup screen opens, such as the VPN guide or the cleartext
    // question, while the app was never ready.
    auth.currentState = HermesConnectionState.connectionError;
    closer.dispose();
    final fresh = ConnectionPageCloser(pushed)
      ..breadcrumbs = Breadcrumbs.of(trail)
      ..bind(auth);
    addTearDown(fresh.dispose);

    for (final state in [
      HermesConnectionState.connectionError,
      HermesConnectionState.connecting,
      HermesConnectionState.connectionError,
      HermesConnectionState.ready,
    ]) {
      auth.currentState = state;
      auth.poke();
      auth.poke();
      await tester.pump();
      await tester.pump();
      expect(find.text('setup guide'), findsOneWidget, reason: state.name);
    }
    expect(trail.recent, isEmpty);
  });

  testWidgets('the handoff cover is not stale after a route is removed', (
    tester,
  ) async {
    final handoff = HandoffController(HandoffBridge(enabled: false));
    addTearDown(handoff.dispose);
    final observer = HandoffNavigationObserver()..handoff = handoff;
    final root = await pumpApp(tester, observers: [observer]);
    final route = page('covering');
    unawaited(root.push(route));
    await tester.pumpAndSettle();
    expect(handoff.covered, isTrue);

    root.removeRoute(route);
    await tester.pumpAndSettle();

    expect(handoff.covered, isFalse);
  });
}
