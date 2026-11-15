import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/memory/memory_controller.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/widgets/memory_reset_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

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
    expect(
      find.text(
        'Wenn du gehst, wird dein ungespeicherter Entwurf verworfen. '
        'Eine unbestätigte Änderung kann trotzdem durchgegangen sein.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('All memories'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Wenn du gehst, wird dein ungespeicherter Entwurf verworfen. '
        'Eine unbestätigte Änderung kann trotzdem durchgegangen sein.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Verwerfen und verlassen'));
    await tester.pumpAndSettle();
    expect(controller.draft, isNull);
  });

  testWidgets('the leave confirmation names a request that is still out', (
    tester,
  ) async {
    final hold = Completer<FakeResponse>();
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail)
      ..on('GET', '/api/config', memoryConfig())
      ..onRequest('PUT', '/api/learning/node', (_) => hold.future);
    final controller = MemoryController();
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      controller.bind(MemoryRepository(server.client().raw), 'work');
      await pumpEventQueue();
      await controller.open(controller.entries.first);
    });
    await tester.pumpWidget(_german(MemoryScreen(controller: controller)));
    await tester.pumpAndSettle();
    controller.beginEdit();
    controller.setDraft('Changed');
    unawaited(controller.mutate(delete: false));
    await tester.pump();
    await tester.ensureVisible(find.text('All memories'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('All memories'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text(
        'Die Anfrage kann im ursprünglichen Profil noch abgeschlossen '
        'werden. Wenn du gehst, wird dieser Entwurf verworfen.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Entwurf behalten'));
    await tester.pump(const Duration(milliseconds: 400));
    hold.complete((status: 200, body: {'ok': true}));
    await tester.pumpAndSettle();
  });

  testWidgets('confirming the delete sends one DELETE', (tester) async {
    late final FakeHermesServer server;
    server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', memoryGraph)
      ..on('GET', '/api/learning/node', memoryDetail)
      ..on('GET', '/api/config', memoryConfig())
      ..onRequest('DELETE', '/api/learning/node', (_) {
        server.on('GET', '/api/learning/graph', {'nodes': []});
        return (status: 200, body: {'ok': true});
      });
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
    await tester.runAsync(() async {
      await tester.tap(find.text('Endgültig löschen'));
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
    expect(server.requestsTo('DELETE', '/api/learning/node'), hasLength(1));
  });

  for (final (count, text) in [
    (
      1,
      'Hermes verwirft die eine Änderung, die hier aufgelistet ist. '
          'Das lässt sich nicht rückgängig machen.',
    ),
    (
      3,
      'Hermes verwirft die 3 Änderungen, die hier aufgelistet sind. '
          'Das lässt sich nicht rückgängig machen.',
    ),
  ]) {
    testWidgets('the reject-all confirmation reads right for $count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _german(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDestructiveConfirm(
                context,
                title: context.l10n.memoryRejectAllTitle,
                message: context.l10n.memoryRejectAllMessage(count),
                confirmLabel: context.l10n.memoryRejectAllAction,
                cancelLabel: MaterialLocalizations.of(context)
                    .cancelButtonLabel,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Alle Änderungen ablehnen?'), findsOneWidget);
      expect(find.text(text), findsOneWidget);
      expect(find.text('Alle ablehnen'), findsOneWidget);
    });
  }
}
