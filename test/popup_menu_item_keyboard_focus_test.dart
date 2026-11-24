import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/popup_trigger_callers.dart';
import 'support/test_localizations.dart';

/// Menu items of an `AdaptivePopupMenuButton`, opened and walked by keyboard
/// (Tab to the trigger, Enter, the arrow keys), under the real theme of each
/// platform. From the focus-ring test sweep (rows 2 and 3 of the line
/// manager's sweep, F.441 follow-up).
///
/// `focus_ring_controls_test.dart` (the Mac menu row and the Mac checked item,
/// about lines 518 and 558) already walks a Mac menu by keyboard. This file
/// adds: Tab and Enter to open the menu from the real callers (the log level
/// pill, a `GroupedMenuRow`), Windows, and the radius of the plain Material
/// item, which only this file catches.
///
/// The design record (`docs/design-briefs/windows-linux-platform-fixes.md`,
/// F7 and its addenda) decides it for every platform here: a focused menu item
/// shows a 2 px ring in the item, inset 2 and radius 4 (the Mac compact row
/// in `onPrimary` inside its own fill). So each case asserts exactly one such
/// ring, on the focused item's row, and that each ArrowDown moves the focus to
/// the next item.
const _platforms = [
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
  TargetPlatform.android,
];

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

bool _inside(BuildContext? context, Element ancestor) {
  if (context == null) return false;
  var within = identical(context, ancestor);
  context.visitAncestorElements((e) {
    within = identical(e, ancestor);
    return !within;
  });
  return within;
}

/// Whether either of the two contexts is within the other.
bool _related(BuildContext? a, Element b) =>
    _inside(a, b) || (a != null && _inside(b, a as Element));

String _owner(BuildContext? context) {
  if (context == null) return 'none';
  final names = <String>[context.widget.runtimeType.toString()];
  context.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && name != 'Focus' && name != 'Semantics') {
      names.add(name);
    }
    return names.length < 4;
  });
  return names.join(' < ');
}

/// The rows a menu is made of, by the widget each platform builds.
final _rowTypes = <(String, Finder)>[
  ('MacMenuRow', find.byType(MacMenuRow)),
  ('FocusRingMenuItem', find.byWidgetPredicate((w) => w is FocusRingMenuItem)),
  (
    'FocusRingCheckedMenuItem',
    find.byWidgetPredicate((w) => w is FocusRingCheckedMenuItem),
  ),
];

Widget _host() => AdaptivePopupMenuButton<String>(
  tooltip: '',
  onSelected: (_) {},
  child: const Padding(padding: EdgeInsets.all(8), child: Text('Menu')),
  itemBuilder: (_) => [
    const AdaptiveMenuItem<String>(value: 'rename', child: Text('Rename')),
    const CheckedPopupMenuItem<String>(
      value: 'sorted',
      checked: true,
      child: Text('Sorted'),
    ),
    const AdaptiveMenuItem<String>(
      value: 'delete',
      destructive: true,
      child: Text('Delete'),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  resetFocusRingInput();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view
    ..physicalSize = const Size(800, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme(platform: platform),
      builder: (_, child) => AppThemeScopes(child: child!),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(padding: const EdgeInsets.all(24), child: body),
        ),
      ),
    ),
  );
}

/// Tab until the focus is inside [trigger], then Enter: the menu opens.
Future<bool> _openByKeyboard(WidgetTester tester, Finder trigger) async {
  final popup = tester.element(trigger);
  for (var i = 0; i < 12; i++) {
    if (_inside(FocusManager.instance.primaryFocus?.context, popup)) break;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  if (!_inside(FocusManager.instance.primaryFocus?.context, popup)) {
    return false;
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  return _rowTypes.any((r) => r.$2.evaluate().isNotEmpty);
}

/// The row (type name, element) the primary focus sits on or in, if any.
(String, Element)? _focusedRow() {
  final focus = FocusManager.instance.primaryFocus?.context;
  for (final (name, finder) in _rowTypes) {
    for (final element in finder.evaluate()) {
      if (_related(focus, element)) return (name, element);
    }
  }
  return null;
}

void main() {
  void checkWalk(
    String name,
    TargetPlatform platform,
    Widget Function() build,
    Finder trigger, {
    required int items,
  }) {
    testWidgets('$name on ${platform.name}: arrow keys walk the items, each '
        'with one ring', (tester) async {
      await _pump(tester, platform, build());
      final opened = await _openByKeyboard(tester, trigger);
      final rows = <Element>[];
      final failures = <String>[];
      expect(opened, isTrue, reason: 'Tab, then Enter, opens the menu');
      for (var step = 0; step < items; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final focus = FocusManager.instance.primaryFocus?.context;
        final row = _focusedRow();
        final rings = _ringFinder.evaluate().length;
        var detail =
            'step ${step + 1}: ${_owner(focus)} '
            'row=${row?.$1 ?? 'none'} rings=$rings';
        if (row == null) {
          failures.add('$detail (focus is not on an item)');
        } else if (rings != 1) {
          failures.add('$detail (want 1 ring)');
        } else {
          final box = tester.getRect(
            find.byElementPredicate((e) => identical(e, row.$2)),
          );
          final ring = tester.getRect(_ringFinder);
          final painter =
              tester.widget<CustomPaint>(_ringFinder).foregroundPainter!
                  as FocusRingPainter;
          detail +=
              ' ring=$ring row=$box radius=${painter.radius} '
              'inset=${painter.inset}';
          if (ring != box || painter.radius != 4 || painter.inset != 2) {
            failures.add('$detail (want the row, radius 4, inset 2)');
          }
        }
        if (row != null) {
          if (rows.any((e) => identical(e, row.$2))) {
            failures.add('$detail (ArrowDown did not move to a new item)');
          }
          rows.add(row.$2);
        }
      }
      expect(
        rows,
        hasLength(items),
        reason: 'each ArrowDown reaches the next of $items items',
      );
      final tops = [
        for (final row in rows)
          tester.getRect(find.byElementPredicate((e) => identical(e, row))).top,
      ];
      expect(tops, orderedEquals([...tops]..sort()), reason: 'in order');
      expect(failures, isEmpty);
    });
  }

  for (final platform in _platforms) {
    checkWalk(
      'host menu (plain, checked, destructive)',
      platform,
      _host,
      find.byType(AdaptivePopupMenuButton<String>),
      items: 3,
    );
    final pill = popupCallers.singleWhere((c) => c.name == 'log level pill');
    checkWalk(
      'log level pill (checked items)',
      platform,
      pill.build,
      pill.popup,
      items: 3,
    );
    final value = popupCallers.singleWhere(
      (c) => c.name == 'grouped value row',
    );
    checkWalk(
      'GroupedMenuRow (checked items)',
      platform,
      value.build,
      value.popup,
      items: 2,
    );
  }
}
