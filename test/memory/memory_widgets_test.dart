import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';

import 'memory_fixtures.dart';

void main() {
  testWidgets('list labels distinguish memory and user profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryView(
            entries: const [
              MemoryEntry(memoryId, 'Long memory', source: 'memory'),
              MemoryEntry('user', 'Preference', source: 'profile'),
            ],
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Agent notes'), findsOneWidget);
    expect(find.text('About you'), findsOneWidget);
  });

  testWidgets('full content remains inert selectable text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryView(
            detail: MemoryDetail(
              const MemoryEntry(memoryId, 'Long memory'),
              fullMemory,
            ),
            selected: const MemoryEntry(memoryId, 'Long memory'),
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.widgetWithText(SelectableText, fullMemory), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('unsupported and stale states offer refresh', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryView(
            failure: MemoryFailure.unsupported,
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text(MemoryFailure.unsupported.message), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryView(
            selected: const MemoryEntry(memoryId, 'Long memory'),
            failure: MemoryFailure.missing,
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text(MemoryFailure.missing.message), findsOneWidget);
  });
}
