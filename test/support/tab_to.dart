import 'package:flutter/widgets.dart' show FocusManager;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presses Tab until the primary focus is on a node inside [finder]'s first
/// match, as a keyboard user reaches a control, and fails with where the focus
/// is if it is not there after [maxTabs] presses. Each press settles the
/// frame, so there is no fixed delay.
///
/// A focus ring geometry case reaches its control with this, not with
/// `requestFocus`: a node focused by hand can be one no Tab ever reaches (a
/// row's inert node, a control above the one that draws the ring), which is
/// how a Mac `GroupedMenuRow` showed no ring while its test passed
/// (`test.geometry-focus-by-key`).
Future<void> tabTo(
  WidgetTester tester,
  Finder finder, {
  int maxTabs = 30,
}) async {
  final target = tester.element(finder.first);
  bool onTarget() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    var within = identical(context, target);
    context.visitAncestorElements((e) {
      within = identical(e, target);
      return !within;
    });
    return within;
  }

  for (var presses = 0; presses < maxTabs; presses++) {
    if (onTarget()) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  if (onTarget()) return;
  final focus = FocusManager.instance.primaryFocus?.context;
  fail(
    'Tab did not reach ${finder.toString()} in $maxTabs presses; the primary '
    'focus is on ${focus == null ? 'nothing' : focus.widget.runtimeType}.',
  );
}
