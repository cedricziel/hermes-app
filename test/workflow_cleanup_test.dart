import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/workflow_app.dart';

void main() {
  testWidgets('socket cleanup drains a timeout started by another timeout', (
    tester,
  ) async {
    var finished = false;
    Timer(const Duration(seconds: 30), () {
      Timer(const Duration(seconds: 15), () => finished = true);
    });

    await letSocketsIdle(tester);

    expect(finished, isTrue);
  });
}
