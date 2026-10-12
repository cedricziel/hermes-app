import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';

void main() {
  for (final error in [
    StateError('late failure'),
    const KanbanException('late plugin failure'),
  ]) {
    testWidgets('${error.runtimeType} does not use a disposed caller', (
      tester,
    ) async {
      final pending = Completer<void>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      late BuildContext callerContext;
      late Future<bool> action;

      Widget app({required bool showCaller}) => MaterialApp(
        home: ScaffoldMessenger(
          key: messengerKey,
          child: showCaller
              ? Scaffold(
                  body: Builder(
                    builder: (context) {
                      callerContext = context;
                      return TextButton(
                        onPressed: () {
                          action = runKanbanAction(
                            context,
                            () => pending.future,
                          );
                        },
                        child: const Text('Run action'),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );

      await tester.pumpWidget(app(showCaller: true));
      await tester.tap(find.text('Run action'));
      await tester.pumpWidget(app(showCaller: false));
      expect(callerContext.mounted, isFalse);

      pending.completeError(error);
      await expectLater(action, completion(isFalse));

      expect(messengerKey.currentState, isNotNull);
    });
  }
}
