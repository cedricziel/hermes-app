import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/tool_result.dart';
import 'package:hermes_app/src/memory/memory_tool_outcome.dart';

import 'memory_tool_fixtures.dart';

MemoryToolOutcome? outcome(Object? result, [Map<String, Object?>? args]) =>
    MemoryToolOutcome.parse(args: args, result: result);

void main() {
  group('saved', () {
    test('reads the tab, the percentage and the saved text', () {
      final saved = outcome(savedResult, addArgs)!;
      expect(saved.kind, MemoryOutcomeKind.saved);
      expect(saved.tab, 'About you');
      expect(saved.percent, 66);
      expect(saved.blocks, [
        [(added: true, text: 'Prefers short answers')],
      ]);
    });

    test('drops the percentage when usage cannot be read', () {
      final saved = outcome({...savedResult, 'usage': 'unknown'}, addArgs)!;
      expect(saved.percent, isNull);
      expect(outcome({'success': true}, replaceArgs)!.percent, isNull);
    });

    test('target memory is Agent notes and defaults to it', () {
      expect(outcome(savedResult, replaceArgs)!.tab, 'Agent notes');
      expect(outcome({'success': true}, {'action': 'add'})!.tab, 'Agent notes');
    });
  });

  group('staged', () {
    test('needs a pending id of 8 hex characters', () {
      final staged = outcome(stagedResult, replaceArgs)!;
      expect(staged.kind, MemoryOutcomeKind.staged);
      expect(staged.pendingId, '1a2b3c4d');
      for (final bad in ['1A2B3C4D', '1a2b3c', '1a2b3c4d5', '', null, 5]) {
        expect(
          outcome({...stagedResult, 'pending_id': bad}, replaceArgs),
          isNull,
          reason: '$bad',
        );
      }
    });
  });

  group('full', () {
    test('reads X and Y from usage', () {
      final full = outcome(fullResult, replaceArgs)!;
      expect(full.kind, MemoryOutcomeKind.full);
      expect(full.used, '2,180');
      expect(full.limit, '2,200');
      expect(full.tab, 'Agent notes');
    });

    test('is not full without the Memory at prefix or a usage of X/Y', () {
      expect(outcome({...fullResult, 'error': 'Disk full'}), isNull);
      expect(outcome({...fullResult, 'usage': '98%'}), isNull);
      expect(outcome({...fullResult}..remove('usage')), isNull);
    });
  });

  test('any other result has no outcome', () {
    expect(outcome(otherErrorResult, addArgs), isNull);
    expect(outcome('plain text'), isNull);
    expect(outcome(null), isNull);
  });

  group('lines', () {
    test('add is one + line', () {
      expect(outcome(savedResult, addArgs)!.blocks.single.single.added, isTrue);
    });

    test('replace and patch read alike', () {
      for (final args in [replaceArgs, patchArgs]) {
        expect(outcome(stagedResult, args)!.blocks, [
          [
            (added: false, text: 'Uses tabs'),
            (added: true, text: 'Uses spaces'),
          ],
        ]);
      }
    });

    test('remove is one - line', () {
      expect(outcome(savedResult, removeArgs)!.blocks, [
        [(added: false, text: 'Uses tabs')],
      ]);
    });

    test('operations give one block each', () {
      expect(outcome(stagedResult, operationsArgs)!.blocks, [
        [(added: true, text: 'Likes tea')],
        [(added: false, text: 'Uses tabs'), (added: true, text: 'Uses spaces')],
        [(added: false, text: 'Lives in Berlin')],
      ]);
    });

    test('missing or malformed arguments leave no lines', () {
      expect(outcome(stagedResult)!.blocks, isEmpty);
      expect(
        outcome(stagedResult, {'operations': 'x', 'content': 5})!.blocks,
        isEmpty,
      );
    });
  });

  group('status', () {
    test('a full memory is a warning, only for the memory tool', () {
      expect(
        toolResultStatus(fullResult, name: 'memory'),
        ToolCallStatus.warning,
      );
      expect(toolResultStatus(fullResult), ToolCallStatus.error);
      expect(
        toolResultStatus(otherErrorResult, name: 'memory'),
        ToolCallStatus.error,
      );
      expect(
        toolResultStatus(savedResult, name: 'memory'),
        ToolCallStatus.completed,
      );
    });
  });
}
