import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tab_to.dart';

void main() {
  Widget host() => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          TextButton(onPressed: () {}, child: const Text('One')),
          TextButton(onPressed: () {}, child: const Text('Two')),
          const TextButton(onPressed: null, child: Text('Off')),
        ],
      ),
    ),
  );

  testWidgets('tabTo moves the focus by Tab to the control inside the finder', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tabTo(tester, find.widgetWithText(TextButton, 'Two'));
    final focus = FocusManager.instance.primaryFocus!.context!;
    final two = tester.element(find.widgetWithText(TextButton, 'Two'));
    var inside = false;
    focus.visitAncestorElements((e) {
      inside = identical(e, two);
      return !inside;
    });
    expect(inside, isTrue, reason: 'the focus is inside the second button');
  });

  testWidgets('tabTo accepts a finder that matches the focused Focus itself', (
    tester,
  ) async {
    const key = ValueKey('focus');
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('One')),
            const Focus(key: key, child: Text('Reachable')),
          ],
        ),
      ),
    );
    await tabTo(tester, find.byKey(key));
    expect(
      identical(
        FocusManager.instance.primaryFocus!.context,
        tester.element(find.byKey(key)),
      ),
      isTrue,
    );
  });

  testWidgets('tabTo fails with a message when Tab never reaches it', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    TestFailure? failure;
    try {
      await tabTo(tester, find.widgetWithText(TextButton, 'Off'), maxTabs: 5);
    } on TestFailure catch (e) {
      failure = e;
    }
    expect(failure, isNotNull, reason: 'a control Tab cannot reach fails');
    expect(failure!.message, contains('Tab did not reach'));
    expect(failure.message, contains('5 presses'));
  });
}
