import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

double _luminanceContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool dark = false,
}) => MaterialApp(
  theme: (dark ? buildHermesDarkTheme() : buildHermesLightTheme()).copyWith(
    platform: platform,
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('presses call back and the label is the accessible name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        DestructiveTintButton(label: 'Stop agent', onPressed: () => taps++),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Stop agent')),
      isSemantics(
        label: 'Stop agent',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Stop agent'));
    expect(taps, 1);
    tester.semantics.tap(find.semantics.byLabel('Stop agent'));
    expect(taps, 2);
    handle.dispose();
  });

  testWidgets('is tinted and outlined, never filled', (tester) async {
    await tester.pumpWidget(
      _host(DestructiveTintButton(label: 'Stop', onPressed: () {})),
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    final context = tester.element(find.byType(OutlinedButton));
    final style = tester
        .widget<OutlinedButton>(find.byType(OutlinedButton))
        .style!;
    final background = style.backgroundColor!.resolve({})!;
    final error = Theme.of(context).colorScheme.error;
    expect(background.a, lessThan(0.2));
    expect(background.toARGB32() & 0xFFFFFF, error.toARGB32() & 0xFFFFFF);
    expect(style.foregroundColor!.resolve({}), error);
  });

  for (final dark in [false, true]) {
    testWidgets('its label meets AA on its tint (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          DestructiveTintButton(label: 'Stop', onPressed: () {}),
          dark: dark,
        ),
      );
      final context = tester.element(find.byType(OutlinedButton));
      final scheme = Theme.of(context).colorScheme;
      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      final tint = style.backgroundColor!.resolve({})!;
      final label = style.foregroundColor!.resolve({})!;
      for (final surface in [scheme.surface, scaffoldColor(context)]) {
        for (final state in [
          <WidgetState>{},
          {WidgetState.hovered},
          {WidgetState.focused},
          {WidgetState.pressed},
        ]) {
          final overlay = style.overlayColor!.resolve(state)!;
          final shown = Color.alphaBlend(
            overlay,
            Color.alphaBlend(tint, surface),
          );
          expect(
            _luminanceContrast(label, shown),
            greaterThanOrEqualTo(4.5),
            reason: 'on $surface, $state',
          );
        }
      }
    });
  }

  testWidgets('targets are 44 pt on iOS, 48 dp on Material, 28 pt on a Mac', (
    tester,
  ) async {
    for (final (platform, height) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      await tester.pumpWidget(
        _host(
          DestructiveTintButton(label: 'Stop', onPressed: () {}),
          platform: platform,
        ),
      );
      // The theme change animates; the platform flips at its midpoint.
      await tester.pumpAndSettle();
      final shown = tester.getSize(find.byType(OutlinedButton)).height;
      expect(shown, greaterThanOrEqualTo(height), reason: '$platform');
      expect(shown, lessThanOrEqualTo(height + 4), reason: '$platform');
    }
  });

  testWidgets('a compact desktop theme does not shrink the Mac target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(
          platform: TargetPlatform.macOS,
          visualDensity: VisualDensity.compact,
        ),
        home: Scaffold(
          body: Center(
            child: DestructiveTintButton(label: 'Stop', onPressed: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(28),
    );
  });

  testWidgets('disabled does not call back and is not an enabled button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const DestructiveTintButton(label: 'Stop', onPressed: null)),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Stop')),
      isSemantics(label: 'Stop', isButton: true, isEnabled: false),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    handle.dispose();
  });

  testWidgets('busy shows a spinner and ignores presses', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        DestructiveTintButton(
          label: 'Stopping',
          onPressed: () => taps++,
          busy: true,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Stopping'), findsOneWidget);
    await tester.tap(find.text('Stopping'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('shows its icon and wraps a long label at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 200,
            child: DestructiveTintButton(
              label: 'Stop this running agent now',
              icon: AppIcons.stop,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Icon), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThan(70));
  });

  testWidgets('keeps 28 pt on a Mac whose theme sets compact density', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(
          platform: TargetPlatform.macOS,
          visualDensity: VisualDensity.compact,
        ),
        home: Scaffold(
          body: Center(
            child: DestructiveTintButton(label: 'Stop agent', onPressed: () {}),
          ),
        ),
      ),
    );
    final box = tester.getSize(find.byType(DestructiveTintButton));
    expect(box.height, greaterThanOrEqualTo(28));
  });
}

Color scaffoldColor(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;
