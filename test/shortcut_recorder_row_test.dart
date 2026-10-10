import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_panel/widgets/quick_panel_shortcut_row.dart';

import 'support/fake_global_shortcut.dart';

void main() {
  late FakeGlobalShortcut shortcut;

  setUp(() => shortcut = FakeGlobalShortcut());
  tearDown(() => shortcut.dispose());

  Future<void> pumpRow(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickPanelShortcutRow(
          shortcut: shortcut,
          recorder: const SizedBox(key: Key('recorder')),
        ),
      ),
    ),
  );

  testWidgets('without a shortcut the row asks for one', (tester) async {
    await pumpRow(tester);
    await tester.pump();

    expect(find.text('Quick panel'), findsOneWidget);
    expect(
      find.text('Record a shortcut to ask Hermes from any app.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recorder')), findsOneWidget);
  });

  testWidgets('a recorded shortcut shows as set', (tester) async {
    shortcut.recorded = true;
    await pumpRow(tester);
    await tester.pump();

    expect(
      find.text('Press the shortcut in any app to ask Hermes.'),
      findsOneWidget,
    );
  });

  testWidgets('follows the recorder recording and clearing', (tester) async {
    await pumpRow(tester);
    await tester.pump();

    shortcut.change(set: true);
    await tester.pump();
    expect(
      find.text('Press the shortcut in any app to ask Hermes.'),
      findsOneWidget,
    );

    shortcut.change(set: false);
    await tester.pump();
    expect(
      find.text('Record a shortcut to ask Hermes from any app.'),
      findsOneWidget,
    );
  });

  testWidgets('a late answer to the first read does not undo a recording', (
    tester,
  ) async {
    shortcut.pendingIsSet = Completer<bool>();
    await pumpRow(tester);

    shortcut.change(set: true);
    shortcut.pendingIsSet!.complete(false);
    await tester.pump();

    expect(
      find.text('Press the shortcut in any app to ask Hermes.'),
      findsOneWidget,
    );
  });
}
