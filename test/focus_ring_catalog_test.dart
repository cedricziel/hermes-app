import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:widgetbook/widgetbook.dart';

import '../widgetbook/focus_ring_use_cases.dart';
import '../widgetbook/model_use_cases.dart';

/// What the app and the catalog mount above the home.
Widget _scoped(BuildContext context, Widget? child) =>
    AppThemeScopes(child: child!);

WidgetbookUseCase _useCase(String name, [WidgetbookNode? from]) {
  WidgetbookUseCase? find(WidgetbookNode node) {
    if (node is WidgetbookUseCase) return node.name == name ? node : null;
    for (final child in node.children ?? const <WidgetbookNode>[]) {
      final hit = find(child);
      if (hit != null) return hit;
    }
    return null;
  }

  return find(from ?? focusRingNode())!;
}

/// Mounts [name] after a mouse press on another example, as in the catalog.
Future<void> _openAfterClick(
  WidgetTester tester,
  String name, {
  WidgetbookNode? from,
}) async {
  addTearDown(forgetFocusRingWatchers);
  forgetFocusRingWatchers();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      builder: _scoped,
      home: const Scaffold(),
    ),
  );
  // Starts the input tracking, as the previous example did.
  final probe = FilledButton(onPressed: () {}, child: const Text('x'));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      builder: _scoped,
      home: Scaffold(body: Center(child: probe)),
    ),
  );
  await tester.tap(find.text('x'), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      builder: _scoped,
      home: Scaffold(body: Builder(builder: _useCase(name, from).builder)),
    ),
  );
  await tester.pumpAndSettle();
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

  testWidgets('a keyboard-focus preview shows its ring after a click '
      'elsewhere', (tester) async {
    await _openAfterClick(tester, 'Filled button');
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(FilledButton).first,
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.shape, isA<FocusRingBorder>());
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

  for (final second in [
    'Mac thread row Archive (20 pt)',
    'Mac thread row More (20 pt)',
  ]) {
    testWidgets('a hover preview mounted after another one still gets '
        'focus and its ring ($second)', (tester) async {
      addTearDown(forgetFocusRingWatchers);
      Future<void> mount(String name) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesLightTheme(),
            builder: _scoped,
            home: Scaffold(body: Builder(builder: _useCase(name).builder)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount('Mac thread row Archive (20 pt)');
      // Another route in between disposes the first preview.
      await tester.pumpWidget(const SizedBox());
      await mount(second);
      expect(tester.takeException(), isNull);
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(IconButton).at(second.contains('More') ? 1 : 0),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.shape, isA<FocusRingBorder>());
    });
  }

  // A platform may draw a tappable row where another draws a button; each
  // variant of these previews must still show a ring.
  for (final name in [
    'Check for updates (iPhone)',
    'Check for updates (Mac)',
    'Check for updates (Material)',
    'Messaging Set up (iPhone)',
    'Messaging Set up (Mac)',
    'Messaging Set up (Material)',
  ]) {
    testWidgets('the "$name" preview shows a ring', (tester) async {
      await _openAfterClick(tester, name);
      final painted = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
      );
      final onButton = find.byWidgetPredicate(
        (w) => w is Material && w.shape is FocusRingBorder,
      );
      expect(
        painted.evaluate().isNotEmpty || onButton.evaluate().isNotEmpty,
        isTrue,
      );
    });
  }

  testWidgets('the popover\'s keyboard-focused row shows its ring after a '
      'click elsewhere', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _openAfterClick(
      tester,
      'Desktop popover: Keyboard focus on a row, wide',
      from: modelNode(),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
      ),
      findsOneWidget,
    );
  });
}
