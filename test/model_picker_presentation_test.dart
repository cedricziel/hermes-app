import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/anchored_popover.dart';

const _options = ModelOptions(
  providers: [
    ModelProviderOption(
      id: 'acme',
      label: 'Acme',
      models: [
        ModelOption(id: 'atlas-1'),
        ModelOption(id: 'atlas-mini', reasoning: false),
      ],
    ),
  ],
);

final _openerFocus = FocusNode();

class _Opened {
  final picked = <ModelChoice>[];
}

/// Pumps a button that opens the picker, at [width] by [height]. With
/// [anchored] the button's own rectangle goes in as the anchor, the way the
/// composer's pill does.
Future<_Opened> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  double height = 900,
  bool anchored = true,
  bool withEffort = false,
  ModelChoice? selected,
  Alignment align = Alignment.bottomLeft,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      home: Scaffold(
        body: Align(
          alignment: align,
          child: Builder(
            builder: (context) => TextButton(
              key: const Key('opener'),
              focusNode: _openerFocus,
              onPressed: () {
                final box = context.findRenderObject()! as RenderBox;
                showModelPicker(
                  context,
                  options: _options,
                  selected: selected,
                  onChanged: opened.picked.add,
                  withEffort: withEffort,
                  anchor: anchored
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  return opened;
}

Future<void> _open(WidgetTester tester) async {
  _openerFocus.requestFocus();
  await tester.pump();
  await tester.tap(find.byKey(const Key('opener')));
  await tester.pumpAndSettle();
}

final _popover = find.byWidgetPredicate(
  (widget) =>
      widget is ModelPicker &&
      widget.presentation == ModelPickerPresentation.popover,
);

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    for (final width in [700.0, 800.0, 1200.0]) {
      group('${platform.name} at $width pt', () {
        testWidgets('with an anchor it is a popover, not a sheet or dialog', (
          tester,
        ) async {
          await _pump(tester, platform: platform, width: width);
          await _open(tester);

          expect(_popover, findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.byType(Dialog), findsNothing);
        });

        testWidgets('without an anchor it is the dialog', (tester) async {
          await _pump(
            tester,
            platform: platform,
            width: width,
            anchored: false,
          );
          await _open(tester);

          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          expect(_popover, findsNothing);
        });
      });
    }

    group('${platform.name} popover', () {
      testWidgets('sits 6 pt above the pill, left edges aligned', (
        tester,
      ) async {
        await _pump(
          tester,
          platform: platform,
          width: 1000,
          align: const Alignment(-0.2, 1),
        );
        final pill = tester.getRect(find.byKey(const Key('opener')));
        await _open(tester);

        final surface = tester.getRect(
          find.ancestor(of: _popover, matching: find.byType(Material)).first,
        );
        expect(surface.bottom, closeTo(pill.top - 6, 0.5));
        expect(surface.left, closeTo(pill.left, 0.5));
        expect(surface.width, closeTo(360, 0.01));
      });

      testWidgets('flips below when there is under 240 pt above', (
        tester,
      ) async {
        await _pump(
          tester,
          platform: platform,
          width: 1000,
          align: Alignment.topLeft,
        );
        final pill = tester.getRect(find.byKey(const Key('opener')));
        await _open(tester);

        final surface = tester.getRect(
          find.ancestor(of: _popover, matching: find.byType(Material)).first,
        );
        expect(surface.top, closeTo(pill.bottom + 6, 0.5));
      });

      testWidgets('Escape closes it and focus returns to the pill', (
        tester,
      ) async {
        await _pump(tester, platform: platform, width: 800);
        await _open(tester);
        expect(_popover, findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(_popover, findsNothing);
        expect(_openerFocus.hasPrimaryFocus, isTrue);
      });

      testWidgets('a click outside closes it with no pick', (tester) async {
        final opened = await _pump(tester, platform: platform, width: 800);
        await _open(tester);

        await tester.tapAt(const Offset(700, 20));
        await tester.pumpAndSettle();

        expect(_popover, findsNothing);
        expect(opened.picked, isEmpty);
      });

      testWidgets('choosing a row sets the pick and closes it without effort', (
        tester,
      ) async {
        final opened = await _pump(tester, platform: platform, width: 800);
        await _open(tester);

        await tester.tap(find.text('atlas-mini'));
        await tester.pumpAndSettle();

        expect(opened.picked, [const ModelChoice('acme', 'atlas-mini')]);
        expect(_popover, findsNothing);
      });

      testWidgets('a model with efforts keeps it open', (tester) async {
        final opened = await _pump(
          tester,
          platform: platform,
          width: 800,
          withEffort: true,
        );
        await _open(tester);

        await tester.tap(find.text('atlas-1'));
        await tester.pumpAndSettle();

        expect(opened.picked, [const ModelChoice('acme', 'atlas-1')]);
        expect(_popover, findsOneWidget);
        expect(find.byKey(const Key('effort-high')), findsOneWidget);
      });

      testWidgets('focus starts on the checked row; Return picks it', (
        tester,
      ) async {
        final opened = await _pump(
          tester,
          platform: platform,
          width: 800,
          selected: const ModelChoice('acme', 'atlas-mini'),
        );
        await _open(tester);

        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(
            of: find.byKey(const Key('model-acme-atlas-mini')),
            matching: find.byWidget(focused.widget),
          ),
          findsWidgets,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(opened.picked.last, const ModelChoice('acme', 'atlas-1'));
      });

      testWidgets('every row and effort pill is at least 28 pt tall', (
        tester,
      ) async {
        await _pump(
          tester,
          platform: platform,
          width: 800,
          withEffort: true,
          selected: const ModelChoice('acme', 'atlas-1'),
        );
        await _open(tester);

        for (final key in const [
          'model-acme-atlas-1',
          'model-acme-atlas-mini',
          'effort-low',
          'effort-high',
        ]) {
          expect(
            tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(28),
            reason: key,
          );
        }
      });
    });
  }

  group('iOS and Android', () {
    testWidgets(
      'iOS at phone width keeps the bottom sheet, with an anchor too',
      (tester) async {
        await _pump(tester, platform: TargetPlatform.iOS, width: 390);
        await _open(tester);

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(_popover, findsNothing);
      },
    );

    testWidgets('iOS at 1000 pt is the dialog', (tester) async {
      await _pump(tester, platform: TargetPlatform.iOS, width: 1000);
      await _open(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(_popover, findsNothing);
    });

    testWidgets('Android at phone width keeps the bottom sheet', (
      tester,
    ) async {
      await _pump(tester, platform: TargetPlatform.android, width: 390);
      await _open(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(_popover, findsNothing);
    });
  });

  group('layoutPopover', () {
    test('clamps to the window and limits the height to the room', () {
      final placed = layoutPopover(
        window: const Size(500, 600),
        anchor: const Rect.fromLTWH(400, 300, 80, 30),
        width: 360,
        maxHeight: 480,
        gap: 6,
        preferAbove: true,
        measure: (c) => c.maxHeight,
      );
      expect(placed.offset.dx, 132);
      expect(placed.constraints.maxHeight, 300 - 6 - 8 - 16);
    });
  });
}
