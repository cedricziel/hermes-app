import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

ModelOptions _many(int count) => ModelOptions(
  providers: [
    ModelProviderOption(
      id: 'acme',
      label: 'Acme',
      models: [for (var i = 0; i < count; i++) ModelOption(id: 'model-$i')],
    ),
  ],
);

final _popover = find.byWidgetPredicate(
  (widget) =>
      widget is ModelPicker &&
      widget.presentation == ModelPickerPresentation.popover,
);

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
}) async {
  tester.view
    ..physicalSize = const Size(900, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = brightness == Brightness.dark
      ? buildHermesDarkTheme(platform: TargetPlatform.macOS)
      : buildHermesLightTheme(platform: TargetPlatform.macOS);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomLeft,
          child: Builder(
            builder: (context) => TextButton(
              key: const Key('opener'),
              onPressed: () {
                final box = context.findRenderObject()! as RenderBox;
                showModelPicker(
                  context,
                  options: _many(12),
                  selected: const ModelChoice('acme', 'model-1', effort: 'low'),
                  onChanged: (_) {},
                  anchor: box.localToGlobal(Offset.zero) & box.size,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('opener')));
  await tester.pumpAndSettle();
}

Material _surface(WidgetTester tester) => tester.widget<Material>(
  find.ancestor(of: _popover, matching: find.byType(Material)).first,
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('the popover has the raised surface a dialog has, '
        '${brightness.name}', (tester) async {
      await _pump(tester, brightness: brightness);
      final popover = _surface(tester).color;

      // What a Dialog under the same theme paints.
      final context = tester.element(find.byKey(const Key('opener')));
      // The popover is the open route: a tap outside closes it.
      await tester.tapAt(const Offset(850, 20));
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const Dialog(child: SizedBox(key: Key('d'))),
        ),
      );
      await tester.pumpAndSettle();
      final dialog = tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const Key('d')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      expect(popover, dialog);
      if (brightness == Brightness.dark) {
        expect(
          popover,
          isNot(Theme.of(context).colorScheme.surface),
          reason: 'in dark the page colour must not be the popover colour',
        );
      }
    });
  }

  testWidgets('the header, the list and the effort block are padded 20 from '
      'the popover edge', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    final surface = tester.getRect(
      find.ancestor(of: _popover, matching: find.byType(Material)).first,
    );
    final search = tester.getRect(find.byType(MacToolbarSearchField));
    final section = tester.getRect(find.byType(GroupedSection).first);
    final effort = tester.getRect(
      find.byWidgetPredicate((w) => w.key.toString().contains('effort-')).first,
    );

    expect(search.left - surface.left, 20);
    expect(surface.right - search.right, 20);
    expect(section.left - surface.left, 20);
    expect(surface.right - section.right, 20);
    expect(effort.left - surface.left, 20);
  });

  testWidgets('the search field is the shared Mac field, 26 pt tall, with '
      'the hint centred on it', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    final field = tester.getRect(find.byType(MacToolbarSearchField));
    final hint = tester.getRect(find.text('Search models'));
    final editable = tester.getRect(find.byType(EditableText));

    expect(field.height, 26);
    expect(editable.center.dy, closeTo(field.center.dy, 0.5));
    expect(hint.center.dy, closeTo(field.center.dy, 0.5));
  });
}
