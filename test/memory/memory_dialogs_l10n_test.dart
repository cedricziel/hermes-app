import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/widgets/memory_reset_dialog.dart';

import '../support/fake_hermes_server.dart';
import 'memory_fixtures.dart';

Widget _german(Widget home) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('the reset dialog speaks German', (tester) async {
    await tester.pumpWidget(
      _german(
        Scaffold(
          body: MemoryResetAlert(
            profile: 'work',
            onPick: (_) {},
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.text('Gedächtnis zurücksetzen?'), findsOneWidget);
    expect(find.textContaining('für das Profil work'), findsOneWidget);
    expect(find.text('Beides zurücksetzen'), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Reset memory?'), findsNothing);
  });

  testWidgets('the delete and leave confirmations speak German', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail)
      ..on('GET', '/api/config', memoryConfig());
    final controller = MemoryController();
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      await controller.open(controller.entries.first);
    });
    await tester.pumpWidget(_german(MemoryScreen(controller: controller)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    expect(find.text('Diese Erinnerung endgültig löschen?'), findsOneWidget);
    expect(find.text('Endgültig löschen'), findsOneWidget);
    expect(find.text('Permanently delete this memory?'), findsNothing);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(server.requestsTo('DELETE', '/api/learning/node'), isEmpty);

    await tester.ensureVisible(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Changed');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('All memories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All memories'));
    await tester.pumpAndSettle();
    expect(find.text('Diese Erinnerung verlassen?'), findsOneWidget);
    await tester.tap(find.text('Entwurf behalten'));
    await tester.pumpAndSettle();
    expect(controller.draft, 'Changed');
  });
}
