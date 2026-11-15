import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/widgets/group_widgets.dart';
import 'package:hermes_app/src/skills/skill_editor_screen.dart';
import 'package:hermes_app/src/skills/widgets/skill_markdown_panel.dart';

import '../bot_mode/group_protocol/groups_repository_test.dart' as fixtures;

const _tasks = '- [ ] item\n- [x] done\n';
const _radios = '- ( ) option\n- (x) chosen\n';

/// A task list read from Markdown is drawn without a Material `Checkbox`
/// (which throws below a text span) and announces its state.
void _expectReadOnlyTasks(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(Checkbox), findsNothing);
  expect(find.byIcon(Icons.check_box), findsOneWidget);
  expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
  expect(
    tester.getSemantics(find.textContaining('item', findRichText: true)),
    isSemantics(
      hasCheckedState: true,
      isChecked: false,
      hasTapAction: false,
      isFocusable: false,
    ),
  );
  expect(
    tester.getSemantics(find.textContaining('done', findRichText: true)),
    isSemantics(
      hasCheckedState: true,
      isChecked: true,
      hasTapAction: false,
      isFocusable: false,
    ),
  );
}

void main() {
  testWidgets('skill detail panel renders radio options read-only', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkillMarkdownPanel(text: _radios)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Radio<bool>), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(
      tester.getSemantics(find.textContaining('option', findRichText: true)),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: false,
        isFocusable: false,
      ),
    );
    expect(
      tester.getSemantics(find.textContaining('chosen', findRichText: true)),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: false,
        isFocusable: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('skill detail panel renders a task list', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SkillMarkdownPanel(text: _tasks)),
      ),
    );
    _expectReadOnlyTasks(tester);
    handle.dispose();
  });

  testWidgets('group message renders a task list', (tester) async {
    final handle = tester.ensureSemantics();
    final event = GroupEvent.fromJson({
      ...fixtures.event(1, kind: 'message.assistant'),
      'actor': {'kind': 'member', 'id': 'one'},
      'payload': {'text': _tasks},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupEventRow(
            event: event,
            members: [GroupMember.fromJson(fixtures.member('one'))],
          ),
        ),
      ),
    );
    _expectReadOnlyTasks(tester);
    handle.dispose();
  });

  testWidgets('skill editor preview renders a task list', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: SkillEditorScreen.edit(
          name: 'x',
          initialText: '---\nname: x\n---\n$_tasks',
          onSave: (_, _, _) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    _expectReadOnlyTasks(tester);
    handle.dispose();
  });
}
