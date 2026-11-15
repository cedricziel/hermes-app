import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? buildHermesLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows title, detail and action', (tester) async {
    await tester.pumpWidget(
      _host(
        AppBanner(
          tone: AppBannerTone.neutral,
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
    final icons = {
      for (final t in AppBannerTone.values) AppBanner.defaultIcon(t),
    };
    expect(icons.length, AppBannerTone.values.length);
    await tester.pumpWidget(
      _host(const AppBanner(tone: AppBannerTone.warning, title: 'Careful')),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, AppIcons.warning.material);
  });

  testWidgets('announces title and detail as one live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const AppBanner(
          tone: AppBannerTone.error,
          title: "Couldn't save",
          detail: 'Try again.',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(AppBanner)),
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
        AppBanner(
          tone: AppBannerTone.neutral,
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
        child: AppBanner(
          tone: AppBannerTone.warning,
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

  group('action target and stacked layout', () {
    const german = 'Die Speicherung konnte nicht bestätigt werden';
    const germanAction = 'Erneut prüfen';

    Widget build({
      required TargetPlatform platform,
      double scale = 1,
      String title = 'Title',
      Locale? locale,
      double width = 360,
    }) {
      final theme = buildHermesLightTheme().copyWith(
        platform: platform,
        // A Mac theme draws compact buttons; the banner must not inherit that.
        visualDensity: platform == TargetPlatform.macOS
            ? VisualDensity.compact
            : null,
      );
      return MaterialApp(
        theme: theme,
        locale: locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('de')],
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: AppBanner(
                  tone: AppBannerTone.warning,
                  title: title,
                  detail: 'It may have gone through.',
                  action: TextButton(
                    onPressed: () {},
                    child: Text(
                      locale?.languageCode == 'de' ? germanAction : 'Check',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder button() => find.byType(TextButton);

    for (final (platform, minimum) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      for (final scale in [1.0, 3.0]) {
        testWidgets(
          'the action is at least $minimum high on $platform at ${scale}x',
          (tester) async {
            await tester.pumpWidget(build(platform: platform, scale: scale));
            final size = tester.getSize(button());
            expect(size.height, greaterThanOrEqualTo(minimum));
            expect(size.width, greaterThanOrEqualTo(minimum));
          },
        );
      }
    }

    testWidgets('a custom-styled action still gets the minimum', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: AppBanner(
              tone: AppBannerTone.neutral,
              title: 'T',
              action: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TextButton)).height, 44);
    });

    testWidgets('at 3.0x the text takes the full width and the action sits '
        'under it, at the text\'s leading edge', (tester) async {
      await tester.pumpWidget(build(platform: TargetPlatform.iOS, scale: 3));
      final title = find.text('Title');
      final detail = find.text('It may have gone through.');
      final label = find.text('Check');
      expect(
        tester.getTopLeft(button()).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(detail).dy),
      );
      expect(
        tester.getTopLeft(label).dx,
        closeTo(tester.getTopLeft(title).dx, 0.5),
      );
      // 360 wide, 1 border, 12 padding: the text column runs to the edge.
      expect(
        tester
            .getRect(
              find.ancestor(of: title, matching: find.byType(Column)).first,
            )
            .right,
        closeTo(360 - 1 - 12, 0.5),
      );
    });

    testWidgets('in German the action stacks even at the normal size', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          platform: TargetPlatform.iOS,
          title: german,
          locale: const Locale('de'),
        ),
      );
      final title = find.text(german);
      expect(
        tester.getTopLeft(find.text(germanAction)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('It may have gone through.')).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.text(germanAction)).dx,
        closeTo(tester.getTopLeft(title).dx, 0.5),
      );
      // The title wraps in the full-width column instead of a squeezed one.
      expect(tester.getSize(title).width, greaterThan(360 - 12 * 2 - 28 - 60));
    });

    testWidgets('a semantics wrapper with no child as the action does not '
        'hang the layout of a stacked banner', (tester) async {
      for (final action in <Widget>[
        Semantics(),
        const ExcludeSemantics(),
        const MergeSemantics(child: SizedBox()),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppBanner(
                tone: AppBannerTone.warning,
                title: german,
                action: action,
              ),
            ),
          ),
        );
        expect(find.byType(AppBanner), findsOneWidget);
      }
    });

    testWidgets('in English at the normal size the action stays beside', (
      tester,
    ) async {
      await tester.pumpWidget(build(platform: TargetPlatform.iOS));
      expect(
        tester.getTopLeft(button()).dy,
        lessThan(tester.getBottomLeft(find.text('Title')).dy),
      );
    });
  });

  group('stacked action alignment and non-button actions', () {
    Widget host({
      required Widget action,
      double scale = 1,
      Locale? locale,
      String title = 'Title',
      bool actionIsButton = true,
      TargetPlatform platform = TargetPlatform.iOS,
      TextDirection direction = TextDirection.ltr,
    }) => MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: 360,
                child: AppBanner(
                  tone: AppBannerTone.warning,
                  title: title,
                  detail: 'Detail',
                  action: action,
                  actionIsButton: actionIsButton,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    TextButton padded(String label, EdgeInsets padding) => TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: padding,
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );

    for (final (name, scale, locale) in [
      ('3x', 3.0, null),
      ('German', 1.0, const Locale('de')),
    ]) {
      testWidgets('a button with its own side padding stacks flush at $name', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            action: padded('Check', const EdgeInsets.symmetric(horizontal: 16)),
            scale: scale,
            locale: locale,
          ),
        );
        expect(
          tester.getTopLeft(find.text('Check')).dx,
          closeTo(tester.getTopLeft(find.text('Title')).dx, 0.5),
        );
        expect(
          tester.getTopLeft(find.byType(TextButton)).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.text('Detail')).dy),
        );
      });
    }

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      for (final direction in TextDirection.values) {
        for (final (name, scale, locale) in [
          ('3x', 3.0, null),
          ('German', 1.0, const Locale('de')),
        ]) {
          testWidgets(
            'a padded button taps at both edges: $platform $direction $name',
            (tester) async {
              var taps = 0;
              await tester.pumpWidget(
                host(
                  action: TextButton(
                    onPressed: () => taps++,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('OK'),
                  ),
                  scale: scale,
                  locale: locale,
                  platform: platform,
                  direction: direction,
                ),
              );
              final rect = tester.getRect(find.byType(TextButton));
              final minimum = switch (platform) {
                TargetPlatform.iOS => 44.0,
                TargetPlatform.macOS => 28.0,
                _ => 48.0,
              };
              expect(rect.width, greaterThanOrEqualTo(minimum));
              await tester.tapAt(rect.centerLeft + const Offset(2, 0));
              await tester.tapAt(rect.centerRight - const Offset(2, 0));
              expect(taps, 2);
            },
          );
        }
      }
    }

    testWidgets('a styled button stays tappable where it was moved', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          action: TextButton(
            onPressed: () => taps++,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Check'),
          ),
          scale: 3,
        ),
      );
      await tester.tap(find.text('Check'));
      expect(taps, 1);
    });

    testWidgets('a button inside a wrapper widget still gets the minimum', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          action: Builder(
            builder: (_) => TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(minimumSize: Size.zero),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TextButton)).height, 44);
    });

    testWidgets('a small spinner passed as the action keeps its size', (
      tester,
    ) async {
      const key = Key('spinner');
      for (final scale in [1.0, 3.0]) {
        await tester.pumpWidget(
          host(
            action: const SizedBox.square(
              key: key,
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            scale: scale,
            actionIsButton: false,
          ),
        );
        expect(tester.getSize(find.byKey(key)), const Size.square(16));
      }
    });

    testWidgets('a Files note action in German is not squeezed by a 150 cap '
        'at the normal size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: FilesOfflineBanner(onRetry: () {}),
              ),
            ),
          ),
        ),
      );
      final label = find.text('Erneut versuchen');
      expect(label, findsOneWidget);
      expect(tester.getSize(label).height, lessThan(24));
    });
  });

  testWidgets('every tone builds in both themes', (tester) async {
    for (final theme in [buildHermesLightTheme(), buildHermesDarkTheme()]) {
      for (final tone in AppBannerTone.values) {
        await tester.pumpWidget(
          _host(
            AppBanner(tone: tone, title: 'T', detail: 'D'),
            theme: theme,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
