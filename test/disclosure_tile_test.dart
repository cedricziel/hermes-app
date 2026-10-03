import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';

import 'support/accessibility.dart';

void main() {
  testWidgets('says it is open when page storage restores it open', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: shown,
            builder: (context, show, _) => Column(
              children: [
                if (show)
                  const DisclosureTile(
                    key: PageStorageKey('section'),
                    title: Text('Section'),
                    children: [Text('Inside')],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();

    // A new tile under the same key reads its state back from page storage.
    shown.value = false;
    await tester.pump();
    shown.value = true;
    await tester.pumpAndSettle();

    expect(find.text('Inside'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Section')),
      disclosure('Section', open: true),
    );
    handle.dispose();
  });
}
