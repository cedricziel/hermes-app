import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pumpGroup(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.macOS),
    home: const Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: ToolCallGroup(
            calls: [
              ToolCall(
                name: 'terminal',
                summary: 'Inspect redacted output',
                args: {'command': 'inspect-fixture'},
                result: 'TOKEN=[REDACTED]',
                outputRisk: ToolOutputRisk(
                  risk: 'secret',
                  findings: ['Credential-like output was redacted.'],
                  redacted: true,
                ),
              ),
              ToolCall(name: 'read_file', summary: 'Read fixture'),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'opening a grouped warning child preserves the group and reveals findings and redacted body',
    (tester) async {
      await _pumpGroup(tester);
      await tester.tap(find.text('Used 2 tools'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolCallCard), findsNWidgets(2));
      expect(find.text('Credential-like output was redacted.'), findsNothing);
      expect(find.text('TOKEN=[REDACTED]'), findsNothing);

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      expect(find.text('Output risk: secret · Redacted'), findsOneWidget);
      expect(find.text('Credential-like output was redacted.'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, 'TOKEN=[REDACTED]'),
        findsOneWidget,
      );
      expect(find.text('Used 2 tools'), findsOneWidget);
      expect(find.byType(ToolCallCard), findsNWidgets(2));
      expect(find.text('read_file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the grouped warning child owns its semantic disclosure action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpGroup(tester);
      await tester.tap(find.text('Used 2 tools'));
      await tester.pumpAndSettle();
      final child = tester.getSemantics(find.text('terminal'));
      final before = child.getSemanticsData();
      expect(before.flagsCollection.isButton, isTrue);
      expect(before.flagsCollection.isExpanded, Tristate.isFalse);
      expect(before.hasAction(SemanticsAction.tap), isTrue);

      tester
          .renderObject(find.text('terminal'))
          .owner!
          .semanticsOwner!
          .performAction(child.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(find.text('terminal'))
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
      expect(find.text('Credential-like output was redacted.'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, 'TOKEN=[REDACTED]'),
        findsOneWidget,
      );
      expect(find.byType(ToolCallCard), findsNWidgets(2));
      expect(find.text('read_file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
