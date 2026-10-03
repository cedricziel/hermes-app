import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

void main() {
  Future<PlatformChrome> chromeFor(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    late PlatformChrome chrome;
    await tester.pumpWidget(
      Theme(
        data: ThemeData(platform: platform),
        child: Builder(
          builder: (context) {
            chrome = platformChromeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return chrome;
  }

  testWidgets('iOS and macOS follow Apple conventions', (tester) async {
    expect(await chromeFor(tester, TargetPlatform.iOS), PlatformChrome.ios);
    expect(await chromeFor(tester, TargetPlatform.macOS), PlatformChrome.macos);
    expect(PlatformChrome.ios.isApple, isTrue);
    expect(PlatformChrome.macos.isApple, isTrue);
  });

  testWidgets('other platforms stay Material', (tester) async {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      final chrome = await chromeFor(tester, platform);
      expect(chrome, PlatformChrome.material);
      expect(chrome.isApple, isFalse);
    }
  });
}
