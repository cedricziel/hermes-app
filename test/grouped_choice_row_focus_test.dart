import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

/// The colour at [x] in the middle of [boundary]: 4 is the row's left padding,
/// clear of text and the radio; 1 is on the row's own left edge, where an
/// outline is drawn.
Future<Color> _fillAt(WidgetTester tester, Finder boundary, {int x = 4}) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final color = await tester.runAsync(() async {
    final image = await render.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
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
  testWidgets('a focused popover choice row draws a 2 px outline in the link '
      'colour and no grey fill; a focused Settings row keeps its fill', (
    tester,
  ) async {
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
    final theme = buildHermesLightTheme().copyWith(
      platform: TargetPlatform.macOS,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
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
    final link = theme.extension<HermesChatColors>()!.link;
    Finder choice() => find.byKey(const Key('choice'));
    Finder settings() => find.byKey(const Key('settings'));

    final choiceResting = await _fillAt(tester, choice());
    final settingsResting = await _fillAt(tester, settings());

    radioNode.requestFocus();
    await tester.pumpAndSettle();
    expect(
      await _fillAt(tester, choice(), x: 1),
      link,
      reason: 'the outline is drawn on the focused popover row',
    );
    expect(
      await _fillAt(tester, choice()),
      choiceResting,
      reason: 'no grey fill inside the outline',
    );

    radioNode.unfocus();
    await tester.pumpAndSettle();
    expect(await _fillAt(tester, choice(), x: 1), choiceResting);

    // The Settings row, focused through its own tap target.
    Focus.of(tester.element(find.text('setting'))).requestFocus();
    await tester.pumpAndSettle();
    expect(
      await _fillAt(tester, settings()),
      isNot(settingsResting),
      reason: 'a Settings row keeps its focus fill',
    );
    expect(
      await _fillAt(tester, settings(), x: 1),
      isNot(link),
      reason: 'and gets no outline',
    );
  });
}
