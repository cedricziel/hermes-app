import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../widgetbook/focus_ring_use_cases.dart';

WidgetbookUseCase _useCase(String name) =>
    (focusRingNode() as WidgetbookComponent).useCases.firstWhere(
      (u) => u.name == name,
    );

/// Mounts [name] after a mouse press on another example, as in the catalog.
Future<void> _openAfterClick(WidgetTester tester, String name) async {
  addTearDown(forgetFocusRingWatchers);
  forgetFocusRingWatchers();
  await tester.pumpWidget(
    MaterialApp(theme: buildHermesLightTheme(), home: const Scaffold()),
  );
  // Starts the input tracking, as the previous example did.
  final probe = FilledButton(onPressed: () {}, child: const Text('x'));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(body: Center(child: probe)),
    ),
  );
  await tester.tap(find.text('x'), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(body: Builder(builder: _useCase(name).builder)),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('the menu-item preview shows its ring after a click elsewhere', (
    tester,
  ) async {
    await _openAfterClick(tester, 'Menu item');
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Try it" keeps pointer suppression after a click', (
    tester,
  ) async {
    await _openAfterClick(tester, 'Try it (press Tab)');
    final button = find.byType(FilledButton).first;
    Focus.of(tester.element(find.text('Filled'))).requestFocus();
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );
    expect(material.shape, isNot(isA<FocusRingBorder>()));
  });
}
