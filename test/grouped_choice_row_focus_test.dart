import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Future<Color> _fillAt(WidgetTester tester, Finder boundary) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final color = await tester.runAsync(() async {
    final image = await render.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    // A point in the row's left padding, clear of text and the radio.
    final x = 4;
    final y = image.height ~/ 2;
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  });
  return color!;
}

void main() {
  testWidgets('a focused popover choice row has the fill a focused Settings '
      'row has, not a second tint', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final radioNode = FocusNode();
    final settingsNode = FocusNode();
    addTearDown(radioNode.dispose);
    addTearDown(settingsNode.dispose);
    tester.view
      ..physicalSize = const Size(400, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Column(
            children: [
              RepaintBoundary(
                key: const Key('choice'),
                child: RadioGroup<int>(
                  groupValue: 1,
                  onChanged: (_) {},
                  child: GroupedChoiceRow<int>(
                    value: 1,
                    title: 'model',
                    rowFocusable: false,
                    focusNode: radioNode,
                  ),
                ),
              ),
              RepaintBoundary(
                key: const Key('settings'),
                child: Focus(
                  focusNode: settingsNode,
                  child: GroupedRow(title: 'setting', onTap: () {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    radioNode.requestFocus();
    await tester.pumpAndSettle();
    final choice = await _fillAt(tester, find.byKey(const Key('choice')));
    radioNode.unfocus();
    await tester.pumpAndSettle();
    final resting = await _fillAt(tester, find.byKey(const Key('choice')));

    // The Settings row, focused through its own tap target.
    Focus.of(tester.element(find.text('setting'))).requestFocus();
    await tester.pumpAndSettle();
    final settings = await _fillAt(tester, find.byKey(const Key('settings')));

    expect(choice, isNot(resting), reason: 'the focused row is highlighted');
    expect(choice, settings);
  });
}
