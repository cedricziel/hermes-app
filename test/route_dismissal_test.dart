import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/route_dismissal.dart';

void main() {
  late GlobalKey<NavigatorState> navigator;
  late BuildContext pageContext;

  Future<void> openPage(WidgetTester tester) async {
    navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('List')),
      ),
    );
    navigator.currentState!.push<String>(
      MaterialPageRoute(
        builder: (context) {
          pageContext = context;
          return const Scaffold(body: Text('Details'));
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dismisses the current page with its result', (tester) async {
    await openPage(tester);
    String? result;
    final route = ModalRoute.of(pageContext)!;
    unawaited(route.popped.then((value) => result = value as String?));

    dismissRoute(pageContext, 'saved');
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
    expect(result, 'saved');
  });

  testWidgets('a completion closes its own page and preserves the overlay', (
    tester,
  ) async {
    await openPage(tester);
    String? result;
    unawaited(
      ModalRoute.of(pageContext)!.popped
          .then((value) => result = value as String?),
    );
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(title: Text('Overlay')),
      ),
    );
    await tester.pumpAndSettle();

    dismissRoute(pageContext, 'saved');
    await tester.pumpAndSettle();

    expect(find.text('Overlay'), findsOneWidget);
    expect(find.text('Details', skipOffstage: false), findsNothing);
    expect(result, 'saved');
  });

  testWidgets('a second dismissal during exit keeps the list', (tester) async {
    await openPage(tester);

    navigator.currentState!.pop();
    dismissRoute(pageContext);
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('a completion after disposal leaves the list alone', (
    tester,
  ) async {
    await openPage(tester);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    dismissRoute(pageContext);
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
