import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

void main() {
  testWidgets('settings opens memory for an explicit active profile', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [profileRow(name: 'work'), profileRow(name: 'other')],
      })
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/learning/graph', memoryGraph);
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: HermesRepositories(server.client()),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('Settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('Memory'));
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Long memory'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/learning/graph').single.queryParameters,
      {'profile': 'work'},
    );
    await tester.tap(find.byKey(const Key('settings-subtitle-menu')));
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('other').last);
    await tester.runAsync(() async {
      await pumpEventQueue();
    });
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(
      server.requestsTo('GET', '/api/learning/graph').last.queryParameters,
      {'profile': 'other'},
    );
    expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
  });
}
