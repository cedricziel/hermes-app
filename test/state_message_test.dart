import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/state_message.dart';

void main() {
  testWidgets('shows the title and detail and runs the action', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StateMessage(
            icon: Icons.error_outline,
            title: 'Could not load',
            detail: 'The server did not answer.',
            action: FilledButton(
              onPressed: () => retried++,
              child: const Text('Retry'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('The server did not answer.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });
}
