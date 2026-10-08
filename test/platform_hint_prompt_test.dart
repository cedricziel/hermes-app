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
    Set<String>? selected,
    Set<String> saved = const {},
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
            selected: selected,
            saved: saved,
            onToggle: (p, on) => taps.add('${on ? 'tick' : 'untick'} $p'),
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
    expect(find.text('Update 2 profiles'), findsOneWidget);

    await pump(tester, update: true);
    expect(find.text('Update note'), findsOneWidget);

    await pump(tester, profiles: ['default', 'work'], failed: ['work']);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining("Couldn't save to work"), findsOneWidget);
  });

  testWidgets('several profiles are a checklist', (tester) async {
    await pump(tester, profiles: ['default', 'work'], selected: {'default'});

    expect(find.text('Add to 1 profile'), findsOneWidget);
    await tester.tap(find.text('work'));
    await tester.tap(find.text('default'));
    expect(taps, ['tick work', 'untick default']);
  });

  testWidgets('a saved profile is locked and says so', (tester) async {
    await pump(
      tester,
      profiles: ['default', 'work'],
      failed: ['work'],
      saved: {'default'},
    );

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text("Couldn't save"), findsOneWidget);
    await tester.tap(find.text('default'));
    expect(taps, isEmpty);
  });

  testWidgets('nothing ticked leaves nothing to add', (tester) async {
    await pump(tester, profiles: ['default', 'work'], selected: {});

    await tester.tap(find.byKey(const ValueKey('platform-hint-add')));

    expect(taps, isEmpty);
  });

  testWidgets('a checkbox says whether it is ticked', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, profiles: ['default', 'work'], selected: {'work'});

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('platform-hint-profile-work')),
      ),
      isSemantics(label: 'work', isChecked: true, hasCheckedState: true),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('platform-hint-profile-default')),
      ),
      isSemantics(label: 'default', isChecked: false, hasCheckedState: true),
    );
    semantics.dispose();
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
