import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_menu_models.dart';
import 'package:hermes_app/src/navigation/widgets/desktop_menu_bar.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../support/test_localizations.dart';

/// The ring the bar draws for keyboard focus: inside the item, inset 2,
/// radius 4 (F7 in `docs/design-briefs/windows-linux-platform-fixes.md`).
final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

void _noop() {}

void main() {
  for (final dark in [false, true]) {
    testWidgets('keyboard focus rings a menu and its items '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      resetFocusRingInput();
      final registry = MacCommandRegistry();
      final registration = registry.register({
        MacCommand.newChat: const MacCommandHandler(_noop),
        MacCommand.settings: const MacCommandHandler(_noop),
      });
      addTearDown(() {
        registration.dispose();
        registry.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: dark
              ? buildHermesDarkTheme(platform: TargetPlatform.linux)
              : buildHermesLightTheme(platform: TargetPlatform.linux),
          home: Builder(
            builder: (context) => Scaffold(
              body: DesktopMenuBar(menus: desktopMenus(registry, context.l10n)),
            ),
          ),
        ),
      );

      void expectOneRingOn(Finder box) {
        expect(_ringFinder, findsOneWidget);
        final ring = _ringFinder.evaluate().single;
        final painter =
            (ring.widget as CustomPaint).foregroundPainter! as FocusRingPainter;
        expect(painter.radius, 4);
        expect(painter.inset, 2);
        // The ring is the control's own box, drawn 2 px inside it.
        expect(tester.getRect(_ringFinder), tester.getRect(box));
      }

      // Tab reaches File, as a keyboard user enters the bar.
      // A click opens File (the bar takes no Tab stop of its own, so a
      // keyboard user enters it through a menu or an accelerator); the next
      // key press is the keyboard, and ArrowRight moves to View.
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expectOneRingOn(find.byType(SubmenuButton).at(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expectOneRingOn(find.byType(SubmenuButton).first);

      // ArrowDown walks into File's menu: the ring moves to the item and the
      // top-level button gives its ring up.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!.context!;
      final item = focused.findAncestorWidgetOfExactType<MenuItemButton>();
      expect(item, isNotNull, reason: 'focus is on a menu item');
      expectOneRingOn(find.byWidget(item!));
    });
  }
}
