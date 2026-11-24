import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import '../support/screenshot_recorder.dart';
import '../support/test_localizations.dart';

const _longValue = 'Aktives Profil (default) mit weiteren Einstellungen';
const _title29 = 'Bei Abschluss benachrichtigen';
const _title35 = 'Automatisch Unteraufgaben erstellen';

/// Pumps [row] in a [rowWidth] wide box at the top left of a [window] wide
/// view, on [platform], at [scale]x text.
Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget row, {
  required double rowWidth,
  double window = 800,
  double scale = 1,
}) async {
  await tester.runAsync(loadTestFonts);
  tester.view
    ..physicalSize = Size(window, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: rowWidth, child: row),
        ),
      ),
    ),
  );
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

double _width(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).width;

/// How many lines [text] takes.
int _lines(WidgetTester tester, String text) => _paragraph(tester, text)
    .getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    )
    .map((box) => box.top.round())
    .toSet()
    .length;

Widget _valueRow(String title, String value) =>
    GroupedValueRow(title: title, value: value, onTap: () {});

Widget _menuRow(String title, String value) => GroupedMenuRow<String>(
  title: title,
  options: [value, 'Hermes'],
  labelOf: (option) => option,
  selected: value,
  onSelected: (_) {},
);

Widget _switchRow(String title) =>
    GroupedSwitchRow(title: title, value: true, onChanged: (_) {});

void main() {
  testWidgets('a Mac pop-up in a 246 px dialog row keeps room for the title '
      'and truncates a long value', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      TargetPlatform.macOS,
      _menuRow('Aktives Profil', _longValue),
      rowWidth: 246,
    );
    expect(tester.takeException(), isNull);
    expect(_width(tester, 'Aktives Profil'), greaterThan(0));
    expect(_paragraph(tester, _longValue).didExceedMaxLines, isTrue);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(_longValue))),
      findsOneWidget,
    );
    semantics.dispose();
  });

  for (final window in [800.0, 1200.0]) {
    testWidgets('an iOS value in a 320 px dialog row in a ${window.toInt()} px '
        'window drops under the title', (tester) async {
      await _pump(
        tester,
        TargetPlatform.iOS,
        _valueRow('Aktives Profil', _longValue),
        rowWidth: 320,
        window: window,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text(_longValue)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.text('Aktives Profil')).dy,
        ),
      );
    });
  }

  for (final (scale, title) in [
    (1.0, _title35),
    (1.5, 'Aktives Profil (default)'),
    (1.5, _title29),
  ]) {
    testWidgets('an iPhone switch title of ${title.length} characters wraps '
        'at ${scale}x', (tester) async {
      await _pump(
        tester,
        TargetPlatform.iOS,
        _switchRow(title),
        rowWidth: 358,
        window: 390,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(_paragraph(tester, title).didExceedMaxLines, isFalse);
      expect(_lines(tester, title), lessThanOrEqualTo(2));
    });
  }

  for (final (scale, title) in [
    (1.0, _title29),
    (1.5, 'Benachrichtigungen'),
    (1.5, _title29),
  ]) {
    testWidgets('an iPhone picker title of ${title.length} characters is not '
        'cut at ${scale}x', (tester) async {
      await _pump(
        tester,
        TargetPlatform.iOS,
        _valueRow(title, 'Hermes Standard'),
        rowWidth: 358,
        window: 390,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(_paragraph(tester, title).didExceedMaxLines, isFalse);
    });
  }

  testWidgets('an Android picker keeps its value under the title', (
    tester,
  ) async {
    await _pump(
      tester,
      TargetPlatform.android,
      _valueRow('Aktives Profil', 'Hermes Standard'),
      rowWidth: 358,
      window: 412,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Hermes Standard')).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.text('Aktives Profil')).dy,
      ),
    );
  });

  testWidgets('an Android switch title of 35 characters wraps', (tester) async {
    await _pump(
      tester,
      TargetPlatform.android,
      _switchRow(_title35),
      rowWidth: 358,
      window: 412,
    );
    expect(tester.takeException(), isNull);
    expect(_paragraph(tester, _title35).didExceedMaxLines, isFalse);
  });

  testWidgets('a short iOS pair stays on one line', (tester) async {
    await _pump(
      tester,
      TargetPlatform.iOS,
      _valueRow('Profil', 'Hermes'),
      rowWidth: 358,
      window: 390,
    );
    expect(
      tester.getTopLeft(find.text('Hermes')).dy,
      closeTo(tester.getTopLeft(find.text('Profil')).dy, 4),
    );
    expect(
      tester.getTopLeft(find.text('Hermes')).dx,
      greaterThan(tester.getTopRight(find.text('Profil')).dx),
    );
  });

  testWidgets('a short Mac pop-up keeps its natural width', (tester) async {
    await _pump(
      tester,
      TargetPlatform.macOS,
      _menuRow('Profil', 'Hermes'),
      rowWidth: 480,
      window: 600,
    );
    expect(tester.takeException(), isNull);
    expect(_width(tester, 'Hermes'), lessThan(60));
    expect(_paragraph(tester, 'Hermes').didExceedMaxLines, isFalse);
  });
}
