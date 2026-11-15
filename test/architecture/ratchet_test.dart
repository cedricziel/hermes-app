import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'ratchet.dart';

void main() {
  final rule = Rule(
    id: 'arch.sample',
    message: 'use theBuildingBlock',
    scan: () => const {},
    locate: (path) => ['$path:3: bad()'],
  );

  group('checkRule', () {
    test('passes when counts match', () {
      expect(checkRule(rule, {'a.dart': 2}, {'a.dart': 2}), isEmpty);
      expect(checkRule(rule, {}, {}), isEmpty);
    });

    test('fails on a rise, with lines and the replacement', () {
      final failures = checkRule(rule, {'a.dart': 3}, {'a.dart': 2});
      expect(failures, hasLength(1));
      expect(failures.single, contains('allows 2'));
      expect(failures.single, contains('a.dart:3: bad()'));
      expect(failures.single, contains('use theBuildingBlock'));
    });

    test('fails on a file that is not listed', () {
      final failures = checkRule(rule, {'b.dart': 1}, {});
      expect(failures.single, contains('not in the baseline'));
    });

    test('fails on a fall with the exact edit', () {
      expect(
        checkRule(rule, {'a.dart': 1}, {'a.dart': 2}).single,
        contains('Lower arch.sample a.dart to 1'),
      );
      expect(
        checkRule(rule, {}, {'a.dart': 2}).single,
        contains('Remove the entry'),
      );
    });
  });

  group('lowered', () {
    test('only lowers and removes, never raises or adds', () {
      expect(
        lowered({'a': 1, 'b': 0, 'c': 9, 'new': 4}, {'a': 3, 'b': 2, 'c': 2}),
        {'a': 1, 'c': 2},
      );
    });
  });

  group('baseline file', () {
    test('round-trips and keeps the header', () {
      const text = '# header\n\narch.x:\n  b.dart: 2\n  a.dart: 1\n';
      final data = parseBaseline(text);
      expect(data, {
        'arch.x': {'a.dart': 1, 'b.dart': 2},
      });
      expect(
        serializeBaseline(baselineHeader(text), data),
        '# header\n\narch.x:\n  a.dart: 1\n  b.dart: 2\n',
      );
    });

    test('rejects a bad id and a non-positive count', () {
      expect(() => parseBaseline('foo.x:\n  a: 1\n'), throwsFormatException);
      expect(() => parseBaseline('arch.x:\n  a: 0\n'), throwsFormatException);
    });

    test('the checked-in baseline parses and lists existing files', () {
      final data = parseBaseline(File(baselinePath).readAsStringSync());
      for (final files in data.values) {
        for (final path in files.keys) {
          expect(File(path).existsSync(), isTrue, reason: '$path is gone');
        }
      }
    });
  });

  test('rule ids are namespaced', () {
    expect(
      () => Rule(id: 'nope', message: 'm', scan: () => const {}),
      throwsArgumentError,
    );
  });
}
