import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/output_lines_tile.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  const lines = ['first line', 'second line'];

  testWidgets('is closed by default and opens on tap', (tester) async {
    await tester.pumpWidget(
      _host(const OutputLinesTile(label: 'Show output', lines: lines)),
    );
    expect(find.text('Show output'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('Show output'));
    await tester.pumpAndSettle();
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, 'first line\nsecond line');
    expect(text.style!.fontFamily, 'monospace');
  });

  testWidgets('initiallyOpen shows the lines at once', (tester) async {
    await tester.pumpWidget(
      _host(
        const OutputLinesTile(
          label: 'Show output',
          lines: lines,
          initiallyOpen: true,
        ),
      ),
    );
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('long lines and the largest text do not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OutputLinesTile(
          label: 'Show output',
          lines: [List.filled(40, 'verylongword').join(' ')],
          initiallyOpen: true,
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty lines open to an empty box', (tester) async {
    await tester.pumpWidget(
      _host(
        const OutputLinesTile(
          label: 'Show output',
          lines: [],
          initiallyOpen: true,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
