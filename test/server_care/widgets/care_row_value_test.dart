import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/widgets/care_row_value.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

// The test font gives every glyph the width of its size: 10 chars at 10 px.
const _style = TextStyle(fontSize: 10, fontFamily: 'Ahem');

Widget _host(Widget child, {double scale = 1, double width = 400}) =>
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: GroupedSection(children: [child]),
            ),
          ),
        ),
      ),
    );

void main() {
  group('careRowText', () {
    test('keeps a value that fits', () {
      final text = careRowText(
        value: '38 GB free',
        subtitle: '62% used',
        maxValueWidth: 100,
        style: _style,
      );
      expect(text, (value: '38 GB free', subtitle: '62% used'));
    });

    test('moves a value wider than the room into the subtitle', () {
      final text = careRowText(
        value: 'Running, some channels offline',
        maxValueWidth: 100,
        style: _style,
      );
      expect(text, (value: null, subtitle: 'Running, some channels offline'));
    });

    test('puts a moved value before the existing subtitle', () {
      final text = careRowText(
        value: 'Running, some channels offline',
        subtitle: 'Since 09:12',
        maxValueWidth: 100,
        style: _style,
      );
      expect(text.subtitle, 'Running, some channels offline · Since 09:12');
      expect(text.value, isNull);
    });

    test('counts the text scale', () {
      final text = careRowText(
        value: '38 GB free',
        maxValueWidth: 100,
        style: _style,
        textScaler: const TextScaler.linear(2),
      );
      expect(text.value, isNull);
      expect(text.subtitle, '38 GB free');
    });

    test('passes no value through', () {
      expect(
        careRowText(
          value: null,
          subtitle: 'Hi',
          maxValueWidth: 10,
          style: _style,
        ),
        (value: null, subtitle: 'Hi'),
      );
    });

    test('a value gets half the row less the gap', () {
      expect(careRowValueWidth(300), 142);
    });
  });

  group('CareValueRow', () {
    testWidgets('a long state becomes the subtitle', (tester) async {
      await tester.pumpWidget(
        _host(
          const CareValueRow(
            title: 'State',
            value: 'Running, some channels offline',
          ),
          width: 360,
        ),
      );
      expect(find.text('Running, some channels offline'), findsOneWidget);
      // Not at the trailing edge: it sits under the title.
      final title = tester.getTopLeft(find.text('State'));
      final state = tester.getTopLeft(
        find.text('Running, some channels offline'),
      );
      expect(state.dx, title.dx);
      expect(state.dy, greaterThan(title.dy));
    });

    testWidgets('a short value stays at the trailing edge', (tester) async {
      await tester.pumpWidget(
        _host(
          const CareValueRow(
            title: 'Disk',
            value: '38 GB free',
            subtitle: '62% used',
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('38 GB free')).dx,
        greaterThan(tester.getTopLeft(find.text('Disk')).dx + 100),
      );
    });

    testWidgets(
      'a value that no longer fits at large text joins the subtitle',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const CareValueRow(
              title: 'Disk',
              value: '38 GB free',
              subtitle: '62% used',
            ),
            scale: 2,
          ),
        );
        expect(find.text('38 GB free · 62% used'), findsOneWidget);
        expect(find.text('38 GB free'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
