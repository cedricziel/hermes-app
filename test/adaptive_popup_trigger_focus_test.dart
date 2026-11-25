import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/popup_trigger_callers.dart';
import 'support/test_localizations.dart';

/// The iOS pull-down trigger of [AdaptivePopupMenuButton] with a custom child
/// (F.441): reachable by the keyboard, one tab stop, Enter and Space open the
/// menu, focus returns to the trigger when the menu closes, and a tap in the margin of the chip
/// toggles like a tap on the chip.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    resetFocusRingInput();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Future<void> pump(
    WidgetTester tester,
    Widget body, {
    TargetPlatform platform = TargetPlatform.iOS,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(platform: platform),
        builder: (context, child) => AppThemeScopes(
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(padding: const EdgeInsets.all(24), child: body),
          ),
        ),
      ),
    );
  }

  /// The focus nodes a Tab can reach inside [popup].
  List<FocusNode> tabStops(WidgetTester tester, Finder popup) {
    final owner = tester.element(popup);
    return [
      for (final node in FocusManager.instance.rootScope.traversalDescendants)
        if (_inside(node, owner)) node,
    ];
  }

  final menuItems = find.byType(CupertinoMenuItem);

  group('keyboard', () {
    for (final caller in popupCallers) {
      group(caller.name, () {
        testWidgets('is exactly one tab stop', (tester) async {
          await pump(tester, caller.build());
          expect(tabStops(tester, caller.popup), hasLength(1));
        });

        testWidgets('Tab reaches it, Enter opens the menu', (tester) async {
          await pump(tester, caller.build());
          for (var i = 0; i < 8; i++) {
            if (tabStops(tester, caller.popup).any((n) => n.hasFocus)) break;
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(tabStops(tester, caller.popup).single.hasFocus, isTrue);
          expect(menuItems, findsNothing);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(menuItems, findsWidgets);
        });

        testWidgets('Space opens the menu', (tester) async {
          await pump(tester, caller.build());
          tabStops(tester, caller.popup).single.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(menuItems, findsWidgets);
        });

        testWidgets('focus is on the trigger again when the menu closes', (
          tester,
        ) async {
          await pump(tester, caller.build());
          final trigger = tabStops(tester, caller.popup).single..requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(menuItems, findsWidgets);
          expect(trigger.hasPrimaryFocus, isFalse, reason: 'the menu has it');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(menuItems, findsNothing);
          expect(trigger.hasPrimaryFocus, isTrue);
        });

        testWidgets('a pointer tap opens it, closes it, and draws no ring', (
          tester,
        ) async {
          await pump(tester, caller.build());
          final trigger = tabStops(tester, caller.popup).single;
          await tester.tap(caller.popup);
          await tester.pumpAndSettle();
          expect(menuItems, findsWidgets);
          await tester.tap(caller.popup);
          await tester.pumpAndSettle();
          expect(menuItems, findsNothing);
          expect(trigger.hasPrimaryFocus, isTrue, reason: 'the tap focused it');
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint && w.foregroundPainter is FocusRingPainter,
            ),
            findsNothing,
          );
        });

        testWidgets('is one button that reads the child', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, caller.build());
          final area = tester.getRect(caller.popup);
          final buttons = <SemanticsNode>[];
          void walk(SemanticsNode node) {
            if (node.getSemanticsData().flagsCollection.isButton &&
                !node.isInvisible &&
                !node.isMergedIntoParent &&
                _globalRect(node).overlaps(area)) {
              buttons.add(node);
            }
            node.visitChildren((child) {
              walk(child);
              return true;
            });
          }

          walk(
            tester
                .binding
                .renderViews
                .first
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          expect(buttons, hasLength(1));
          expect(
            buttons.single.getSemanticsData().label,
            contains(caller.text),
          );
          handle.dispose();
        });
      });
    }
  });

  group('kanban filter chip: the 44 pt hit box', () {
    final chip = popupCallers.singleWhere((c) => c.chip);

    Rect hitBox(WidgetTester tester) => tester.getRect(
      find
          .descendant(of: chip.popup, matching: find.byType(GestureDetector))
          .first,
    );

    for (final scale in [1.0, 3.0]) {
      testWidgets('is at least 44 square at text ${scale}x', (tester) async {
        await pump(tester, chip.build(), textScale: scale);
        final box = hitBox(tester);
        expect(box.width, greaterThanOrEqualTo(44));
        expect(box.height, greaterThanOrEqualTo(44));
      });
    }

    testWidgets('a tap on the chip opens the menu once', (tester) async {
      await pump(tester, chip.build());
      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();
      expect(menuItems, findsNWidgets(3));
    });

    testWidgets('a tap on the margin, menu closed, opens it once', (
      tester,
    ) async {
      await pump(tester, chip.build());
      final box = hitBox(tester);
      final painted = tester.getRect(
        find
            .descendant(of: find.byType(Chip), matching: find.byType(Material))
            .first,
      );
      expect(box.top, lessThan(painted.top), reason: 'there is a margin');
      await tester.tapAt(Offset(box.center.dx, box.top + 1));
      await tester.pumpAndSettle();
      expect(menuItems, findsNWidgets(3));
    });

    testWidgets('a tap on the margin, menu open, closes it and not again', (
      tester,
    ) async {
      await pump(tester, chip.build());
      final box = hitBox(tester);
      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();
      expect(menuItems, findsNWidgets(3));
      await tester.tapAt(Offset(box.center.dx, box.top + 1));
      await tester.pumpAndSettle();
      expect(menuItems, findsNothing);
    });
  });

  group('what stays as it was', () {
    testWidgets('Android keeps its padded chip and its Material menu', (
      tester,
    ) async {
      final chip = popupCallers.singleWhere((c) => c.chip);
      await pump(tester, chip.build(), platform: TargetPlatform.android);
      expect(find.byType(CupertinoMenuAnchor), findsNothing);
      expect(find.byType(PopupMenuButton<({String? option})>), findsOneWidget);
      expect(tester.getSize(find.byType(Chip)).height, 48);
    });

    for (final caller in popupCallers.where((c) => !c.chip)) {
      testWidgets('${caller.name} keeps the size of its child', (tester) async {
        await pump(tester, caller.build());
        final trigger = find
            .descendant(
              of: caller.popup,
              matching: find.byType(GestureDetector),
            )
            .first;
        final child = caller.child;
        expect(
          tester.getSize(trigger),
          tester.getSize(child),
          reason: 'no hit box was added round it',
        );
      });
    }

    testWidgets('the pill at 3x text is still one tab stop', (tester) async {
      final pill = popupCallers.first;
      await pump(tester, pill.build(), textScale: 3);
      expect(tabStops(tester, pill.popup), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Quick Look anchor on a Mac takes no focus', (
      tester,
    ) async {
      await pump(
        tester,
        QuickLookTarget(
          onOpen: () {},
          onToggle: () {},
          child: const SizedBox(width: 100, height: 48),
        ),
        platform: TargetPlatform.macOS,
      );
      final anchor = find.byWidgetPredicate(
        (w) => w is AdaptivePopupMenuButton<void>,
      );
      expect(anchor, findsOneWidget);
      expect(tabStops(tester, anchor), isEmpty);
    });

    testWidgets('an ExcludeFocus anchor on iOS takes no focus', (tester) async {
      await pump(
        tester,
        ExcludeFocus(
          child: AdaptivePopupMenuButton<void>(
            tooltip: '',
            itemBuilder: (_) => const [
              PopupMenuItem<void>(child: Text('Open')),
            ],
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(
        FocusManager.instance.rootScope.traversalDescendants.where(
          (n) => n is! FocusScopeNode,
        ),
        isEmpty,
      );
    });
  });
}

bool _inside(FocusNode node, Element owner) {
  var inside = false;
  node.context?.visitAncestorElements((e) {
    inside = identical(e, owner);
    return !inside;
  });
  return inside;
}

Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    final t = n.transform;
    if (t != null) rect = MatrixUtils.transformRect(t, rect);
  }
  return rect;
}
