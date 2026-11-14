import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_sheet.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/widgets/adaptive_sheet.dart';

import 'support/screenshot_recorder.dart';

/// Where to write the PNGs of every case; unset writes none.
final _shots = Platform.environment['DIALOG_EDGE_SHOTS'];

/// WCAG 2.x relative luminance contrast ratio, (L1 + 0.05) / (L2 + 0.05).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The WCAG 1.4.11 minimum for the edge of a user interface component.
const _edgeContrast = 3.0;

/// The least a field outline or an unselected segment may differ from its
/// dialog's surface. The light theme's own outline on white is 1.28 and its
/// segment 1.10; a zinc800 control on a zinc800 dialog is 1.0.
const _fillContrast = 1.05;

const _options = ModelOptions(
  current: ModelChoice('acme', 'atlas-1'),
  providers: [
    ModelProviderOption(
      id: 'acme',
      label: 'Acme',
      models: [
        ModelOption(id: 'atlas-1', canDisableReasoning: true),
        ModelOption(id: 'atlas-mini'),
      ],
    ),
  ],
);

typedef _Open = Future<void> Function(BuildContext context);

final _cases = <String, _Open>{
  'confirm': (context) => showConfirmDialog(
    context,
    title: 'Restart the gateway?',
    message: 'Running chats stop and reconnect.',
    confirmLabel: 'Restart',
  ),
  'text-field': (context) => showAppDialog<void>(
    context: context,
    builder: (dialog) => AppAlertDialog(
      title: const Text('New board'),
      content: AppDialogTextField(
        controller: TextEditingController(),
        hint: 'Name',
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancel'),
        ),
        AppDialogAction(
          isDefault: true,
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Create'),
        ),
      ],
    ),
  ),
  'model-picker': (context) => showModelPicker(
    context,
    options: _options,
    selected: const ModelChoice('acme', 'atlas-1', effort: 'medium'),
    onChanged: (_) {},
  ),
  'date-picker': (context) => showDatePicker(
    context: context,
    initialDate: DateTime(2030, 5, 14),
    firstDate: DateTime(2030),
    lastDate: DateTime(2031),
  ),
  'time-picker': (context) => showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 30),
  ),
  'sheet': (context) => showAdaptiveSheet<void>(
    context,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(24),
      child: Text('A sheet with a question and nothing else around it.'),
    ),
  ),
};

class _Shot {
  _Shot(this.width, this.rgba);
  final int width;
  final ByteData rgba;

  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      255,
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
  }
}

/// Opens [name] under [theme] at [size] and measures what is drawn: the
/// backdrop under the scrim, the overlay's surface and its left edge.
Future<({Color scrim, Color surface, Color edge})> _measure(
  WidgetTester tester,
  String name,
  ThemeData theme,
  Size size,
  String label,
) async {
  final rec = ScreenshotRecorder('dialog-edge');
  await rec.start(tester, size);
  await tester.pumpWidget(
    rec.frame(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: withScreenshotFont(theme),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => _cases[name]!(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  final overlay = find
      .descendant(
        of: find.byWidgetPredicate((w) => w is Dialog || w is BottomSheet),
        matching: find.byType(Material),
      )
      .first;
  final rect = tester.getRect(overlay);
  final png = await rec.render(tester, pixelRatio: 1);
  if (_shots != null) {
    await tester.runAsync(() async {
      final file = File('$_shots/$label.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png);
    });
  }
  final shot = (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData())!;
    return _Shot(image.width, data);
  }))!;

  // The left edge at mid height: its x is whole where the top edge's y is
  // often half a pixel, which would split the 1 px border over two rows.
  final y = rect.center.dy.round();
  final left = rect.left.floor();
  var edge = shot.at(left, y);
  for (final x in [left - 1, left + 1]) {
    if (x < 0) continue;
    final c = shot.at(x, y);
    if (c.computeLuminance() > edge.computeLuminance()) edge = c;
  }
  return (scrim: shot.at(2, 2), surface: shot.at(left + 8, y), edge: edge);
}

void main() {
  final themes = {
    'dark': buildHermesDarkTheme(platform: TargetPlatform.android),
    'light': buildHermesLightTheme(platform: TargetPlatform.android),
  };
  final sizes = {'phone': phoneSize, 'desktop': desktopSize};

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    for (final MapEntry(key: device, value: size) in sizes.entries) {
      for (final name in _cases.keys) {
        testWidgets('$name stands out from the scrim ($mode, $device)', (
          tester,
        ) async {
          final m = await _measure(
            tester,
            name,
            theme,
            size,
            '$mode-$device-$name',
          );
          // Pixels as drawn: the backdrop under the scrim, the surface, and
          // the edge row. Either the edge or the surface must stand 3:1 off
          // the scrim, so the question has a visible boundary.
          final best = math.max(
            _contrast(m.edge, m.scrim),
            _contrast(m.surface, m.scrim),
          );
          expect(
            best,
            greaterThanOrEqualTo(_edgeContrast),
            reason:
                'scrim ${m.scrim}, surface ${m.surface}, edge ${m.edge}: '
                'edge ${_contrast(m.edge, m.scrim).toStringAsFixed(2)}:1, '
                'surface ${_contrast(m.surface, m.scrim).toStringAsFixed(2)}:1',
          );
        });
      }
    }
  }

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    testWidgets('the unfocused outline of AppDialogTextField differs from the '
        'dialog surface ($mode)', (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => _cases['text-field']!(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // The field is autofocused; look at the border a field shows idle.
      final context = tester.element(find.byType(AppDialogTextField));
      final border = Theme.of(context).inputDecorationTheme.border!;
      final outline = (border as OutlineInputBorder).borderSide.color;
      final surface = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(
        _contrast(outline, surface),
        greaterThanOrEqualTo(_fillContrast),
        reason: 'outline $outline on dialog $surface',
      );
    });

    testWidgets('unselected effort segments differ from the dialog surface '
        '($mode)', (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => _cases['model-picker']!(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      Color? colorOf(Finder f) => tester
          .widget<Material>(
            find.descendant(of: f, matching: find.byType(Material)).first,
          )
          .color;
      final surface = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      final unselected = colorOf(find.byKey(const Key('effort-high')))!;
      expect(
        _contrast(unselected, surface),
        greaterThanOrEqualTo(_fillContrast),
        reason: 'segment $unselected on dialog $surface',
      );
    });
  }

  testWidgets('the Kanban phone sheet, opened through its route, draws one '
      'edge in dark', (tester) async {
    final rec = ScreenshotRecorder('dialog-edge');
    await rec.start(tester, phoneSize);
    await tester.pumpWidget(
      rec.frame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withScreenshotFont(themes['dark']!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showKanbanDetentSheet(
                  context,
                  (controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: const [Text('Row one'), Text('Row two')],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const Key('kanbanTaskSheet')));
    final png = await rec.render(tester, pixelRatio: 1);
    if (_shots != null) {
      await tester.runAsync(() async {
        final file = File('$_shots/dark-phone-kanban-route-sheet.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
      });
    }
    final shot = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
      final image = (await codec.getNextFrame()).image;
      return _Shot(image.width, (await image.toByteData())!);
    }))!;
    final top = rect.top.round();
    final x = rect.center.dx.round();
    var edge = 0.0;
    for (final y in [top - 1, top, top + 1]) {
      edge = math.max(edge, shot.at(x, y).computeLuminance());
    }
    expect(
      edge,
      greaterThan(0.1),
      reason: 'the sheet draws its zinc500 edge along the top',
    );
    // A second edge from the theme's radius-28 shape would cross the corner
    // diagonal at 8 px in, inside the radius-12 sheet.
    for (final d in [6, 7, 8, 9, 10]) {
      final c = shot.at(d, top + d);
      expect(
        c.computeLuminance(),
        lessThan(0.05),
        reason: 'pixel $d,$d below the top-left corner is $c: a second edge',
      );
    }
  });

  testWidgets('GroupedDialog and the Kanban form sheet take the edge in '
      'dark', (tester) async {
    tester.view.physicalSize = desktopSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes['dark'],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const GroupedDialog(
                      title: 'Settings',
                      children: [Text('Row')],
                    ),
                  ),
                  child: const Text('grouped'),
                ),
                TextButton(
                  onPressed: () =>
                      showKanbanFormSheet(context, const Text('Form')),
                  child: const Text('form'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final label in ['grouped', 'form']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final shape = tester.widget<Dialog>(find.byType(Dialog)).shape!;
      expect(
        (shape as RoundedRectangleBorder).side.color,
        HermesColors.zinc500,
        reason: label,
      );
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();
    }
  });

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    testWidgets('lines inside the model picker and the platform hint sheet '
        'stay visible on the overlay surface ($mode)', (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => _cases['model-picker']!(context),
                    child: const Text('picker'),
                  ),
                  TextButton(
                    onPressed: () => showAdaptiveSheet<void>(
                      context,
                      builder: (_) => PlatformHintPrompt(
                        profiles: const ['alpha', 'beta'],
                        selected: const {'alpha'},
                        onToggle: (_, _) {},
                        text: 'A note',
                        onAdd: () {},
                        onLater: () {},
                        onNever: () {},
                      ),
                    ),
                    child: const Text('hint'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in ['picker', 'hint']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final dialog = find.byType(Dialog);
        final scheme = Theme.of(tester.element(dialog)).colorScheme;
        final surface = tester
            .widget<Material>(
              find
                  .descendant(of: dialog, matching: find.byType(Material))
                  .first,
            )
            .color!;
        final lines = <String, Color>{};
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: dialog, matching: find.byType(DecoratedBox)),
        )) {
          final d = box.decoration;
          if (d is! BoxDecoration || d.border is! Border) continue;
          final b = d.border! as Border;
          for (final side in [b.top, b.left]) {
            if (side.style == BorderStyle.solid) lines['box'] = side.color;
          }
        }
        // A GroupedSection fills with the scaffold colour, a darker well
        // its own dividers are drawn for; only lines on the overlay surface
        // are checked.
        for (final element in tester.elementList(
          find.descendant(of: dialog, matching: find.byType(Divider)),
        )) {
          if (element.findAncestorWidgetOfExactType<GroupedSection>() != null) {
            continue;
          }
          lines['divider'] =
              (element.widget as Divider).color ?? scheme.outline;
        }
        expect(lines, isNotEmpty, reason: label);
        for (final MapEntry(:key, :value) in lines.entries) {
          expect(
            _contrast(value, surface),
            greaterThanOrEqualTo(_fillContrast),
            reason: '$label $key line $value on $surface',
          );
        }
        Navigator.of(tester.element(dialog)).pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
