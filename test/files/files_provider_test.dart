import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app/providers/auth_providers.dart';
import 'package:hermes_app/src/files/open_files.dart';
import 'package:provider/provider.dart';

import 'package:hermes_app/src/files/files_availability.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';

import '../support/fake_hermes_server.dart';

Widget _app(HermesRepositories? repositories) => MaterialApp(
  home: MultiProvider(
    providers: [
      Provider<HermesRepositories?>.value(value: repositories),
      filesAvailabilityProvider(),
    ],
    child: Builder(
      builder: (context) => Text(filesShown(context) ? 'files' : 'none'),
    ),
  ),
);

Future<void> _until(WidgetTester tester, String text) async {
  for (var i = 0; i < 100 && find.text(text).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// The real provider definition, not `ChangeNotifierProvider.value`: a plain
/// `ProxyProvider` of a `ChangeNotifier` throws in debug builds and never
/// rebuilds its readers in release.
void main() {
  testWidgets('the entry points appear when the probe answers', (tester) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/fs/default-cwd', {'cwd': '/x'});

    await tester.pumpWidget(_app(HermesRepositories(server.client())));
    expect(find.text('none'), findsOneWidget);
    await _until(tester, 'files');

    expect(tester.takeException(), isNull);
    expect(find.text('files'), findsOneWidget);
  });

  testWidgets('signed out, nothing is offered and nothing throws', (
    tester,
  ) async {
    await tester.pumpWidget(_app(null));
    expect(find.text('none'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new connection asks again, and the old probe is disposed', (
    tester,
  ) async {
    final held = Completer<FakeResponse>();
    final first = FakeHermesServer()
      ..onRequest('GET', '/api/fs/default-cwd', (_) => held.future);
    final second = FakeHermesServer()
      ..on('GET', '/api/fs/default-cwd', {'cwd': '/x'});

    await tester.pumpWidget(_app(HermesRepositories(first.client())));
    // The first probe is still waiting for its answer.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('none'), findsOneWidget);
    final old = Provider.of<FilesAvailability?>(
      tester.element(find.text('none')),
      listen: false,
    )!;
    expect(first.requests, hasLength(1), reason: 'the probe is really out');

    await tester.pumpWidget(_app(HermesRepositories(second.client())));
    await _until(tester, 'files');
    expect(find.text('files'), findsOneWidget);
    expect(old.isDisposed, isTrue);

    // The old answer arriving now changes nothing.
    held.complete((status: 404, body: {'detail': 'no'}));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'the app builds its providers with the Files availability in them',
    () async {
      final telemetry = await Telemetry.initialize(
        const TelemetryConfig(
          otlpEndpoint: '',
          otlpHeaders: {},
          serviceName: 'test',
          serviceVersion: '',
          deploymentEnvironment: 'test',
        ),
      );
      final providers = authProviders(telemetry);

      expect(
        providers
            .whereType<
              ChangeNotifierProxyProvider<
                HermesRepositories?,
                FilesAvailability?
              >
            >(),
        hasLength(1),
        reason: 'a plain ProxyProvider of a ChangeNotifier throws in debug',
      );
    },
  );
}
