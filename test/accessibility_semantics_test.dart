import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_comments.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_header.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_runs.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ChangeNotifierProvider(
    create: (_) => AuthController(),
    child: MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ),
);

const _task = KanbanTask(id: 't_1', title: 'Write the docs', status: 'todo');

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('sidebar destinations are buttons, the open one selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ShellNavigation(
        destinations: const [
          (icon: AppIcons.chat, selected: AppIcons.chatFilled, label: 'Chat'),
          (
            icon: AppIcons.kanban,
            selected: AppIcons.kanbanFilled,
            label: 'Kanban',
          ),
          (
            icon: AppIcons.scheduleOutlined,
            selected: AppIcons.schedule,
            label: 'Schedules',
          ),
        ],
        selectedIndex: 1,
        onSelected: (_) {},
      ),
    );

    for (final label in ['Chat', 'Kanban', 'Schedules']) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          isSelected: label == 'Kanban',
        ),
      );
    }
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('New chat is a button and More says whether it is open', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: ThreadSidebar(
              threads: const [],
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
              onOpenSkills: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('New chat')),
      isSemantics(label: 'New chat', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.text('More')),
      isSemantics(
        label: 'More',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: false,
      ),
    );
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(
      tester.getSemantics(find.text('More')),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  // macOS reads a node's name from its label only; a tooltip never reaches
  // the AX tree there, and iOS would read a label and a tooltip twice.
  Matcher namedButton(String name) =>
      isSemantics(label: name, tooltip: '', isButton: true);

  testWidgets('composer buttons are named and the field has its hint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      ChatComposer(
        controller: controller,
        onSend: (_) {},
        onAttach: () {},
        attachments: const [],
        onRemoveAttachment: (_) {},
        replying: false,
        queued: const [],
        onRemoveQueued: (_) {},
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.add)),
      namedButton('Add attachment'),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.arrow_upward)),
      namedButton('Send'),
    );
    expect(
      tester.getSemantics(find.byType(EditableText)),
      isSemantics(isTextField: true, label: 'Message Hermes…'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('task header: Move to is a button, Edit has a name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanTaskHeader(
        task: _task,
        onEdit: () {},
        onAssign: () {},
        onPrioritise: () {},
        onMove: (_) {},
      ),
    );

    expect(
      tester.getSemantics(find.text('Move to…')),
      isSemantics(
        label: 'Move to…',
        tooltip: '',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.edit_outlined)),
      namedButton('Edit'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('task history is a button that expands', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanTaskRuns(
        runs: const [],
        events: const [KanbanEvent(kind: 'created')],
        taskRunning: false,
        onTerminate: (_) {},
        onShowLog: () {},
      ),
    );

    expect(
      tester.getSemantics(find.text('History')),
      isSemantics(
        label: 'History',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: false,
      ),
    );
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('History')),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('comments: the heading is a header, send has a name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KanbanTaskComments(comments: const [], onSend: (_) async => true),
    );

    expect(
      tester.getSemantics(find.text('COMMENTS (0)')),
      isSemantics(label: 'Comments (0)', isHeader: true),
    );
    expect(tester.getSemantics(find.byIcon(Icons.send)), namedButton('Send'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a job switch is named after its job', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      JobTile(
        job: const CronJob(id: 'j1', name: 'Morning digest'),
        now: DateTime(2026, 10, 3),
        onTap: () {},
        onPausedChanged: (_) {},
      ),
    );

    expect(
      tester.getSemantics(find.byType(Switch)),
      isSemantics(
        label: 'Morning digest',
        hasToggledState: true,
        isToggled: true,
      ),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
