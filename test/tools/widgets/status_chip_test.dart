import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';

import 'pump_tools.dart';

void main() {
  const words = {
    ToolsStatus.ready: 'Ready',
    ToolsStatus.needsKey: 'Needs a key',
    ToolsStatus.needsSignIn: 'Needs a sign-in on the server',
    ToolsStatus.needsInstall: 'Needs install',
    ToolsStatus.needsSetup: 'Needs setup',
    ToolsStatus.unusable: "Can't be used",
  };

  for (final MapEntry(key: status, value: text) in words.entries) {
    testWidgets('$status shows an icon and the words "$text"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTools(tester, StatusChip(status));
      expect(find.text(text), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(tester.getSemantics(find.byType(StatusChip)).label, text);
      handle.dispose();
    });
  }

  test('every status has its own icon', () {
    final icons = {for (final s in ToolsStatus.values) s.icon.material};
    expect(icons.length, ToolsStatus.values.length);
  });

  test('an unknown provider status reads as needs setup', () {
    expect(
      ToolsStatus.fromProvider(ToolsetProviderStatus.parse('from-the-future')),
      ToolsStatus.needsSetup,
    );
    expect(
      ToolsStatus.fromBackend(BackendStatus.parse('weird')),
      ToolsStatus.unusable,
    );
  });

  testWidgets('long words wrap at the largest text size', (tester) async {
    await pumpTools(
      tester,
      const SizedBox(width: 200, child: StatusChip(ToolsStatus.needsSignIn)),
      textScale: 3,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.text('Needs a sign-in on the server')).width,
      lessThanOrEqualTo(200),
    );
  });

  testWidgets('German words', (tester) async {
    await pumpTools(
      tester,
      const StatusChip(ToolsStatus.needsKey),
      locale: const Locale('de'),
    );
    expect(find.text('Braucht einen Schlüssel'), findsOneWidget);
  });
}
