import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

/// What a switch paints, sampled from the rendered pixels so the test sees
/// what the user sees and not a theme property a default could override.
class _Painted {
  _Painted(this.background, this.track, this.outline, this.thumb);

  final Color background;
  final Color track;
  final Color outline;
  final Color thumb;

  double get outlineOnBackground => _contrast(outline, background);
  double get thumbOnTrack => _contrast(thumb, track);
  double get trackOnBackground => _contrast(track, background);

  @override
  String toString() =>
      'bg=${_hex(background)} track=${_hex(track)} outline=${_hex(outline)} '
      'thumb=${_hex(thumb)} outline/bg=${outlineOnBackground.toStringAsFixed(2)} '
      'thumb/track=${thumbOnTrack.toStringAsFixed(2)} '
      'track/bg=${trackOnBackground.toStringAsFixed(2)}';
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// WCAG 2.x contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

ThemeData _theme(TargetPlatform platform, Brightness brightness) =>
    brightness == Brightness.dark
    ? buildHermesDarkTheme(platform: platform)
    : buildHermesLightTheme(platform: platform);

Future<_Painted> _paint(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Brightness brightness,
  required bool on,
  bool enabled = true,
  bool withoutAdaptation = false,
}) async {
  var theme = _theme(platform, brightness);
  if (withoutAdaptation) theme = theme.copyWith(adaptations: const []);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.all(24),
              child: GroupedSwitch(
                value: on,
                onChanged: enabled ? (_) {} : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final center =
      tester.getCenter(find.byType(Switch)) -
      tester.getTopLeft(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  Color at(double dx, double dy) {
    final x = (center.dx + dx).floor();
    final y = (center.dy + dy).floor();
    final i = (y * image.width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  final apple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  // The thumb sits left when off and right when on; the track is sampled on
  // the side the thumb is not, and the Material outline at the top edge.
  final trackDx = on ? -12.0 : 12.0;
  return _Painted(
    at(-center.dx + 2, 2),
    at(trackDx, 0),
    apple ? at(trackDx, 0) : at(0, -15),
    at(on ? 10 : -10, 0),
  );
}

void main() {
  const materialPlatforms = [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];

  for (final brightness in Brightness.values) {
    for (final platform in materialPlatforms) {
      testWidgets(
        '${platform.name} ${brightness.name}: an off switch shows its '
        'boundary and its thumb (WCAG 1.4.11)',
        (tester) async {
          final p = await _paint(
            tester,
            platform: platform,
            brightness: brightness,
            on: false,
          );
          expect(p.outlineOnBackground, greaterThanOrEqualTo(3.0));
          expect(p.thumbOnTrack, greaterThanOrEqualTo(3.0));
        },
      );

      testWidgets('${platform.name} ${brightness.name}: an on switch keeps the '
          'primary track and onPrimary thumb', (tester) async {
        final scheme = _theme(platform, brightness).colorScheme;
        final p = await _paint(
          tester,
          platform: platform,
          brightness: brightness,
          on: true,
        );
        expect(p.track, scheme.primary);
        expect(p.thumb, scheme.onPrimary);
      });

      testWidgets('${platform.name} ${brightness.name}: a disabled off switch '
          'keeps Material\'s dimmed outline and thumb', (tester) async {
        final adapted = await _paint(
          tester,
          platform: platform,
          brightness: brightness,
          on: false,
          enabled: false,
        );
        final material = await _paint(
          tester,
          platform: platform,
          brightness: brightness,
          on: false,
          enabled: false,
          withoutAdaptation: true,
        );
        expect(adapted.outline, material.outline);
        expect(adapted.thumb, material.thumb);
      });
    }
  }

  // iOS and macOS keep the platform's own OFF track, which is below 3:1
  // against the row. What to do about that is the owner's open choice, so
  // these only stop it getting worse than the values measured today.
  for (final (platform, brightness, floor) in [
    (TargetPlatform.iOS, Brightness.dark, 1.43),
    (TargetPlatform.macOS, Brightness.dark, 1.43),
    (TargetPlatform.iOS, Brightness.light, 1.2),
    (TargetPlatform.macOS, Brightness.light, 1.2),
  ]) {
    testWidgets(
      '${platform.name} ${brightness.name}: the off track is no fainter '
      'than today',
      (tester) async {
        final p = await _paint(
          tester,
          platform: platform,
          brightness: brightness,
          on: false,
        );
        expect(p.trackOnBackground, greaterThanOrEqualTo(floor));
      },
    );
  }
}
