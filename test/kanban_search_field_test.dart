import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';

import 'support/pump_on_platform.dart';

KanbanBoardToolbar _toolbar({ValueChanged<String>? onQuery}) =>
    KanbanBoardToolbar(
      assignees: const ['coder'],
      tenants: const [],
      includeArchived: false,
      wide: false,
      onQueryChanged: onQuery ?? (_) {},
      onAssigneeChanged: (_) {},
      onTenantChanged: (_) {},
      onIncludeArchivedChanged: (_) {},
    );

void main() {
  group('search field', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('is the standard search field on $platform', (tester) async {
        final queries = <String>[];
        await pumpOnPlatform(
          tester,
          _toolbar(onQuery: queries.add),
          platform: platform,
        );

        expect(find.byType(CupertinoSearchTextField), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.enterText(find.byType(CupertinoSearchTextField), 'keys');
        expect(queries, ['keys']);
      });
    }

    testWidgets('stays a Material field on Android', (tester) async {
      await pumpOnPlatform(
        tester,
        _toolbar(),
        platform: TargetPlatform.android,
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CupertinoSearchTextField), findsNothing);
    });
  });
}
