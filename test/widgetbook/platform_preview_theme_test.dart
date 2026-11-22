import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_segmented_control.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../widgetbook/directories.dart';
import '../../widgetbook/environment.dart';
import '../../widgetbook/frame.dart';
import '../support/test_localizations.dart';

/// A platform preview of the catalog must carry the app theme built for that
/// platform: Mac, Windows and Linux shrink-wrap their tap targets and use
/// compact density, iPhone and Android pad them. Under `flutter test` the base
/// theme is built for Android, so a theme copied onto another platform kept
/// the phone sizing.
typedef _Sizing = ({MaterialTapTargetSize tapTarget, VisualDensity density});

_Sizing _sizing(BuildContext context) {
  final theme = Theme.of(context);
  return (tapTarget: theme.materialTapTargetSize, density: theme.visualDensity);
}

WidgetbookUseCase? _find(Iterable<WidgetbookNode> nodes, String name) {
  for (final node in nodes) {
    if (node is WidgetbookUseCase) {
      if (node.name == name) return node;
    } else {
      final found = _find(node.children ?? const [], name);
      if (found != null) return found;
    }
  }
  return null;
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData base,
  WidgetBuilder builder,
) async {
  tester.view
    ..physicalSize = const Size(1000, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      theme: base,
      home: Scaffold(body: Builder(builder: builder)),
    ),
  );
}

void main() {
  for (final MapEntry(key: mode, value: base) in themes.entries) {
    group('onEachPlatform, $mode', () {
      for (final (label, shrinkWrap) in [
        ('iPhone', false),
        ('Mac', true),
        ('Material', false),
      ]) {
        testWidgets('$label gets its own tap-target size and density', (
          tester,
        ) async {
          _Sizing? seen;
          Brightness? brightness;
          final useCase = onEachPlatform('State', (context) {
            seen = _sizing(context);
            brightness = Theme.of(context).brightness;
            return const SizedBox();
          }).singleWhere((u) => u.name == 'State ($label)');
          await _pump(tester, base, useCase.builder);

          expect(brightness, base.brightness);
          expect(
            seen?.tapTarget,
            shrinkWrap
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
          );
          expect(
            seen?.density,
            shrinkWrap ? VisualDensity.compact : VisualDensity.standard,
          );
        });
      }
    });
  }

  group('AdaptiveSegmentedControl platform switches', () {
    // The hit-area band of the use case is as high as the control's tap area
    // on that platform.
    for (final (name, platform, shrinkWrap, hit) in [
      ('iPhone', TargetPlatform.iOS, false, 44.0),
      ('Mac', TargetPlatform.macOS, true, 28.0),
      ('Android', TargetPlatform.android, false, 48.0),
      ('Windows', TargetPlatform.windows, true, 48.0),
      ('Linux', TargetPlatform.linux, true, 48.0),
    ]) {
      testWidgets('$name: tap-target size, density and band height', (
        tester,
      ) async {
        final useCase = _find(directories, '$name, Text selected')!;
        await _pump(tester, themes['Light']!, useCase.builder);

        final control = find.byType(AdaptiveSegmentedControl<bool>);
        final theme = Theme.of(tester.element(control));
        expect(theme.platform, platform);
        expect(
          theme.materialTapTargetSize,
          shrinkWrap
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
        );
        expect(
          theme.visualDensity,
          shrinkWrap ? VisualDensity.compact : VisualDensity.standard,
        );
        final band = find.ancestor(
          of: control,
          matching: find.byType(ColoredBox),
        );
        expect(tester.getSize(band.first).height, hit);
      });
    }
  });
}
