import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';

const _title = 'Persönlichkeit und Charakter des Agenten';

Widget _app({
  required TargetPlatform platform,
  required TextDirection direction,
  required double scale,
  required String label,
  required VoidCallback onSave,
  bool cancel = false,
}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  builder: (context, child) => Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScaffold(
                title: _title,
                cancel: cancel,
                formAction: SettingsFormAction(
                  key: const Key('save'),
                  label: label,
                  onPressed: onSave,
                ),
                body: const Text('body'),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final direction in TextDirection.values) {
      for (final label in ['Save', 'Speichern']) {
        for (final cancel in [false, true]) {
          testWidgets('keeps the form action on screen at 3x text: '
              '${platform.name} ${direction.name} $label cancel=$cancel', (
            tester,
          ) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            var saved = 0;
            await tester.pumpWidget(
              _app(
                platform: platform,
                direction: direction,
                scale: 3,
                label: label,
                cancel: cancel,
                onSave: () => saved++,
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();

            final save = find.byKey(const Key('save'));
            expect(save, findsOneWidget);
            final rect = tester.getRect(save);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(find.text(label), findsOneWidget);
            final labelRect = tester.getRect(find.text(label));
            expect(labelRect.left, greaterThanOrEqualTo(0));
            expect(labelRect.right, lessThanOrEqualTo(320));

            await tester.tap(save);
            expect(saved, 1);
          });
        }
      }
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets('the collapsed iOS back button stays tappable and named '
        '(${direction.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.iOS,
          direction: direction,
          scale: 3,
          label: 'Speichern',
          onSave: () {},
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Chat'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
      final back = find.bySemanticsLabel('Chat');
      final target = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(InkResponse),
      );
      expect(target, findsOneWidget);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      final node = tester.getSemantics(back);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.rect.size, const Size(44, 44));
      tester.semantics.tap(find.semantics.byLabel('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('the collapsed Cancel icon has a tap action that closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.iOS,
        direction: TextDirection.ltr,
        scale: 3,
        label: 'Save',
        onSave: () {},
        cancel: true,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancel = find.bySemanticsLabel('Cancel');
    expect(cancel, findsOneWidget);
    final node = tester.getSemantics(cancel);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.rect.size, const Size(44, 44));
    tester.semantics.tap(find.semantics.byLabel('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an empty previous title still names the collapsed back button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    leading: const AdaptiveBackButton(previousTitle: ''),
                    leadingWidth: 52,
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('at normal text the iOS back button still shows its label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.iOS,
        direction: TextDirection.ltr,
        scale: 1,
        label: 'Save',
        onSave: () {},
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Chat'), findsOneWidget);
  });
}
