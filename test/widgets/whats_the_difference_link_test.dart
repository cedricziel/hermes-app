import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/whats_the_difference_link.dart';

void main() {
  Future<void> pump(
    WidgetTester t,
    Widget child, {
    TargetPlatform platform = TargetPlatform.android,
    double textScale = 1,
  }) => t.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('calls back, is a link and uses the link colour', (t) async {
    final handle = t.ensureSemantics();
    var taps = 0;
    await pump(t, WhatsTheDifferenceLink(onTap: () => taps++));
    await t.tap(find.text("What's the difference?"));
    expect(taps, 1);
    expect(
      t.getSemantics(find.text("What's the difference?")),
      isSemantics(isLink: true, hasTapAction: true),
    );
    final text = t.widget<Text>(find.text("What's the difference?"));
    expect(
      text.style?.color,
      buildHermesLightTheme().extension<HermesChatColors>()!.link,
    );
    handle.dispose();
  });

  for (final (platform, height) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('is at least $height tall on $platform', (t) async {
      await pump(t, WhatsTheDifferenceLink(onTap: () {}), platform: platform);
      expect(
        t.getSize(find.byType(WhatsTheDifferenceLink)).height,
        greaterThanOrEqualTo(height),
      );
    });
  }

  testWidgets('grows with the text size without overflowing', (t) async {
    await pump(t, WhatsTheDifferenceLink(onTap: () {}), textScale: 3);
    expect(t.takeException(), isNull);
    final small = t.getSize(find.text("What's the difference?")).height;
    await pump(t, WhatsTheDifferenceLink(onTap: () {}));
    expect(
      t.getSize(find.text("What's the difference?")).height,
      lessThan(small),
    );
  });

  testWidgets('the footer variant passes the tap on', (t) async {
    var taps = 0;
    await pump(t, WhatsTheDifferenceFooter(onTap: () => taps++));
    await t.tap(find.text("What's the difference?"));
    expect(taps, 1);
  });
  group('tap area', () {
    final text = find.text("What's the difference?");
    final area = find.descendant(
      of: find.byType(WhatsTheDifferenceLink),
      matching: find.byType(InkWell),
    );

    Future<Size> areaAt(
      WidgetTester t,
      double parentWidth,
      TargetPlatform platform,
      VoidCallback onTap,
    ) async {
      await pump(
        t,
        SizedBox(
          width: parentWidth,
          child: WhatsTheDifferenceLink(onTap: onTap),
        ),
        platform: platform,
      );
      return t.getSize(area);
    }

    for (final (platform, height) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      testWidgets('is the text wide and at least $height tall on $platform, '
          'whatever the parent width', (t) async {
        final narrow = await areaAt(t, 360, platform, () {});
        final textWidth = t.getSize(text).width;
        final wide = await areaAt(t, 900, platform, () {});

        expect(narrow.height, greaterThanOrEqualTo(height));
        expect(wide, narrow);
        expect(narrow.width, textWidth);
        expect(narrow.width, lessThan(360));
      });
    }

    testWidgets('a tap on the text opens it, one beside it does not', (
      t,
    ) async {
      var taps = 0;
      await areaAt(t, 900, TargetPlatform.android, () => taps++);
      await t.tap(text);
      expect(taps, 1);

      final box = t.getRect(area);
      await t.tapAt(Offset(box.right + 40, box.center.dy));
      expect(taps, 1);
    });
  });
}
