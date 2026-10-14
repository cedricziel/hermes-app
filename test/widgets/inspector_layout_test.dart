import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/inspector_layout.dart';

void main() {
  Future<void> pump(WidgetTester tester, double width, VoidCallback dismiss) {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InspectorLayout(
            content: const Text('content'),
            shown: true,
            inspector: const Text('inspector'),
            panelKey: const Key('panel'),
            onDismissOverlay: dismiss,
          ),
        ),
      ),
    );
  }

  testWidgets('a wide layout docks the inspector with nothing to dismiss', (
    tester,
  ) async {
    await pump(tester, 1200, () => fail('nothing to dismiss'));
    expect(tester.getRect(find.byKey(const Key('panel'))).left, 1200 - 380);
    expect(find.byKey(const Key('inspector-barrier')), findsNothing);
  });

  testWidgets('a narrow overlay closes on a tap beside it or on Escape', (
    tester,
  ) async {
    var dismissed = 0;
    await pump(tester, 700, () => dismissed++);
    await tester.tapAt(const Offset(50, 300));
    expect(dismissed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissed, 2);
  });
}
