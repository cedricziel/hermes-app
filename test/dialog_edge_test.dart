import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
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
}
