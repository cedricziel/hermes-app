import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Widget _app(TargetPlatform platform, Widget child) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: Scaffold(body: GroupedListView(children: [child])),
);

final _chevron = find.byKey(const Key('grouped-row-chevron'));

void main() {
  testWidgets('separates rows with one divider between each pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        const GroupedSection(
          header: 'Installed',
          footer: 'Skills run in every chat of this profile.',
          children: [
            GroupedRow(title: 'One'),
            GroupedRow(title: 'Two'),
            GroupedRow(title: 'Three'),
          ],
        ),
      ),
    );
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.text('INSTALLED'), findsOneWidget);
    expect(
      find.text('Skills run in every chat of this profile.'),
      findsOneWidget,
    );
  });

  testWidgets('a header keeps its case off iOS', (tester) async {
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        const GroupedSection(
          header: 'Installed',
          children: [GroupedRow(title: 'One')],
        ),
      ),
    );
    expect(find.text('Installed'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('a row that opens something has a chevron and is tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        GroupedRow(
          title: 'Telegram',
          subtitle: '@hermes_bot',
          value: 'Connected',
          onTap: () => taps++,
        ),
      ),
    );
    expect(_chevron, findsOneWidget);
    await tester.tap(find.text('Telegram'));
    expect(taps, 1);
  });

  testWidgets('a row without an action has no chevron', (tester) async {
    await tester.pumpWidget(
      _app(TargetPlatform.iOS, const GroupedRow(title: 'Plain')),
    );
    expect(_chevron, findsNothing);
  });

  testWidgets('a switch row shows a switch instead of a chevron', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        GroupedSwitchRow(
          title: 'Memory',
          value: false,
          onChanged: (on) => changed = on,
          onTap: () {},
        ),
      ),
    );
    expect(_chevron, findsNothing);
    await tester.tap(find.byType(Switch));
    expect(changed, isTrue);
  });

  testWidgets('a switch row is named by its title', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        TargetPlatform.macOS,
        GroupedSwitchRow(title: 'Memory', value: true, onChanged: (_) {}),
      ),
    );
    expect(
      tester.getSemantics(find.byType(Switch)),
      isSemantics(label: 'Memory', isToggled: true, hasToggledState: true),
    );
    semantics.dispose();
  });

  testWidgets('a switch row that opens details keeps its own switch node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    bool? changed;
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        GroupedSwitchRow(
          title: 'grafana',
          subtitle: 'https://mcp.grafana.com/mcp',
          leading: const GroupedTile(child: Text('G')),
          value: true,
          onChanged: (on) => changed = on,
          onTap: () => opened++,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(Switch)),
      isSemantics(label: 'grafana', isToggled: true, hasToggledState: true),
    );
    expect(
      find.semantics.byLabel(RegExp(r'grafana[\s\S]*mcp\.grafana\.com')),
      findsOne,
    );
    await tester.tap(find.text('grafana'));
    expect(opened, 1);
    await tester.tap(find.byType(Switch));
    expect(changed, isFalse);
    expect(opened, 1);
    semantics.dispose();
  });

  for (final (platform, height) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.macOS, 40.0),
    (TargetPlatform.android, 56.0),
  ]) {
    testWidgets('a one-line row on $platform is $height high', (tester) async {
      await tester.pumpWidget(
        _app(platform, GroupedRow(title: 'Row', onTap: () {})),
      );
      expect(tester.getSize(find.byType(GroupedRow)).height, height);
    });

    testWidgets('a switch row on $platform is $height high', (tester) async {
      await tester.pumpWidget(
        _app(
          platform,
          GroupedSwitchRow(title: 'Row', value: true, onChanged: (_) {}),
        ),
      );
      expect(tester.getSize(find.byType(GroupedRow)).height, height);
    });
  }

  testWidgets('shows the meta text and a warning line', (tester) async {
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        const GroupedRow(
          title: 'kanban',
          meta: 'v1.2.0',
          warning: 'Needs a newer Hermes',
        ),
      ),
    );
    expect(find.textContaining('v1.2.0', findRichText: true), findsOneWidget);
    expect(find.text('Needs a newer Hermes'), findsOneWidget);
  });

  testWidgets('shows an error line in the error colour', (tester) async {
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        const GroupedRow(title: 'Slack', error: 'Invalid bot token'),
      ),
    );
    final context = tester.element(find.byType(GroupedRow));
    final text = tester.widget<Text>(find.text('Invalid bot token'));
    expect(text.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('shows a caption under the subtitle, monospaced on request', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        const GroupedRow(
          title: 'filesystem',
          subtitle: 'npx server-filesystem',
          monospaceSubtitle: true,
          caption: 'Command · Off',
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('npx server-filesystem')).style?.fontFamily,
      'monospace',
    );
    expect(find.text('Command · Off'), findsOneWidget);
  });

  for (final (platform, size) in [
    (TargetPlatform.iOS, 29.0),
    (TargetPlatform.macOS, 24.0),
    (TargetPlatform.android, 32.0),
  ]) {
    testWidgets('a leading tile on $platform is $size square', (tester) async {
      await tester.pumpWidget(
        _app(
          platform,
          const GroupedRow(
            title: 'grafana',
            leading: GroupedTile(child: Text('G')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(GroupedTile)), Size.square(size));
    });
  }

  testWidgets('centers the groups in the Mac column on a wide page', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        TargetPlatform.macOS,
        const GroupedSection(children: [GroupedRow(title: 'Row')]),
      ),
    );
    expect(tester.getSize(find.byType(GroupedSection)).width, 600);
    expect(tester.getTopLeft(find.byType(GroupedSection)).dx, 300);
  });
}
