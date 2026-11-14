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

  testWidgets('each tone has its own icon unless one is given', (tester) async {
    final icons = {for (final t in BannerTone.values) Banner.defaultIcon(t)};
    expect(icons.length, BannerTone.values.length);
    await tester.pumpWidget(
      _host(const Banner(tone: BannerTone.warning, title: 'Careful')),
    );
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('is a polite live region and its icon is not announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Banner(
          tone: BannerTone.error,
          icon: AppIcons.error,
          title: "Couldn't save",
        ),
      ),
    );
    final node = tester.getSemantics(find.text("Couldn't save"));
    expect(node.label, contains("Couldn't save"));
    expect(
      tester.getSemantics(find.byType(Banner)).flagsCollection.isLiveRegion,
      isTrue,
    );
    handle.dispose();
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
