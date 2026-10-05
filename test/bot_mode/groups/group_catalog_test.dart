import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../widgetbook/group_use_cases.dart';

import 'package:widgetbook/widgetbook.dart';

import '../../../widgetbook/environment.dart';

void main() {
  final cases = groupUiNode().children!.cast<WidgetbookUseCase>();
  for (final useCase in cases) {
    for (final theme in themes.entries) {
      for (final viewport in [phone, desktop]) {
        testWidgets(
          'group catalog ${useCase.name}: ${theme.key} ${viewport.name}',
          (tester) async {
            tester.view.physicalSize = viewport.size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: theme.value,
                home: Scaffold(body: Builder(builder: useCase.builder)),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
