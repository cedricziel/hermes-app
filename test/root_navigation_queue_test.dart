import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/root_navigation_queue.dart';

void main() {
  testWidgets('a launch cannot replace an explicit request behind a guard', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final destination = ValueNotifier('Home');
    addTearDown(destination.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: destination,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    );
    final queue = RootNavigationQueue(
      navigator: navigator.currentState!,
      root: ModalRoute.of(tester.element(find.text('Home')))!,
      canNavigate: () => true,
    );
    addTearDown(queue.dispose);
    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Text('Editing')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    queue.request((_) => destination.value = 'New link');
    await tester.pumpAndSettle();
    queue.request((_) => destination.value = 'Old launch', isLaunch: true);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('New link'), findsOneWidget);
    expect(find.text('Old launch'), findsNothing);
  });
}
