import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

void main() {
  late ValueNotifier<bool> when;
  final answers = <bool>[];

  Future<void> pumpHost(WidgetTester tester) async {
    answers.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () async => answers.add(
                  await showConfirmDialog(
                    context,
                    title: 'Stop this agent?',
                    message: 'm',
                    confirmLabel: 'Stop',
                    destructive: true,
                    filled: false,
                    cancelIsDefault: true,
                    dismissWhen: when,
                  ),
                ),
                child: const Text('open'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('over')),
                  ),
                ),
                child: const Text('push'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('closes with false when the signal turns true', (tester) async {
    when = ValueNotifier(false);
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Stop this agent?'), findsOneWidget);
    when.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Stop this agent?'), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('a signal already true closes it at once', (tester) async {
    when = ValueNotifier(true);
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Stop this agent?'), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('a dialog under another route closes where it is, once', (
    tester,
  ) async {
    when = ValueNotifier(false);
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Another route above the dialog.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('over')),
      ),
    );
    await tester.pumpAndSettle();
    when.value = true;
    await tester.pumpAndSettle();
    expect(answers, [false]);
    expect(find.text('over'), findsOneWidget, reason: 'the top route stays');
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Stop this agent?'), findsNothing);
  });
}
