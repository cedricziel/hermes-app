import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';

import 'support/accessibility.dart';

void main() {
  final taps = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    List<String> profiles = const ['default'],
    bool update = false,
    bool busy = false,
    List<String> failed = const [],
  }) async {
    taps.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformHintPrompt(
            profiles: profiles,
            text: 'the note',
            update: update,
            busy: busy,
            failed: failed,
            onAdd: () => taps.add('add'),
            onLater: () => taps.add('later'),
            onNever: () => taps.add('never'),
          ),
        ),
      ),
    );
  }

  testWidgets('each button answers with its own choice', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add note'));
    await tester.tap(find.text('Not now'));
    await tester.tap(find.text("Don't ask again"));

    expect(taps, ['add', 'later', 'never']);
  });

  testWidgets('the add button names what it does', (tester) async {
    await pump(tester, profiles: ['default', 'work']);
    expect(find.text('Add to 2 profiles'), findsOneWidget);
    expect(find.text('default'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);

    await pump(tester, profiles: ['default', 'work'], update: true);
    expect(find.text('Update note'), findsOneWidget);

    await pump(tester, profiles: ['default', 'work'], failed: ['work']);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining("Couldn't save to work"), findsOneWidget);
  });

  testWidgets('a single profile is named in the sentence', (tester) async {
    await pump(tester);

    expect(find.textContaining('“default” profile'), findsOneWidget);
  });

  testWidgets('the note shows on request', (tester) async {
    await pump(tester);
    expect(find.text('the note'), findsNothing);

    await tester.tap(find.text('Show the note'));
    await tester.pumpAndSettle();

    expect(find.text('the note'), findsOneWidget);
  });

  testWidgets('no button answers while saving', (tester) async {
    await pump(tester, busy: true);

    await tester.tap(find.byKey(const ValueKey('platform-hint-add')));
    await tester.tap(find.text('Not now'));
    await tester.tap(find.text("Don't ask again"));

    expect(taps, isEmpty);
  });

  testWidgets('buttons and the disclosure have names', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    expect(tester.getSemantics(find.text('Add note')), namedButton('Add note'));
    expect(
      tester.getSemantics(find.text('Show the note')),
      disclosure('Show the note', open: false),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
