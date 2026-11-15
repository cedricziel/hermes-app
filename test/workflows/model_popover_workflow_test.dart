import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';

import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

final _options = ModelOptions(
  providers: [
    ModelProviderOption(
      id: 'acme',
      label: 'Acme',
      models: [
        for (final id in [
          'atlas-1',
          'atlas-2',
          'atlas-mini',
          'borealis-large',
          'borealis-small',
          'cirrus-4',
          'cirrus-4-mini',
          'delta-2.1',
          'ember-xl',
          'flux-7',
        ])
          ModelOption(id: id),
      ],
    ),
  ],
);

/// A pill at the bottom or top of a Mac window that opens the picker on
/// itself, as the composer's does.
class _Host extends StatelessWidget {
  const _Host({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: top ? Alignment.topLeft : Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Builder(
          builder: (context) => TextButton(
            key: const Key('pill'),
            onPressed: () {
              final box = context.findRenderObject()! as RenderBox;
              showModelPicker(
                context,
                options: _options,
                selected: const ModelChoice('acme', 'atlas-mini'),
                onChanged: (_) {},
                anchor: box.localToGlobal(Offset.zero) & box.size,
              );
            },
            child: const Text('atlas-mini · High'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (name, brightness, top) in [
    ('light', Brightness.light, false),
    ('dark', Brightness.dark, false),
    ('flipped', Brightness.light, true),
  ]) {
    testWidgets('the Mac model popover, $name', (tester) async {
      final shots = ScreenshotRecorder('model-popover-$name');
      await pumpScreen(
        tester,
        shots,
        _Host(top: top),
        size: const Size(900, 760),
        brightness: brightness,
        platform: TargetPlatform.macOS,
      );
      await tester.tap(find.byKey(const Key('pill')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'checked-row-focused');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'arrow-down');
    });
  }
}
