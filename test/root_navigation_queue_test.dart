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

  testWidgets('a replacement request reuses the outstanding route guard', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final canPop = ValueNotifier(false);
    var guardAttempts = 0;
    bool? waited;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: const Text('Home')),
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
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: canPop,
          builder: (_, allowed, _) => PopScope(
            canPop: allowed,
            onPopInvokedWithResult: (_, _) => guardAttempts++,
            child: const Scaffold(body: Text('Editing')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    queue.request((_) {});
    await tester.pump();
    expect(guardAttempts, 1);

    queue.cancel();
    queue.request((didWait) => waited = didWait);
    await tester.pump();

    expect(guardAttempts, 1);
    expect(waited, isNull);

    canPop.value = true;
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(waited, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });
}
