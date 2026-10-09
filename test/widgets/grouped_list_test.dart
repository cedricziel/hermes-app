import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  const long =
      'The server refused the bot token because it was revoked in the '
      'platform settings an hour ago, so the bot cannot sign in';

  double lineHeight(WidgetTester tester, String text) {
    final style = tester.widget<Text>(find.text(text)).style!;
    return style.fontSize! * 1.5;
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('an error line on $platform wraps instead of cutting off', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(platform, const GroupedRow(title: 'Slack', error: long)),
      );
      expect(
        tester.getSize(find.text(long)).height,
        greaterThan(lineHeight(tester, long)),
      );
      expect(
        tester.renderObject<RenderParagraph>(find.text(long)).didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('a warning line on $platform wraps instead of cutting off', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(platform, GroupedRow(title: 'Slack', warning: '$long. $long')),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('$long. $long'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  }

  testWidgets('a subtitle stays on one line unless the row asks for more', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        const GroupedSection(
          children: [
            GroupedRow(key: Key('short'), title: 'One', subtitle: long),
            GroupedRow(
              key: Key('long'),
              title: 'Two',
              subtitle: '$long.',
              subtitleMaxLines: null,
            ),
          ],
        ),
      ),
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text(long)).didExceedMaxLines,
      isTrue,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('$long.'))
          .didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('a long value shortens instead of overflowing the row', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        TargetPlatform.iOS,
        GroupedRow(
          title: 'Platforms',
          value: 'macOS, Linux, Windows, iOS, Android, FreeBSD, Haiku',
          onTap: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopRight(find.text('Platforms')).dx,
      lessThan(tester.getTopLeft(find.textContaining('macOS, Linux')).dx),
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('a disabled row on $platform is still a button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          platform,
          GroupedRow(
            title: 'Estimate the work',
            enabled: false,
            onTap: () => taps++,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Estimate the work')),
        isSemantics(
          label: 'Estimate the work',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      await tester.tap(find.text('Estimate the work'));
      expect(taps, 0);
      semantics.dispose();
    });

    testWidgets('a checked row on $platform says it is checked', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          platform,
          GroupedRow(
            title: 'Ada',
            checked: true,
            trailing: const Icon(Icons.check),
            onTap: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Ada')),
        isSemantics(
          label: 'Ada',
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a leading tile on $platform is not read out', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          platform,
          GroupedRow(
            title: 'Work assistant',
            leading: const GroupedTile(child: Text('WA')),
            onTap: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Work assistant')),
        isSemantics(label: 'Work assistant'),
      );
      semantics.dispose();
    });
  }

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
