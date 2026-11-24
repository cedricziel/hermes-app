import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// `FocusRing.onlyFor` follows the primary focus of one node; a new node to
/// follow must be judged at once, not on the next focus move.
void main() {
  final ring = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
  );

  testWidgets('swapping onlyFor to a node without focus drops the ring', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    resetFocusRingInput();
    final focused = FocusNode(debugLabel: 'focused');
    final other = FocusNode(debugLabel: 'other');
    addTearDown(focused.dispose);
    addTearDown(other.dispose);

    Widget app(FocusNode follows) => MaterialApp(
      theme: buildHermesLightTheme(),
      home: Column(
        children: [
          FocusRing(
            onlyFor: follows,
            child: Focus(focusNode: focused, child: const SizedBox(height: 40)),
          ),
          Focus(focusNode: other, child: const SizedBox(height: 40)),
        ],
      ),
    );

    await tester.pumpWidget(app(focused));
    focused.requestFocus();
    await tester.pump();
    expect(ring, findsOneWidget);

    await tester.pumpWidget(app(other));
    await tester.pump();

    expect(focused.hasPrimaryFocus, isTrue);
    expect(ring, findsNothing);
  });
}
