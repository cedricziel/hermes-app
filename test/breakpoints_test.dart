import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';

Future<bool> _isWide(
  WidgetTester tester,
  Size size,
  TargetPlatform platform, {
  double? width,
}) async {
  late bool result;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) {
          result = isWideLayout(context, width: width);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  group('isWideLayout on iOS', () {
    testWidgets('11-inch iPad in portrait is wide', (tester) async {
      expect(
        await _isWide(tester, const Size(834, 1194), TargetPlatform.iOS),
        isTrue,
      );
    });

    testWidgets('iPad mini in portrait is wide', (tester) async {
      expect(
        await _isWide(tester, const Size(744, 1133), TargetPlatform.iOS),
        isTrue,
      );
    });

    testWidgets('iPad in landscape is wide', (tester) async {
      expect(
        await _isWide(tester, const Size(1194, 834), TargetPlatform.iOS),
        isTrue,
      );
    });

    testWidgets('a Split View half stays compact', (tester) async {
      expect(
        await _isWide(tester, const Size(507, 834), TargetPlatform.iOS),
        isFalse,
      );
      expect(
        await _isWide(tester, const Size(570, 834), TargetPlatform.iOS),
        isFalse,
      );
    });

    testWidgets('iPhone stays compact in portrait and landscape', (
      tester,
    ) async {
      expect(
        await _isWide(tester, const Size(390, 844), TargetPlatform.iOS),
        isFalse,
      );
      expect(
        await _isWide(tester, const Size(844, 390), TargetPlatform.iOS),
        isFalse,
      );
    });

    testWidgets('a pane narrower than the threshold is compact', (
      tester,
    ) async {
      expect(
        await _isWide(
          tester,
          const Size(834, 1194),
          TargetPlatform.iOS,
          width: 554,
        ),
        isFalse,
      );
    });
  });

  group('isWideLayout elsewhere', () {
    testWidgets('Android at 834 keeps the 900 breakpoint', (tester) async {
      expect(
        await _isWide(tester, const Size(834, 1194), TargetPlatform.android),
        isFalse,
      );
      expect(
        await _isWide(tester, const Size(900, 1194), TargetPlatform.android),
        isTrue,
      );
    });

    testWidgets('macOS keeps the 900 breakpoint', (tester) async {
      expect(
        await _isWide(tester, const Size(800, 900), TargetPlatform.macOS),
        isFalse,
      );
    });
  });
}
