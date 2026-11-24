import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/popup_trigger_callers.dart';
import 'support/test_localizations.dart';

/// Off iOS, does each `AdaptivePopupMenuButton(child:)` caller show a keyboard
/// focus ring when reached by Tab, and where does the focus land? Roadmap
/// row: popup callers off iOS (F.441 follow-up).
///
/// The design record ("F.441 popup trigger (design pass)",
/// `docs/design-briefs/windows-linux-platform-fixes.md`) decides a ring for
/// iOS only and leaves Mac and Material "untouched": there is no decision for
/// these platforms, so the cases assert only that the trigger is reached by
/// Tab and that some visible focus indication shows (a ring, or a Material
/// focus fill). The one decided Mac case is the pop-up value of a grouped
/// form (F.427 table D, #1307): one ring outside the face, radius 6.
///
/// Each case prints a `POPUP-FOCUS` row: caller | platform | focus lands on |
/// rings | Material fill.
const _platforms = [
  TargetPlatform.macOS,
  TargetPlatform.android,
  TargetPlatform.windows,
  TargetPlatform.linux,
];

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

/// The widget types nearest above [context], for saying whose node it is.
String _owner(BuildContext context) {
  final names = <String>[context.widget.runtimeType.toString()];
  context.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && name != 'Focus' && name != 'Semantics') {
      names.add(name);
    }
    return names.length < 5;
  });
  return names.join(' < ');
}

/// The alpha of the Material focus fill the focused node's ink well would
/// draw, 0 when none (the Mac theme clears it) or there is no ink well.
double _focusFill(BuildContext context) {
  InkResponse? ink;
  if (context.widget is InkResponse) ink = context.widget as InkResponse;
  context.visitAncestorElements((e) {
    if (ink == null && e.widget is InkResponse) {
      ink = e.widget as InkResponse;
      return false;
    }
    return ink == null;
  });
  final found = ink;
  if (found == null) return 0;
  final color = found.focusColor ?? Theme.of(context).focusColor;
  return color.a;
}

bool _inside(BuildContext? context, Element ancestor) {
  if (context == null) return false;
  var within = identical(context, ancestor);
  context.visitAncestorElements((e) {
    within = identical(e, ancestor);
    return !within;
  });
  return within;
}

void main() {
  setUp(() {
    resetFocusRingInput();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final caller in popupCallers) {
    for (final platform in _platforms) {
      testWidgets('${caller.name} on ${platform.name}: Tab reaches the '
          'trigger and a focus indication shows', (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: caller.build(),
                ),
              ),
            ),
          ),
        );

        final popup = tester.element(caller.popup);
        var tabs = 0;
        while (tabs < 12 &&
            !_inside(FocusManager.instance.primaryFocus?.context, popup)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          tabs++;
        }
        final focus = FocusManager.instance.primaryFocus;
        final reached = _inside(focus?.context, popup);
        final rings = _ringFinder.evaluate().length;
        final fill = reached ? _focusFill(focus!.context!) : 0.0;
        // ignore: avoid_print
        print(
          'POPUP-FOCUS | ${caller.name} | ${platform.name} | '
          '${reached ? 'Tab x$tabs: ${_owner(focus!.context!)}' : 'not reached in 12 Tabs: ${focus?.context == null ? 'none' : _owner(focus!.context!)}'}'
          ' | rings=$rings | fill alpha=${fill.toStringAsFixed(2)}',
        );

        expect(reached, isTrue, reason: 'Tab reaches the trigger');
        expect(
          rings > 0 || fill > 0,
          isTrue,
          reason: 'some visible focus indication (no decision for the shape)',
        );
        if (caller.name == 'grouped value row' &&
            platform == TargetPlatform.macOS) {
          // F.427 table D (#1307): one ring outside the pop-up face, radius 6.
          expect(rings, 1, reason: 'one ring');
          final face = find
              .ancestor(
                of: find.text('anthropic'),
                matching: find.byType(Material),
              )
              .first;
          expect(tester.getRect(_ringFinder), tester.getRect(face));
        }
      });
    }
  }
}
