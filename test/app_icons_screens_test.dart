import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';

import 'support/pump_on_platform.dart';

Future<void> _pumpComposer(WidgetTester tester, TargetPlatform platform) =>
    pumpOnPlatform(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ChatComposer(
          controller: TextEditingController(),
          onSend: (_) {},
          onAttach: () {},
          attachments: const [],
          onRemoveAttachment: (_) {},
          replying: false,
          queued: const [],
          onRemoveQueued: (_) {},
        ),
      ),
      platform: platform,
    );

void main() {
  testWidgets('the composer shows SF-style icons on iOS', (tester) async {
    await _pumpComposer(tester, TargetPlatform.iOS);

    expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
  });

  testWidgets('the composer keeps its Material icons on Android', (
    tester,
  ) async {
    await _pumpComposer(tester, TargetPlatform.android);

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.add), findsNothing);
  });

  testWidgets('the Kanban bulk bar shows SF-style icons on iOS', (
    tester,
  ) async {
    await pumpOnPlatform(
      tester,
      const SizedBox.shrink(),
      platform: TargetPlatform.iOS,
      bottom: KanbanBulkBar(
        selectedCount: 2,
        assignees: const ['coder'],
        onMove: (_) {},
        onAssign: (_) {},
        onPriority: (_) {},
        onEffort: (_) {},
        onArchive: () {},
      ),
    );

    expect(find.byIcon(CupertinoIcons.archivebox), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.flag), findsOneWidget);
    expect(find.byIcon(Icons.archive_outlined), findsNothing);
  });
}
