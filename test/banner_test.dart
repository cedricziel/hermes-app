import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/banner.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? buildHermesLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows title, detail and action', (tester) async {
    await tester.pumpWidget(
      _host(
        Banner(
          tone: BannerTone.neutral,
          title: 'Working folder',
          detail: 'Of the server.',
          action: TextButton(onPressed: () {}, child: const Text('Show')),
        ),
      ),
    );
    expect(find.text('Working folder'), findsOneWidget);
    expect(find.text('Of the server.'), findsOneWidget);
    expect(find.text('Show'), findsOneWidget);
  });

  testWidgets('uses the default icon of its tone', (tester) async {
    final icons = {for (final t in BannerTone.values) Banner.defaultIcon(t)};
    expect(icons.length, BannerTone.values.length);
    await tester.pumpWidget(
      _host(const Banner(tone: BannerTone.warning, title: 'Careful')),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, AppIcons.warning.material);
  });

  testWidgets('announces title and detail as one live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Banner(
          tone: BannerTone.error,
          title: "Couldn't save",
          detail: 'Try again.',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(Banner)),
      isSemantics(label: "Couldn't save. Try again.", isLiveRegion: true),
    );
    expect(find.bySemanticsLabel("Couldn't save"), findsNothing);
    handle.dispose();
  });

  testWidgets('the action keeps its own tappable node', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Banner(
          tone: BannerTone.neutral,
          title: 'Offline',
          action: TextButton(
            onPressed: () => taps++,
            child: const Text('Retry'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('the action sits beside the text, and below it at large text', (
    tester,
  ) async {
    Widget build(double scale) => _host(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Banner(
          tone: BannerTone.warning,
          title: 'Title',
          action: TextButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ),
    );
    await tester.pumpWidget(build(1));
    expect(
      tester.getTopLeft(find.text('Retry')).dy,
      lessThan(tester.getBottomLeft(find.text('Title')).dy),
    );
    await tester.pumpWidget(build(2));
    expect(
      tester.getTopLeft(find.text('Retry')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text('Title')).dy),
    );
  });

  testWidgets('every tone builds in both themes', (tester) async {
    for (final theme in [buildHermesLightTheme(), buildHermesDarkTheme()]) {
      for (final tone in BannerTone.values) {
        await tester.pumpWidget(
          _host(
            Banner(tone: tone, title: 'T', detail: 'D'),
            theme: theme,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
