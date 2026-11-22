import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';

import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// The four Kanban dialogs with their own actions open through `showAppDialog`:
/// iOS gets the Cupertino route (a barrier tap keeps it, Esc still closes it),
/// macOS keeps a click outside for orchestration only, since the three text
/// dialogs must not lose typed text to a stray click, and Material is as it was.
void main() {
  late BuildContext context;

  Future<void> pump(WidgetTester tester, TargetPlatform platform) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

  KanbanRepository repository() {
    final server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/orchestration', {
        'orchestrator_profile': 'lead',
        'default_assignee': 'coder',
        'auto_decompose': false,
        'auto_promote_children': true,
        'active_profile': 'default',
      })
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder'],
      });
    return KanbanRepository(server.client());
  }

  // name, what is on screen, whether it holds typed text, how it opens.
  final dialogs = <(String, String, bool, Future<void> Function())>[
    (
      'board export',
      'Export Ops',
      true,
      () => showKanbanExportDialog(context, name: 'Ops'),
    ),
    (
      'board import',
      'Import a board',
      true,
      () => showKanbanImportDialog(context),
    ),
    (
      'edit task',
      'Edit task',
      true,
      () => showKanbanTaskEditDialog(
        context,
        const KanbanTask(id: 't1', title: 'Write notes', status: 'todo'),
      ),
    ),
    (
      'orchestration',
      'Orchestration',
      false,
      () => showKanbanOrchestrationDialog(context, repository: repository()),
    ),
  ];

  Future<void> open(
    WidgetTester tester,
    TargetPlatform platform,
    Future<void> Function() show,
    String marker,
  ) async {
    await pump(tester, platform);
    unawaited(show());
    await tester.pumpAndSettle();
    expect(find.text(marker), findsWidgets);
  }

  Future<void> clickBarrier(WidgetTester tester) async {
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  }

  Future<void> esc(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  for (final (name, marker, _, show) in dialogs) {
    testWidgets('$name on iOS: a barrier tap keeps it, Esc closes it', (
      tester,
    ) async {
      await open(tester, TargetPlatform.iOS, show, marker);
      await clickBarrier(tester);
      expect(find.text(marker), findsWidgets);
      await esc(tester);
      expect(find.text(marker), findsNothing);
    });

    testWidgets('$name on macOS: Esc closes it', (tester) async {
      await open(tester, TargetPlatform.macOS, show, marker);
      await esc(tester);
      expect(find.text(marker), findsNothing);
    });

    testWidgets('$name on Android: a barrier tap closes it', (tester) async {
      await open(tester, TargetPlatform.android, show, marker);
      await clickBarrier(tester);
      expect(find.text(marker), findsNothing);
    });
  }

  final (_, orchestrationMarker, _, orchestrate) = dialogs.last;
  testWidgets('orchestration on macOS: a click outside closes it', (
    tester,
  ) async {
    await open(tester, TargetPlatform.macOS, orchestrate, orchestrationMarker);
    await clickBarrier(tester);
    expect(find.text(orchestrationMarker), findsNothing);
  });

  for (final (name, marker, _, show) in dialogs.where((d) => d.$3)) {
    testWidgets('$name on macOS: a click outside keeps it and the typed text', (
      tester,
    ) async {
      await open(tester, TargetPlatform.macOS, show, marker);
      await tester.enterText(find.byType(EditableText).first, 'typed words');
      await clickBarrier(tester);
      expect(find.text(marker), findsWidgets);
      expect(find.text('typed words'), findsOneWidget);
    });
  }

  testWidgets('board import on iOS: its autofocused field keeps focus', (
    tester,
  ) async {
    final (_, marker, _, show) = dialogs[1];
    await open(tester, TargetPlatform.iOS, show, marker);
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.focusNode.hasPrimaryFocus, isTrue);
  });

  for (final index in [0, 2]) {
    final (name, marker, _, show) = dialogs[index];
    testWidgets('$name on iOS: a tap in the text field takes focus', (
      tester,
    ) async {
      await open(tester, TargetPlatform.iOS, show, marker);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(field.focusNode.hasPrimaryFocus, isTrue);
    });
  }

  // A pointer click that takes focus out of the field must not strand Esc above
  // the binding (the setup and the click are those of dialog_esc_guard_test).
  Future<void> click(WidgetTester tester, Offset at) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: at);
    await gesture.down(at);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    for (final (name, marker, _, show) in dialogs.where((d) => d.$3)) {
      for (final target in const ['barrier', 'title']) {
        testWidgets('$name on ${platform.name}: a click on the $target, '
            'then Esc, closes it', (tester) async {
          await open(tester, platform, show, marker);
          final field = tester.widget<EditableText>(
            find.byType(EditableText).first,
          );
          await tester.tap(find.byType(EditableText).first);
          await tester.enterText(find.byType(EditableText).first, 'draft');
          await tester.pump();
          expect(field.focusNode.hasPrimaryFocus, isTrue);
          await click(
            tester,
            target == 'barrier'
                ? const Offset(4, 4)
                : tester.getCenter(find.text(marker).first),
          );
          expect(field.focusNode.hasPrimaryFocus, isFalse);
          // The click may be closing the dialog: let that finish first.
          await tester.pumpAndSettle();
          expect(find.text(marker), findsWidgets);
          await esc(tester);
          expect(find.text(marker), findsNothing);
        });
      }
    }
  }
}
