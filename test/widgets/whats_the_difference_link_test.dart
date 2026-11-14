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
}
