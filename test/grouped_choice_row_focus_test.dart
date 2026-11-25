import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoRadio;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

/// The colour at [x] in the middle of [boundary]: 4 is the row's left padding,
/// clear of text and the radio; 1 is on the row's own left edge, where an
/// outline is drawn. [y] defaults to the middle.
Future<Color> _fillAt(
  WidgetTester tester,
  Finder boundary, {
  int x = 4,
  int? y,
}) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final color = await tester.runAsync(() async {
    final image = await render.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final row = y ?? image.height ~/ 2;
    final i = (row * image.width + x) * 4;
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
    final theme = buildHermesLightTheme(platform: TargetPlatform.macOS);
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

  /// One choice row in a 400 x 400 Mac window, [rowFocusable] as a Settings
  /// row (true) or the model popover (false) passes it.
  Future<FocusNode> pumpRow(
    WidgetTester tester, {
    required bool rowFocusable,
    FocusHighlightStrategy strategy = FocusHighlightStrategy.alwaysTraditional,
  }) async {
    FocusManager.instance.highlightStrategy = strategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final node = FocusNode();
    addTearDown(node.dispose);
    tester.view
      ..physicalSize = const Size(400, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: const Key('choice'),
              child: RadioGroup<int>(
                groupValue: 1,
                onChanged: (_) {},
                child: GroupedChoiceRow<int>(
                  value: 1,
                  title: 'model',
                  rowFocusable: rowFocusable,
                  focusNode: node,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return node;
  }

  final choice = find.byKey(const Key('choice'));
  Color link(WidgetTester tester) =>
      Theme.of(tester.element(choice)).extension<HermesChatColors>()!.link;

  testWidgets('a focused choice row outside the popover keeps its fill and '
      'the radio keeps its focus ring, with no outline', (tester) async {
    final node = await pumpRow(tester, rowFocusable: true);
    final resting = await _fillAt(tester, choice);

    node.requestFocus();
    await tester.pumpAndSettle();

    expect(
      await _fillAt(tester, choice),
      isNot(resting),
      reason: 'the InkWell focus fill',
    );
    expect(
      await _fillAt(tester, choice, x: 1),
      isNot(link(tester)),
      reason: 'no outline',
    );
    final radio = tester.widget<CupertinoRadio<int>>(
      find.byType(CupertinoRadio<int>),
    );
    expect(
      radio.focusColor,
      isNot(Colors.transparent),
      reason: "the radio's own focus ring stays",
    );
  });

  testWidgets('the popover row hides the radio focus ring, it draws the '
      'outline instead', (tester) async {
    await pumpRow(tester, rowFocusable: false);

    final radio = tester.widget<CupertinoRadio<int>>(
      find.byType(CupertinoRadio<int>),
    );
    expect(radio.focusColor, Colors.transparent);
  });

  testWidgets('the outline is for keyboard focus only', (tester) async {
    final node = await pumpRow(
      tester,
      rowFocusable: false,
      strategy: FocusHighlightStrategy.alwaysTouch,
    );
    final resting = await _fillAt(tester, choice, x: 1);

    node.requestFocus();
    await tester.pumpAndSettle();

    expect(node.hasFocus, isTrue);
    expect(await _fillAt(tester, choice, x: 1), resting);
    expect(await _fillAt(tester, choice, x: 1), isNot(link(tester)));
  });

  testWidgets('the outline has a radius of 10', (tester) async {
    final node = await pumpRow(tester, rowFocusable: false);
    node.requestFocus();
    await tester.pumpAndSettle();
    final color = link(tester);

    // Along the top edge the outline is straight.
    expect(await _fillAt(tester, choice, x: 100, y: 0), color);
    // The corner pixel is outside a radius of 10 and inside a radius of 4.
    expect(await _fillAt(tester, choice, x: 1, y: 1), isNot(color));
    // The 45 degree point of a radius of 10 is on the stroke; for a smaller
    // radius it is inside the shape.
    expect(await _fillAt(tester, choice, x: 3, y: 3), color);
  });
}
