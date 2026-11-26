import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/rows_result.dart';

import 'support/rows_fixtures.dart';

RowsResult? _of(Object? answer, {String name = 'search_files'}) =>
    RowsResult.of(rowsCall(answer, name: name));

void main() {
  group('a list of rows', () {
    test('a list of flat maps is a table', () {
      final result = _of([
        {'id': 1, 'name': 'a', 'ok': true, 'note': null},
        {'id': 2, 'name': 'b', 'ok': false, 'note': 'x'},
      ], name: 'some_tool')!;
      expect(result.columns, ['id', 'name', 'ok', 'note']);
      expect(result.rows, hasLength(2));
      expect(result.unit, RowsUnit.rows);
    });

    test('a JSON text in result with no resultData is decoded', () {
      final result = RowsResult.of(
        rowsCall(null, name: 'some_tool', text: '[{"a":1},{"a":2}]'),
      );
      expect(result?.rows, hasLength(2));
    });

    test('a nested value is not a table', () {
      expect(
        _of([
          {
            'a': 1,
            'b': {'c': 2},
          },
        ], name: 'some_tool'),
        isNull,
      );
      expect(
        _of([
          {
            'a': [1],
          },
        ], name: 'some_tool'),
        isNull,
      );
    });

    test('a nested value in a later row is not a table', () {
      expect(
        _of([
          {'a': 1},
          {
            'a': {'deep': 1},
          },
        ], name: 'some_tool'),
        isNull,
      );
    });

    test('an empty list from another tool is not a table', () {
      expect(_of(<Object?>[], name: 'some_tool'), isNull);
    });

    test('a list that holds anything but maps is not a table', () {
      expect(_of(['a', 'b'], name: 'some_tool'), isNull);
      expect(
        _of([
          {'a': 1},
          'b',
        ], name: 'some_tool'),
        isNull,
      );
    });

    test('rows with no keys at all are not a table', () {
      expect(
        _of([<String, Object?>{}, <String, Object?>{}], name: 'some_tool'),
        isNull,
      );
    });

    test('the first row orders the columns and later keys join them', () {
      final result = _of([
        {'b': 1, 'a': 2},
        {'c': 3, 'a': 4},
      ], name: 'some_tool')!;
      expect(result.columns, ['b', 'a', 'c']);
    });

    test('at most eight columns show and the rest are counted', () {
      final result = _of([
        {for (var i = 0; i < 11; i++) 'c$i': i},
      ], name: 'some_tool')!;
      expect(result.columns, hasLength(8));
      expect(result.moreColumns, 3);
      expect(result.rows.single, hasLength(11));
    });

    test('a map with one large list of maps is a table', () {
      final result = _of({
        'count': 2,
        'items': [
          {'a': 1},
          {'a': 2},
        ],
      }, name: 'some_tool')!;
      expect(result.columns, ['a']);
      expect(result.rows, hasLength(2));
    });

    test('a map with two lists, or a nested map, is not a table', () {
      final list = [
        {'a': 1},
      ];
      expect(_of({'x': list, 'y': list}, name: 'some_tool'), isNull);
      expect(
        _of({
          'x': list,
          'meta': {'k': 1},
        }, name: 'some_tool'),
        isNull,
      );
    });

    test('a map with an error is not a table', () {
      expect(
        _of({
          'error': 'boom',
          'items': [
            {'a': 1},
          ],
        }, name: 'some_tool'),
        isNull,
      );
    });

    test('a map with no list of maps is not a table', () {
      expect(_of({'ok': true, 'count': 3}, name: 'some_tool'), isNull);
    });
  });

  group('search_files', () {
    test('matches with three rows is a table', () {
      final result = _of({'total_count': 3, 'matches': matchRows(3)})!;
      expect(result.columns, ['path', 'line', 'content']);
      expect(result.rows, hasLength(3));
      expect(result.unit, RowsUnit.matches);
    });

    test('a path-grouped matches_text of 12 matches becomes 12 rows', () {
      final result = _of(densifiedAnswer(manyMatches(12), totalCount: 12))!;
      expect(result.columns, ['path', 'line', 'content']);
      expect(result.rows, hasLength(12));
      expect(result.rows.first, {
        'path': 'lib/src/file_0.dart',
        'line': 1,
        'content': 'final value0 = 0;',
      });
      expect(result.rows.last['line'], 12);
      expect(result.unit, RowsUnit.matches);
    });

    test('the first row orders the columns', () {
      final result = _of({
        'total_count': 1,
        'matches': [
          {'content': 'x', 'line': 4, 'path': 'a.dart'},
        ],
      })!;
      expect(result.columns, ['content', 'line', 'path']);
    });

    test('a block with a stray line is not a table', () {
      final text = '${manyMatches(6)}\n  stray';
      expect(_of(densifiedAnswer(text, totalCount: 6)), isNull);
    });

    test('a row before any path line is not a table', () {
      expect(
        _of(densifiedAnswer('  1: orphan\nlib/a.dart', totalCount: 1)),
        isNull,
      );
    });

    test('a blank line inside the block is not a table', () {
      expect(
        _of(densifiedAnswer('lib/a.dart\n  1: a\n\n  2: b', totalCount: 2)),
        isNull,
      );
    });

    test('another matches_format is not a table', () {
      final answer = densifiedAnswer(manyMatches(6), totalCount: 6)
        ..['matches_format'] = 'grouped-by-file';
      expect(_of(answer), isNull);
    });

    test('a hit whose content holds CR or U+2028 still parses', () {
      final result = _of(
        densifiedAnswer(
          'lib/a.dart\n  1: tab\there\r\n  2: line\u2028break\n  3: ',
          totalCount: 3,
        ),
      )!;
      expect(result.rows[0]['content'], 'tab\there\r');
      expect(result.rows[1]['content'], 'line\u2028break');
      expect(result.rows[2]['content'], '');
    });

    test('a row with no space after the colon is not a table', () {
      expect(
        _of(densifiedAnswer('lib/a.dart\n  1: a\n  2:', totalCount: 2)),
        isNull,
      );
    });

    test('a path with spaces, colons and digits is a path line', () {
      final result = _of(
        densifiedAnswer('src/my dir/a: b.dart\n  7: x', totalCount: 1),
      )!;
      expect(result.rows.single['path'], 'src/my dir/a: b.dart');
    });

    test('a content that looks like a row stays content', () {
      final result = _of(
        densifiedAnswer('a.dart\n  3:   4: nested', totalCount: 1),
      )!;
      expect(result.rows.single['content'], '  4: nested');
    });

    test('{total_count: 0} is no matches', () {
      final result = _of({'total_count': 0})!;
      expect(result.rows, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('an empty matches list from search_files is no matches', () {
      expect(_of({'total_count': 0, 'matches': <Object?>[]})!.isEmpty, isTrue);
    });

    test('[] from another tool is not a table', () {
      expect(_of(<Object?>[], name: 'list_things'), isNull);
    });

    test('a files or counts answer falls back', () {
      expect(
        _of({
          'total_count': 2,
          'files': ['a.dart', 'b.dart'],
        }),
        isNull,
      );
      expect(
        _of({
          'total_count': 3,
          'counts': {'a.dart': 3},
        }),
        isNull,
      );
    });

    test('an error is not a table', () {
      expect(_of({'error': 'bad pattern'}), isNull);
    });

    test('an answer with a total but no rows at all falls back', () {
      expect(_of({'total_count': 4}), isNull);
    });

    test('matches that hold a nested value fall back', () {
      expect(
        _of({
          'total_count': 1,
          'matches': [
            {
              'path': 'a',
              'line': {'n': 1},
              'content': 'x',
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('notes', () {
    List<RowsNote> notes(Map<String, Object?> extra) =>
        _of({'total_count': 3, 'matches': matchRows(3), ...extra})!.notes;

    test('an ordinary answer has no note', () {
      expect(notes({}), isEmpty);
    });

    test('truncated with a lower bound says the search stopped early', () {
      final note = notes({
        'total_count': 212,
        'truncated': true,
        'total_count_is_lower_bound': true,
      }).single;
      expect(note.kind, RowsNoteKind.stoppedEarly);
      expect(note.count, 212);
    });

    test('truncated alone is no early stop', () {
      expect(notes({'total_count': 212, 'truncated': true}), isEmpty);
    });

    test('the total of a truncated search is kept', () {
      final result = _of({
        'total_count': 212,
        'truncated': true,
        'matches': matchRows(3),
      })!;
      expect(result.total, 212);
    });

    test('a total below the rows shown is ignored', () {
      expect(_of({'total_count': 1, 'matches': matchRows(3)})!.total, isNull);
    });

    test('_omitted gives the held-back note with Hermes\' words', () {
      final note = notes({
        '_omitted':
            '2 result(s) omitted because they target credential, token, '
            'cache, or secret-bearing environment files.',
      }).single;
      expect(note.kind, RowsNoteKind.heldBack);
      expect(note.count, 2);
      expect(note.text, contains('secret-bearing'));
    });

    test('_omitted without a number still shows as a note', () {
      final note = notes({'_omitted': 'some were left out'}).single;
      expect(note.kind, RowsNoteKind.heldBack);
      expect(note.count, isNull);
    });

    test('warning, limit_reason, _warning and _hint show as notes', () {
      final all = notes({
        'warning': 'be careful',
        'limit_reason': 'match limit',
        '_warning': 'repeated search',
        '_hint': 'try a narrower pattern',
      });
      expect(
        [for (final note in all) (note.kind, note.text)],
        containsAll([
          (RowsNoteKind.warning, 'be careful'),
          (RowsNoteKind.warning, 'match limit'),
          (RowsNoteKind.warning, 'repeated search'),
          (RowsNoteKind.hint, 'try a narrower pattern'),
        ]),
      );
    });

    test('a note on an empty search is kept', () {
      final result = _of({'total_count': 0, '_hint': 'widen the pattern'})!;
      expect(result.isEmpty, isTrue);
      expect(result.notes.single.kind, RowsNoteKind.hint);
    });
  });

  test('the result is parsed once per call', () {
    final call = rowsCall({'total_count': 3, 'matches': matchRows(3)});
    expect(identical(RowsResult.of(call), RowsResult.of(call)), isTrue);
  });
}
