import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/semantics.dart';

import 'accessibility_announcements.dart';

void main() {
  testWidgets('records announcements only, not tooltips or taps', (
    tester,
  ) async {
    final said = captureAnnouncements(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Tooltip(message: 'Hint', child: Text('Target')),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Target'));
    await tester.pumpAndSettle();
    expect(said, isEmpty);

    final context = tester.element(find.text('Target'));
    await SemanticsService.sendAnnouncement(
      View.of(context),
      'Hello',
      TextDirection.rtl,
    );
    expect(said, [(message: 'Hello', textDirection: 0)]);
  });
}
