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

    popCurrentRoute(pageContext, 'saved');
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
    expect(result, 'saved');
  });

  testWidgets('a completion cannot dismiss an overlay above its page', (
    tester,
  ) async {
    await openPage(tester);
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(title: Text('Overlay')),
      ),
    );
    await tester.pumpAndSettle();

    popCurrentRoute(pageContext);
    await tester.pumpAndSettle();

    expect(find.text('Overlay'), findsOneWidget);
    expect(find.text('Details', skipOffstage: false), findsOneWidget);
  });

  testWidgets('a second dismissal during exit keeps the list', (tester) async {
    await openPage(tester);

    navigator.currentState!.pop();
    popCurrentRoute(pageContext);
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('a completion after disposal leaves the list alone', (
    tester,
  ) async {
    await openPage(tester);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    popCurrentRoute(pageContext);
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
