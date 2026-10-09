import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/plugins/widgets/catalog_row.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Widget _app(TargetPlatform platform, Widget row) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: Scaffold(
    body: GroupedListView(
      children: [
        GroupedSection(children: [row]),
      ],
    ),
  ),
);

void main() {
  for (final (platform, guideline, height) in [
    (TargetPlatform.iOS, iOSTapTargetGuideline, 28.0),
    (TargetPlatform.android, androidTapTargetGuideline, 32.0),
  ]) {
    testWidgets(
      'an Install button on $platform keeps its size and is big enough to tap',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            platform,
            GroupedRow(
              title: 'weather-lookup',
              onTap: () {},
              trailing: InstallButton(installing: false, onPressed: () {}),
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(guideline));
        final pill = find.descendant(
          of: find.byType(InstallButton),
          matching: find.byType(Material),
        );
        expect(tester.getSize(pill.first).height, height);
        semantics.dispose();
      },
    );
  }

  testWidgets('the Set up button on Android is big enough to tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        MessagingPlatformRow(
          platform: const HermesMessagingPlatform(id: 'slack', name: 'Slack'),
          onSetUp: () {},
          onToggle: (_) {},
        ),
      ),
    );
    expect(find.text('Set up'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
