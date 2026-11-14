import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';
import 'package:hermes_app/src/tools/widgets/risk_note.dart';

import 'pump_tools.dart';

void main() {
  const titles = {
    ToolsetRiskKind.runCommands: 'Can change things on your server',
    ToolsetRiskKind.runPrograms: 'Can change things on your server',
    ToolsetRiskKind.changeFiles: 'Can change things on your server',
    ToolsetRiskKind.controlComputer: 'Can see and control a computer',
    ToolsetRiskKind.actOnWebPages: 'Can act on web pages for you',
    ToolsetRiskKind.actOnItsOwn: 'Can act on its own',
    ToolsetRiskKind.manageDiscord: 'Can change your Discord server',
  };

  for (final MapEntry(key: kind, value: title) in titles.entries) {
    testWidgets('$kind is one element, title then sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTools(tester, RiskNote(kind: kind));
      expect(find.text(title), findsOneWidget);
      final label = tester.getSemantics(find.byType(RiskNote)).label;
      expect(label, startsWith('$title. Hermes can'));
      expect(label, isNot(contains('asks before')));
      handle.dispose();
    });
  }

  testWidgets('a confirm level adds that Hermes asks first', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTools(
      tester,
      const RiskNote(kind: ToolsetRiskKind.runCommands, confirmLevel: true),
    );
    expect(find.text('Hermes asks before you switch it on.'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(RiskNote)).label,
      endsWith('Hermes asks before you switch it on.'),
    );
    handle.dispose();
  });

  testWidgets('the border is the text colour and 1 pt wide', (tester) async {
    await pumpTools(
      tester,
      const RiskNote(kind: ToolsetRiskKind.controlComputer),
    );
    final box = tester.widget<Container>(find.byType(Container).first);
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 1);
    expect(
      border.top.color,
      Theme.of(tester.element(find.byType(RiskNote))).colorScheme.onSurface,
    );
  });

  testWidgets('wraps at the largest text size without overflow', (
    tester,
  ) async {
    await pumpTools(
      tester,
      const RiskNote(kind: ToolsetRiskKind.controlComputer, confirmLevel: true),
      textScale: 3,
      locale: const Locale('de'),
    );
    expect(tester.takeException(), isNull);
  });
}
