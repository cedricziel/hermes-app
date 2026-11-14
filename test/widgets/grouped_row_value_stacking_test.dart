import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/plugins/installed_plugin.dart';
import 'package:hermes_app/src/plugins/widgets/plugin_row.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  double scale = 1,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
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

bool _beside(WidgetTester tester, String title, String value) =>
    (tester.getTopLeft(find.text(title)).dy -
                tester.getTopLeft(find.text(value)).dy)
            .abs() <
        8 &&
    tester.getTopLeft(find.text(value)).dx >
        tester.getTopRight(find.text(title)).dx;

void main() {
  const longValue = 'Running, some channels offline and one restarting';

  for (final scale in [1.5, 2.0]) {
    testWidgets('a short value stays beside the title at ${scale}x', (
      tester,
    ) async {
      await _pump(
        tester,
        const GroupedRow(title: 'Telegram', value: 'Set up', onTap: _noop),
        scale: scale,
        // The test font is wider than the real one: a width that holds the
        // row the way a phone's does.
        width: 640,
      );
      expect(_beside(tester, 'Telegram', 'Set up'), isTrue);
    });
  }

  testWidgets('a value too long to fit stacks under the title at 2x', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupedRow(title: 'State', value: longValue, subtitle: 'Gateway'),
      scale: 2,
    );
    final title = tester.getTopLeft(find.text('State'));
    final value = tester.getTopLeft(find.text(longValue));
    final subtitle = tester.getTopLeft(find.text('Gateway'));
    expect(value.dy, greaterThan(title.dy));
    expect(value.dx, title.dx);
    // Title, then value, then subtitle.
    expect(subtitle.dy, greaterThan(value.dy));
  });

  testWidgets('a stacked value is set apart from the subtitle', (tester) async {
    await _pump(
      tester,
      const GroupedRow(title: 'State', value: longValue, subtitle: 'Gateway'),
      scale: 2,
    );
    final value = tester.widget<Text>(find.text(longValue)).style!;
    final subtitle = tester.widget<Text>(find.text('Gateway')).style!;
    expect(value.fontWeight, isNot(subtitle.fontWeight));
    expect(value.color, isNot(subtitle.color));
  });

  testWidgets('at the default size a long value is cut beside the title, as '
      'it was', (tester) async {
    await _pump(tester, const GroupedRow(title: 'State', value: longValue));
    expect(_beside(tester, 'State', longValue), isTrue);
  });

  testWidgets('a row with a switch never stacks', (tester) async {
    await _pump(
      tester,
      GroupedRow(
        title: 'State',
        value: longValue,
        trailing: Switch(value: true, onChanged: (_) {}),
      ),
      scale: 2,
    );
    expect(_beside(tester, 'State', longValue), isTrue);
  });

  testWidgets('a row without a value is untouched', (tester) async {
    await _pump(
      tester,
      const GroupedRow(title: 'Telegram', subtitle: 'Connected', onTap: _noop),
      scale: 2,
    );
    expect(find.byKey(const Key('grouped-row-chevron')), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('a value under half the row stacks when it would squeeze the '
      'title', (tester) async {
    // 'Set up' alone is under half the row, but beside this title, with a
    // leading icon and a chevron, the title would keep too little room.
    await _pump(
      tester,
      const GroupedRow(
        title: 'A rather long row title that needs room',
        leading: Icon(Icons.chat),
        value: 'Set up',
        onTap: _noop,
      ),
      scale: 1.2,
      width: 314,
    );
    final title = tester.getTopLeft(
      find.text('A rather long row title that needs room'),
    );
    final value = tester.getTopLeft(find.text('Set up'));
    expect(value.dx, title.dx);
    expect(value.dy, greaterThan(title.dy));
  });

  testWidgets(
    'a stacked row still honours titleMaxLines and subtitleMaxLines',
    (tester) async {
      const title = 'a long title that has to wrap somewhere in the row';
      const subtitle = 'a long subtitle that has to wrap somewhere in the row';
      await _pump(
        tester,
        const GroupedRow(
          title: title,
          titleMaxLines: 2,
          value: longValue,
          subtitle: subtitle,
          subtitleMaxLines: 2,
        ),
        scale: 2,
      );
      final titleText = tester.widget<Text>(find.text(title));
      expect(titleText.maxLines, 2);
      expect(titleText.overflow, TextOverflow.ellipsis);
      final subtitleText = tester.widget<Text>(find.text(subtitle));
      expect(subtitleText.maxLines, 2);
      expect(subtitleText.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('a stacked row with null limits still wraps in full', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupedRow(
        title: 'State',
        titleMaxLines: null,
        value: longValue,
        subtitle: 'Gateway',
        subtitleMaxLines: null,
      ),
      scale: 2,
    );
    expect(tester.widget<Text>(find.text('Gateway')).maxLines, isNull);
  });

  testWidgets('a stacked row with the default limit of one line truncates', (
    tester,
  ) async {
    const title = 'a long title that has to wrap somewhere in the row';
    const subtitle = 'a long subtitle that has to wrap somewhere in the row';
    await _pump(
      tester,
      const GroupedRow(title: title, value: longValue, subtitle: subtitle),
      scale: 2,
    );
    expect(tester.widget<Text>(find.text(title)).maxLines, 1);
    expect(tester.widget<Text>(find.text(subtitle)).maxLines, 1);
    // One line each: the rendered height is a line's, not several.
    expect(
      tester.getSize(find.text(subtitle)).height,
      lessThan(tester.getSize(find.text(longValue)).height * 1.5),
    );
  });

  testWidgets('wrapWhenStacked lets a stacked row wrap in full', (
    tester,
  ) async {
    const title = 'a long title that has to wrap somewhere in the row';
    const subtitle = 'a long subtitle that has to wrap somewhere in the row';
    await _pump(
      tester,
      const GroupedRow(
        title: title,
        value: longValue,
        subtitle: subtitle,
        wrapWhenStacked: true,
      ),
      scale: 2,
    );
    expect(tester.widget<Text>(find.text(subtitle)).maxLines, isNull);
    expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
  });

  testWidgets('a plugin row wraps its description in full once it stacks at '
      '2x', (tester) async {
    const description =
        'Query NetBox for devices, prefixes and addresses, and keep a folder '
        'of notes in step with what the agent remembers about them';
    await _pump(
      tester,
      const PluginRow(
        plugin: InstalledPlugin(
          name: 'a plugin with a rather long name',
          version: '1.2.0',
          description: description,
          status: PluginStatus.inactive,
        ),
        onTap: _noop,
      ),
      scale: 2,
      width: 300,
    );
    final text = tester.widget<Text>(find.text(description));
    expect(text.maxLines, isNull);
    final single = TextPainter(
      text: TextSpan(text: description, style: text.style),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(2),
    )..layout();
    // Several lines tall, so nothing is cut at the row's width.
    expect(
      tester.getSize(find.text(description)).height,
      greaterThan(single.preferredLineHeight * 2.5),
    );
    // Stacked: the value sits under the title, not beside it.
    expect(
      tester.getTopLeft(find.text('Inactive')).dy,
      greaterThan(
        tester
            .getTopLeft(find.textContaining('a plugin with a rather long name'))
            .dy,
      ),
    );
  });
}

void _noop() {}
