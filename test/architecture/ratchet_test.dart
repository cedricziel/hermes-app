import 'dart:io';
import 'dart:isolate';

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

  group('parseBaseline shape', () {
    test('a rule key with no entries is empty', () {
      expect(parseBaseline('arch.x:\n'), {'arch.x': <String, int>{}});
      expect(
        serializeBaseline('# h', parseBaseline('# h\narch.x:\n')),
        '# h\n',
      );
    });

    test('a non-string key names its line', () {
      expect(
        () => parseBaseline('arch.x:\n  a.dart: 1\n  7: 1\n'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('line 3'),
          ),
        ),
      );
    });

    test('a backslash path is rejected', () {
      expect(
        () => parseBaseline('arch.x:\n  "lib\\\\a.dart": 1\n'),
        throwsFormatException,
      );
    });
  });

  group('registration', () {
    setUp(resetRegisteredRules);

    Rule named(String id) => Rule(id: id, message: 'm', scan: () => const {});

    test('a duplicate id within a list throws', () {
      expect(
        () => claimRuleIds('arch', [named('arch.a'), named('arch.a')]),
        throwsArgumentError,
      );
    });

    test('a duplicate id across registrations throws', () {
      claimRuleIds('arch', [named('arch.a')]);
      expect(
        () => claimRuleIds('arch', [named('arch.a')]),
        throwsArgumentError,
      );
    });

    test('an id outside the namespace throws', () {
      expect(
        () => claimRuleIds('arch', [named('style.a')]),
        throwsArgumentError,
      );
    });
  });

  test('orphanIds lists unclaimed ids of the namespace only', () {
    final baseline = {
      'arch.a': {'x': 1},
      'arch.gone': {'x': 1},
      'style.other': {'x': 1},
    };
    expect(orphanIds(baseline, 'arch', {'arch.a'}), ['arch.gone']);
  });

  test('the update drops empty rule ids and orphans, never adds', () {
    final dir = Directory.systemTemp.createTempSync('ratchet_update');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/baseline.yaml')
      ..writeAsStringSync(
        '# h\n\narch.a:\n  x.dart: 3\n\narch.gone:\n  y.dart: 1\n\n'
        'arch.empty:\n',
      );
    updateBaselineFile(file, (current) {
      current['arch.a'] = lowered({
        'x.dart': 1,
        'new.dart': 9,
      }, current['arch.a']!);
      for (final id in orphanIds(current, 'arch', {'arch.a'})) {
        current.remove(id);
      }
    });
    expect(file.readAsStringSync(), '# h\n\narch.a:\n  x.dart: 1\n');
  });

  test('concurrent writers lose no update', () async {
    final dir = Directory.systemTemp.createTempSync('ratchet_writers');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/baseline.yaml')
      ..writeAsStringSync('# header\n');
    await Future.wait([
      for (var w = 0; w < 6; w++)
        Isolate.run(() => _writer(file.path, 'arch.w$w', 8)),
    ]);
    final data = parseBaseline(file.readAsStringSync());
    expect(
      data.keys,
      unorderedEquals([for (var w = 0; w < 6; w++) 'arch.w$w']),
    );
    for (final files in data.values) {
      expect(files, {'p.dart': 8});
    }
    expect(dir.listSync().map((e) => e.path.split('/').last), [
      'baseline.yaml',
    ]);
  });

  test('rule ids are namespaced', () {
    expect(
      () => Rule(id: 'nope', message: 'm', scan: () => const {}),
      throwsArgumentError,
    );
  });
}

/// One writer: raises its own rule's count one at a time, each a locked
/// read-modify-write of the shared file.
void _writer(String path, String id, int times) {
  for (var i = 1; i <= times; i++) {
    updateBaselineFile(File(path), (current) {
      current[id] = {'p.dart': i};
    });
  }
}
