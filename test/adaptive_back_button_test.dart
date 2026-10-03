import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';

Widget _app(TargetPlatform platform) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Detail'),
                    leading: const AdaptiveBackButton(previousTitle: 'Skills'),
                    leadingWidth: adaptiveBackLeadingWidth(context),
                  ),
                  body: const SizedBox.expand(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(_app(platform));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iOS shows a chevron labelled with the parent title', (
    tester,
  ) async {
    await _open(tester, TargetPlatform.iOS);
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
  });

  testWidgets('iOS pops on an edge swipe', (tester) async {
    await _open(tester, TargetPlatform.iOS);
    await tester.dragFrom(const Offset(2, 300), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('the iOS button pops the route', (tester) async {
    await _open(tester, TargetPlatform.iOS);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('macOS and Material keep the standard back button', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
      await _open(tester, platform);
      expect(find.byType(BackButton), findsOneWidget, reason: '$platform');
      expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);
      expect(find.text('Skills'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
