import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/named_popup_menu_button.dart';

Future<List<String>> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  AdaptiveMenuController? controller,
}) async {
  final picked = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      home: Scaffold(
        body: Center(
          child: NamedPopupMenuButton<String>(
            controller: controller,
            label: 'Chat actions',
            icon: AppIcons.more,
            onSelected: picked.add,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'pin',
                checked: true,
                child: Text('Pin'),
              ),
              PopupMenuItem(value: 'off', enabled: false, child: Text('Off')),
            ],
          ),
        ),
      ),
    ),
  );
  return picked;
}

void main() {
  testWidgets('iOS opens a pull-down menu and answers the pick', (
    tester,
  ) async {
    final picked = await _pump(tester, TargetPlatform.iOS);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoMenuItem), findsNWidgets(3));
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(picked, ['rename']);
    expect(find.byType(CupertinoMenuItem), findsNothing);
  });

  testWidgets('iOS opens from the controller', (tester) async {
    final controller = AdaptiveMenuController();
    await _pump(tester, TargetPlatform.iOS, controller: controller);
    controller.open();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoMenuItem), findsNWidgets(3));
  });

  testWidgets('macOS menus are compact', (tester) async {
    final picked = await _pump(tester, TargetPlatform.macOS);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoMenuItem), findsNothing);
    expect(
      tester
          .getSize(find.widgetWithText(PopupMenuItem<String>, 'Rename'))
          .height,
      AdaptivePopupMenuButton.macRowHeight,
    );
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(picked, ['rename']);
  });

  testWidgets('Android keeps the 48 pixel Material menu', (tester) async {
    await _pump(tester, TargetPlatform.android);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoMenuItem), findsNothing);
    expect(
      tester
          .getSize(find.widgetWithText(PopupMenuItem<String>, 'Rename'))
          .height,
      kMinInteractiveDimension,
    );
  });

  testWidgets('a right-click on a row opens its menu on macOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ContextMenuRow(
            builder: (context, menu) => ListTile(
              title: const Text('Board'),
              trailing: AdaptivePopupMenuButton<String>(
                controller: menu,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Board'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
  });

  group('Mac menu rows', () {
    Future<List<String>> pumpMac(
      WidgetTester tester, {
      AdaptiveMenuController? controller,
      TargetPlatform platform = TargetPlatform.macOS,
    }) async {
      final picked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AdaptivePopupMenuButton<String>(
                controller: controller,
                onSelected: picked.add,
                itemBuilder: (_) => const [
                  AdaptiveMenuItem(
                    value: 'pin',
                    shortcut: '⇧⌘P',
                    child: Text('Pin'),
                  ),
                  PopupMenuDivider(),
                  AdaptiveMenuItem(
                    value: 'delete',
                    shortcut: '⌘⌫',
                    destructive: true,
                    child: Text('Delete…'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    testWidgets('are 22pt tall with the shortcut on the right', (tester) async {
      await pumpMac(tester);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(AdaptivePopupMenuButton.macRowHeight, 22);
      final pin = find.widgetWithText(PopupMenuItem<String>, 'Pin');
      expect(tester.getSize(pin).height, 22);
      expect(
        tester.getTopRight(find.text('⇧⌘P')).dx,
        greaterThan(tester.getTopRight(find.text('Pin')).dx),
      );
    });

    testWidgets('paint a destructive item in the error colour', (tester) async {
      await pumpMac(tester);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final error = Theme.of(tester.element(find.text('Pin')))
          .colorScheme
          .error;
      final style = DefaultTextStyle.of(tester.element(find.text('Delete…')));
      expect(style.style.color, error);
    });

    testWidgets('a two-line item takes its own height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: AdaptivePopupMenuButton<String>(
              itemBuilder: (_) => const [
                AdaptiveMenuItem(
                  value: 'work',
                  macHeight: 36,
                  child: Text('Work'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.widgetWithText(PopupMenuItem<String>, 'Work'))
            .height,
        36,
      );
    });

    testWidgets('open at a point puts the menu there', (tester) async {
      final controller = AdaptiveMenuController();
      final picked = await pumpMac(tester, controller: controller);
      controller.open(at: const Offset(300, 200));
      await tester.pumpAndSettle();

      final pin = tester.getTopLeft(find.text('Pin'));
      expect(pin.dx, greaterThan(300));
      expect(pin.dy, greaterThan(200));
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(picked, ['pin']);
    });

    testWidgets('Material leaves the Mac shortcut out', (tester) async {
      await pumpMac(tester, platform: TargetPlatform.android);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Delete…'), findsOneWidget);
      expect(find.text('⌘⌫'), findsNothing);
    });
  });
}
