import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

const _phone = Size(390, 844);
const _desktop = Size(700, 844);

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double scale,
  required Size size,
  required Widget row,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: GroupedListView(
          children: [
            GroupedSection(children: [row]),
          ],
        ),
      ),
    ),
  );
}

Widget _updates() => SkillUpdatesSection(onPressed: () {});

Widget _setUp() => MessagingPlatformRow(
  platform: const HermesMessagingPlatform(id: 'slack', name: 'Slack'),
  onSetUp: () {},
  onToggle: (_) {},
);

/// The button is on screen, tappable and not under another widget.
void _expectReachable(WidgetTester tester, Finder button, Size size) {
  expect(button, findsOneWidget);
  expect(button.hitTestable(), findsOneWidget);
  final rect = tester.getRect(button);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
}

void main() {
  final macButton = find.widgetWithText(OutlinedButton, 'Check for Updates');
  final materialButton = find.widgetWithText(OutlinedButton, 'Set up');

  for (final scale in [2.0, 3.0]) {
    testWidgets(
      'Check for Updates on a Mac stays on screen at ${scale}x text',
      (tester) async {
        await _pump(
          tester,
          platform: TargetPlatform.macOS,
          scale: scale,
          size: _phone,
          row: _updates(),
        );
        expect(tester.takeException(), isNull);
        _expectReachable(tester, macButton, _phone);
        // Mac pointer targets are at least 28 pt.
        expect(tester.getSize(macButton).height, greaterThanOrEqualTo(28));
      },
    );

    testWidgets('Set up on Material stays on screen at ${scale}x text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        platform: TargetPlatform.android,
        scale: scale,
        size: _phone,
        row: _setUp(),
      );
      expect(tester.takeException(), isNull);
      _expectReachable(tester, materialButton, _phone);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }

  group('the layout is unchanged where the button fits beside the label', () {
    testWidgets('Check for Updates, 1x on a phone and 1.5x on a desktop', (
      tester,
    ) async {
      for (final (scale, size) in [(1.0, _phone), (1.5, _desktop)]) {
        await _pump(
          tester,
          platform: TargetPlatform.macOS,
          scale: scale,
          size: size,
          row: _updates(),
        );
        expect(tester.takeException(), isNull);
        final label = tester.getRect(find.text('Hub skills'));
        final button = tester.getRect(macButton);
        expect(button.left, greaterThan(label.right));
        expect(button.center.dy, closeTo(label.center.dy, 1));
      }
    });

    testWidgets('Set up, 1x on a phone and 3x on a desktop', (tester) async {
      for (final (scale, size) in [(1.0, _phone), (3.0, _desktop)]) {
        await _pump(
          tester,
          platform: TargetPlatform.android,
          scale: scale,
          size: size,
          row: _setUp(),
        );
        expect(tester.takeException(), isNull);
        final label = tester.getRect(find.text('Slack'));
        final button = tester.getRect(materialButton);
        expect(button.left, greaterThan(label.right));
        expect(button.center.dy, closeTo(label.center.dy, 1));
      }
    });
  });
}
