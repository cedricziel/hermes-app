import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
            icon: Icons.more_horiz,
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
}
