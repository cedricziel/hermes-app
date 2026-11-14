import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/state_message.dart';

void main() {
  testWidgets('shows the title and detail and runs the action', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StateMessage(
            icon: AppIcons.error,
            title: 'Could not load',
            detail: 'The server did not answer.',
            action: FilledButton(
              onPressed: () => retried++,
              child: const Text('Retry'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('The server did not answer.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('scrolls instead of overflowing when the text is too tall', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 300)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 300),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: StateMessage(
              title: 'Dieser Server bietet keine Tool-Einstellungen an.',
              detail: 'Ein Update von Hermes auf dem Server fügt sie hinzu.',
              action: OutlinedButton(
                onPressed: () {},
                child: const Text('Zurück'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Zurück'), 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays centered when there is room', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StateMessage(title: 'Empty')),
      ),
    );
    final centre = tester.getCenter(find.text('Empty'));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(centre.dy, closeTo(screen.height / 2, 30));
  });
}
