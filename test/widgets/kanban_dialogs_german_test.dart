import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// A German device gets German words in the four Kanban dialogs: their
/// titles, fields, switches and buttons.
void main() {
  late BuildContext context;

  Future<void> open(
    WidgetTester tester,
    Future<void> Function() Function() show,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    unawaited(show()());
    await tester.pumpAndSettle();
  }

  void expectGerman(List<String> labels) {
    for (final label in labels) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  }

  testWidgets('board export is German', (tester) async {
    await open(
      tester,
      () =>
          () => showKanbanExportDialog(context, name: 'Ops'),
    );
    expectGerman([
      'Ops exportieren',
      'Server-Pfad',
      'Export-Ordner verwenden',
      'Anhänge einbeziehen',
      'Worker-Logs einbeziehen',
      'Das Archiv wird auf dem Server geschrieben, nicht auf diesem Gerät. Bleibt es leer, wird der Export-Ordner des Servers verwendet.',
      'Abbrechen',
      'Exportieren',
    ]);
  });

  testWidgets('board import is German', (tester) async {
    await open(
      tester,
      () =>
          () => showKanbanImportDialog(context),
    );
    expectGerman([
      'Board importieren',
      'Archivpfad',
      'Das Archiv muss bereits auf dem Server liegen.',
      'Neuer Board-Slug',
      'Optional',
      'Danach öffnen',
      'Abbrechen',
      'Importieren',
    ]);
  });

  testWidgets('a Kanban text prompt has a German Cancel', (tester) async {
    await open(
      tester,
      () =>
          () =>
              askKanbanText(context, title: 'Neues Board', confirm: 'Anlegen'),
    );
    expectGerman(['Neues Board', 'Abbrechen', 'Anlegen']);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('edit task is German', (tester) async {
    await open(
      tester,
      () =>
          () => showKanbanTaskEditDialog(
            context,
            const KanbanTask(id: 't1', title: 'Write notes', status: 'todo'),
          ),
    );
    expectGerman([
      'Aufgabe bearbeiten',
      'Titel',
      'Beschreibung',
      'Abbrechen',
      'Speichern',
    ]);
  });

  testWidgets('orchestration is German', (tester) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/orchestration', {
        'orchestrator_profile': '',
        'default_assignee': '',
        'auto_decompose': false,
        'auto_promote_children': true,
        'active_profile': 'default',
      })
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]});
    await open(
      tester,
      () =>
          () => showKanbanOrchestrationDialog(
            context,
            repository: KanbanRepository(server.client()),
          ),
    );
    expectGerman([
      'Orchestrierung',
      'Orchestrator-Profil',
      'Aktives Profil (default)',
      'Triage-Aufgaben automatisch zerlegen',
      'Aus: von Hand zerlegen',
      'Unteraufgaben weiterschieben, sobald sie bereit sind',
      'Standardmäßig zuständig',
      'Abbrechen',
      'Speichern',
    ]);
  });

  testWidgets('orchestration says so in German when it cannot load', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/orchestration', {
        'detail': 'boom',
      }, status: 500);
    await open(
      tester,
      () =>
          () => showKanbanOrchestrationDialog(
            context,
            repository: KanbanRepository(server.client()),
          ),
    );
    expect(
      find.text('Die Einstellungen konnten nicht geladen werden'),
      findsOneWidget,
    );
  });
}
