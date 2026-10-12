import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final reduced in [false, true]) {
      for (final fullScreen in [false, true]) {
        testWidgets(
          'macOS dark=$dark reduced=$reduced fullscreen=$fullScreen motion and result',
          (tester) async {
            final navigator = GlobalKey<NavigatorState>();
            final theme = dark
                ? buildHermesDarkTheme(platform: TargetPlatform.macOS)
                : buildHermesLightTheme(platform: TargetPlatform.macOS);
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navigator,
                theme: theme,
                builder: (_, child) => MediaQuery(
                  data: MediaQueryData(disableAnimations: reduced),
                  child: child!,
                ),
                home: const Scaffold(body: Text('Root')),
              ),
            );
            final route = MaterialPageRoute<String>(
              fullscreenDialog: fullScreen,
              settings: const RouteSettings(
                name: '/detail',
                arguments: 'argument',
              ),
              builder: (_) => const Scaffold(body: Text('Detail')),
            );
            final result = navigator.currentState!.push(route);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));

            expect(tester.getTopLeft(find.text('Detail')).dx, 0);
            expect(
              route.transitionDuration.inMilliseconds,
              lessThanOrEqualTo(180),
            );
            expect(route.settings.name, '/detail');
            expect(route.settings.arguments, 'argument');
            final fades = tester.widgetList<FadeTransition>(
              find.ancestor(
                of: find.text('Detail'),
                matching: find.byType(FadeTransition),
              ),
            );
            if (reduced) {
              expect(fades, isEmpty);
            } else {
              expect(fades, isNotEmpty);
              expect(
                fades.first.opacity.value,
                allOf(greaterThan(0), lessThan(1)),
              );
            }
            await tester.pumpAndSettle();
            navigator.currentState!.pop('saved');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));
            expect(tester.getTopLeft(find.text('Detail')).dx, 0);
            await tester.pumpAndSettle();
            expect(await result, 'saved');
            expect(find.text('Root'), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('rapid Back leaves a valid root and completes the result', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: const Scaffold(body: Text('Root')),
      ),
    );
    final result = navigator.currentState!.push(
      MaterialPageRoute<String>(
        builder: (_) => const Scaffold(body: Text('Detail')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    navigator.currentState!.pop('cancelled');
    await tester.pumpAndSettle();
    expect(await result, 'cancelled');
    expect(find.text('Detail'), findsNothing);
    expect(find.text('Root'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  test('mobile Back builders remain the SDK defaults in both themes', () {
    final defaults = const PageTransitionsTheme().builders;
    for (final theme in [buildHermesLightTheme(), buildHermesDarkTheme()]) {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          theme.pageTransitionsTheme.builders[platform],
          defaults[platform],
        );
      }
    }
  });
}
