import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/widgets/voice_consent_row.dart';

import 'voice_call_widgets_support.dart';

void main() {
  testWidgets('shows the sentence and the switch, which toggles', (
    tester,
  ) async {
    var on = false;
    await pumpVoice(
      tester,
      StatefulBuilder(
        builder: (context, setState) => VoiceConsentRow(
          value: on,
          onChanged: (v) => setState(() => on = v),
        ),
      ),
    );
    expect(
      find.textContaining('Hermes sends each thing you say after a pause'),
      findsOneWidget,
    );
    expect(find.text('Send what I say automatically'), findsOneWidget);
    expect(find.text('Off again for the next call'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(on, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('the switch is named by its title', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVoice(tester, VoiceConsentRow(value: true, onChanged: (_) {}));
      expect(
        find.bySemanticsLabel(RegExp('Send what I say automatically')),
        findsWidgets,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wraps at 2x text without overflow', (tester) async {
    await pumpVoice(
      tester,
      VoiceConsentRow(value: false, onChanged: (_) {}),
      scale: 2,
      size: const Size(360, 1600),
    );
    expect(tester.takeException(), isNull);
  });
}
