import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/memory/memory_screen.dart';
import 'package:hermes_app/src/memory/memory_usage.dart';
import 'package:hermes_app/src/memory/widgets/memory_entry_editor.dart';
import 'package:hermes_app/src/memory/widgets/memory_entry_list.dart';
import 'package:hermes_app/src/memory/widgets/memory_fill_bar.dart';

import 'memory_fixtures.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

MemoryUsage _usage(List<int> sizes, {int? limit, bool lowerBound = false}) =>
    MemoryUsage.of(
      [for (final size in sizes) 'x' * size],
      limit: limit,
      lowerBound: lowerBound,
    );

void main() {
  const warning =
      'Hermes has to shorten or remove entries before it can add one';

  group('MemoryFillBar', () {
    testWidgets('says how many characters of the limit are used', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(MemoryFillBar(usage: _usage([300, 300, 306], limit: 1375))),
      );
      expect(find.text('912 of 1,375 characters'), findsOneWidget);
      expect(find.text('3 entries'), findsOneWidget);
      expect(find.textContaining(warning), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(912 / 1375, 0.001),
      );
    });

    testWidgets('warns from 95% of the limit', (tester) async {
      await tester.pumpWidget(
        _app(MemoryFillBar(usage: _usage([2100], limit: 2200))),
      );
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);
      expect(find.textContaining(warning), findsOneWidget);
    });

    testWidgets('has no bar or warning without a limit', (tester) async {
      await tester.pumpWidget(_app(MemoryFillBar(usage: _usage([2100]))));
      expect(find.text('2,100 characters'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining(warning), findsNothing);
    });

    testWidgets('a lower bound says at least', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryFillBar(usage: _usage([1200], limit: 1375, lowerBound: true)),
        ),
      );
      expect(find.text('at least 1,200 of 1,375 characters'), findsOneWidget);
    });
  });

  group('MemoryEntryList', () {
    testWidgets('lists entries by their text only', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryEntryList(
            usage: _usage([5, 5], limit: 100),
            entries: const ['Prefers metric units', 'Lives in Berlin'],
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text('Prefers metric units'), findsOneWidget);
      expect(find.text('Lives in Berlin'), findsOneWidget);
      expect(find.textContaining('Hermes reads these notes'), findsOneWidget);
      expect(find.text('Nothing remembered yet'), findsNothing);
    });

    testWidgets('an empty file says nothing is remembered yet', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryEntryList(
            usage: _usage([], limit: 1375),
            entries: const [],
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text('Nothing remembered yet'), findsOneWidget);
      expect(find.textContaining('Remember that I prefer'), findsOneWidget);
      expect(find.text('0 of 1,375 characters'), findsOneWidget);
    });
  });

  group('MemoryEntryEditor', () {
    Widget editor({bool editing = true, String draft = 'x', int? left = 463}) =>
        _app(
          MemoryEntryEditor(
            tab: MemoryTab.aboutYou,
            editing: editing,
            draft: draft,
            left: left,
            onChanged: (_) {},
            onEdit: () {},
            onSave: () {},
            onCancel: () {},
            onDelete: () {},
            onCheck: () {},
          ),
        );

    testWidgets('counts the draft and what is left in the file', (
      tester,
    ) async {
      await tester.pumpWidget(editor(draft: 'x' * 91));
      expect(find.text('91 characters'), findsOneWidget);
      expect(find.text('463 left in About you'), findsOneWidget);
      expect(find.textContaining('Used from the next chat'), findsOneWidget);
      expect(
        find.textContaining('already open keep the memory'),
        findsOneWidget,
      );
      expect(find.text('Delete entry'), findsOneWidget);
    });

    testWidgets('says how far over the limit a draft is', (tester) async {
      await tester.pumpWidget(editor(left: -1137));
      expect(find.text('1,137 over the limit in About you'), findsOneWidget);
    });

    testWidgets('shows no budget when the limit is unknown', (tester) async {
      await tester.pumpWidget(editor(left: null));
      expect(find.textContaining('left in'), findsNothing);
      expect(find.textContaining('over the limit'), findsNothing);
    });
  });

  group('MemoryView', () {
    testWidgets('names the file and place of the open entry', (tester) async {
      const entry = MemoryEntry(memoryId, 'Long memory');
      await tester.pumpWidget(
        _app(
          MemoryView(
            detail: MemoryDetail(entry, fullMemory),
            selected: entry,
            place: 'Entry 2 of 4 in About you (USER.md)',
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text('Entry 2 of 4 in About you (USER.md)'), findsOneWidget);
    });

    testWidgets('full content remains inert selectable text', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryView(
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
      );
      expect(find.widgetWithText(SelectableText, fullMemory), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('unsupported and stale states offer refresh', (tester) async {
      await tester.pumpWidget(
        _app(
          MemoryView(
            failure: MemoryFailure.unsupported,
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text(MemoryFailure.unsupported.message), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Nothing remembered yet'), findsNothing);
      await tester.pumpWidget(
        _app(
          MemoryView(
            selected: const MemoryEntry(memoryId, 'Long memory'),
            failure: MemoryFailure.missing,
            onOpen: (_) {},
            onRefresh: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.text(MemoryFailure.missing.message), findsOneWidget);
    });
  });
}
