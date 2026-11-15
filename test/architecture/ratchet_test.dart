import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'ratchet.dart';

/// Namespaces that have a baseline file checked in.
List<String> checkedInNamespaces() {
  final dir = Directory(baselineDir);
  if (!dir.existsSync()) return const [];
  return [
    for (final f in dir.listSync())
      if (f is File && f.path.endsWith('.yaml'))
        f.path.split('/').last.replaceAll('.yaml', ''),
  ]..sort();
}

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

    test('the checked-in baseline files parse and list existing files', () {
      for (final ns in checkedInNamespaces()) {
        final data = parseBaseline(
          File(baselinePathFor(ns)).readAsStringSync(),
        );
        for (final entry in data.entries) {
          expect(
            entry.key,
            startsWith('$ns.'),
            reason: '$ns.yaml: ${entry.key}',
          );
          for (final path in entry.value.keys) {
            expect(File(path).existsSync(), isTrue, reason: '$path is gone');
          }
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
    final file = File('${dir.path}/arch.yaml')
      ..writeAsStringSync(
        '# h\n\narch.a:\n  x.dart: 3\n\narch.gone:\n  y.dart: 1\n\n'
        'arch.empty:\n',
      );
    final text = file.readAsStringSync();
    final current = parseBaseline(text);
    current['arch.a'] = lowered({
      'x.dart': 1,
      'new.dart': 9,
    }, current['arch.a']!);
    for (final id in orphanIds(current, 'arch', {'arch.a'})) {
      current.remove(id);
    }
    writeFileAtomically(file, serializeBaseline(baselineHeader(text), current));
    expect(file.readAsStringSync(), '# h\n\narch.a:\n  x.dart: 1\n');
    expect(dir.listSync().map((e) => e.path.split('/').last), ['arch.yaml']);
  });

  group('one registration per namespace', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('ratchet_reg'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String name, String body) =>
        File('${root.path}/$name').writeAsStringSync(body);

    Registrations scan() => findRegistrations([root]);

    test('finds the namespace literal, in either quote style', () {
      write(
        'a_test.dart',
        "void main() => ratchetTests(r, namespace: 'arch');",
      );
      write(
        'b_test.dart',
        'void main() => ratchetTests(r, namespace: "style");',
      );
      final found = scan();
      expect(found.problems, isEmpty);
      expect(found.byNamespace.keys, unorderedEquals(['arch', 'style']));
    });

    test('a semicolon inside the rule list does not cut the arguments', () {
      write(
        'a_test.dart',
        'void main() {\n'
            '  ratchetTests([\n'
            "    Rule(id: 'arch.a', message: 'm', scan: () { var x = 1; return {}; }),\n"
            "  ], namespace: 'arch');\n"
            '}\n',
      );
      final found = scan();
      expect(found.problems, isEmpty);
      expect(found.byNamespace.keys, ['arch']);
    });

    test('comments never count', () {
      write(
        'a_test.dart',
        "// ratchetTests(r, namespace: 'arch');\n"
            "/* ratchetTests(r, namespace: 'arch');\n */\n",
      );
      final found = scan();
      expect(found.problems, isEmpty);
      expect(found.byNamespace, isEmpty);
    });

    test('a helper wrapper outside a *_test.dart file fails', () {
      write('helper.dart', "void reg() => ratchetTests(r, namespace: 'arch');");
      expect(scan().problems.single, contains('outside a *_test.dart'));
    });

    test('a namespace that is not a literal fails', () {
      write(
        'a_test.dart',
        "const ns = 'arch';\nvoid main() => ratchetTests(r, namespace: ns);",
      );
      final problems = scan().problems;
      expect(problems.single, contains('not a string literal'));
      expect(
        problems.single,
        contains('exactly one *_test.dart per namespace'),
      );
    });

    test('an unknown namespace fails', () {
      write(
        'a_test.dart',
        "void main() => ratchetTests(r, namespace: 'nope');",
      );
      expect(scan().problems.single, contains('unknown namespace'));
    });

    test('a namespace in two files fails', () {
      write(
        'a_test.dart',
        "void main() => ratchetTests(r, namespace: 'arch');",
      );
      write(
        'b_test.dart',
        'void main() {\n  ratchetTests(\n    r,\n    namespace: "arch",\n  );\n}',
      );
      final problems = checkRegistrations(scan(), ['arch']);
      expect(problems.single, contains('registered 2 times'));
    });

    test('a baseline file with no registering file fails', () {
      final problems = checkRegistrations(Registrations(), ['style']);
      expect(problems.single, contains('baseline/style.yaml has no test file'));
    });

    test('a second call per namespace is refused', () {
      resetRegisteredRules();
      claimNamespace('arch');
      expect(() => claimNamespace('arch'), throwsArgumentError);
      expect(() => claimNamespace('nope'), throwsArgumentError);
    });
  });

  test('every ratchetTests call is exact and every baseline file is used', () {
    final problems = checkRegistrations(
      findRegistrations([Directory('test'), Directory('lib')]),
      checkedInNamespaces(),
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('rule ids are namespaced', () {
    expect(
      () => Rule(id: 'nope', message: 'm', scan: () => const {}),
      throwsArgumentError,
    );
  });
}
