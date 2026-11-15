/// A shrink-only baseline for source-scan guards.
///
/// A [Rule] is an id, a scan that returns violations per repo-relative path,
/// and a message that names the building block to use instead. [ratchetTests]
/// registers one test per rule, comparing the scan with
/// `test/architecture/baseline.yaml`:
///
/// - more violations in a file than its entry (or a file with no entry) fails
///   with the offending lines and the message;
/// - fewer violations than the entry fails with the exact edit to make, so the
///   baseline only shrinks.
///
/// With `UPDATE_BASELINE=1` the file is rewritten instead, lowering counts and
/// removing entries; it never raises a count or adds an entry. Run it with
/// `--concurrency=1` when several test files register rules, since each one
/// rewrites the same file.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Where the baseline lives, relative to the repository root.
const baselinePath = 'test/architecture/baseline.yaml';

final _idPattern = RegExp(r'^(arch|style|test)\.[A-Za-z0-9_.-]+$');

/// One guarded rule.
class Rule {
  Rule({
    required this.id,
    required this.message,
    required this.scan,
    this.locate,
  }) {
    if (!_idPattern.hasMatch(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'a rule id is arch.<name>, style.<name> or test.<name>',
      );
    }
  }

  /// `arch.<name>`, `style.<name>` or `test.<name>`.
  final String id;

  /// What to do instead: names the building block to use.
  final String message;

  /// Violations per repo-relative path (paths with none may be left out).
  final Map<String, int> Function() scan;

  /// The offending lines of one file, as `path:line: text`, for the failure.
  final List<String> Function(String path)? locate;
}

/// The failures of one rule: [actual] against its [allowed] baseline entry.
List<String> checkRule(
  Rule rule,
  Map<String, int> actual,
  Map<String, int> allowed,
) {
  final failures = <String>[];
  for (final path in (actual.keys.toList()..sort())) {
    final found = actual[path]!;
    if (found <= 0) continue;
    final base = allowed[path];
    if (base != null && found <= base) continue;
    final lines = rule.locate?.call(path) ?? const <String>[];
    failures.add(
      '${rule.id}: $path has $found, '
      '${base == null ? 'not in the baseline' : 'the baseline allows $base'}.\n'
      '${lines.map((l) => '  $l\n').join()}'
      '  Instead: ${rule.message}',
    );
  }
  for (final path in (allowed.keys.toList()..sort())) {
    final found = actual[path] ?? 0;
    if (found >= allowed[path]!) continue;
    failures.add(
      found == 0
          ? '${rule.id}: $path is clean now. Remove the entry '
                '("$path: ${allowed[path]}") from $baselinePath.'
          : '${rule.id}: $path went down. Lower ${rule.id} $path to $found '
                'in $baselinePath.',
    );
  }
  return failures;
}

/// [allowed] lowered to [actual]: counts that fell, entries that went to 0
/// removed. Never raises a count and never adds a path.
Map<String, int> lowered(Map<String, int> actual, Map<String, int> allowed) {
  final out = <String, int>{};
  for (final entry in allowed.entries) {
    final found = actual[entry.key] ?? 0;
    final count = found < entry.value ? found : entry.value;
    if (count > 0) out[entry.key] = count;
  }
  return out;
}

/// Parses baseline text into rule id -> path -> count. Throws on a bad shape.
Map<String, Map<String, int>> parseBaseline(String text) {
  final doc = loadYaml(text);
  if (doc == null) return {};
  if (doc is! YamlMap) throw const FormatException('baseline is not a map');
  final out = <String, Map<String, int>>{};
  for (final rule in doc.entries) {
    final id = rule.key as String;
    final files = rule.value;
    if (!_idPattern.hasMatch(id)) {
      throw FormatException('bad rule id "$id" in the baseline');
    }
    if (files is! YamlMap) {
      throw FormatException('$id must map paths to counts');
    }
    out[id] = {
      for (final file in files.entries)
        file.key as String: _count(id, file.key, file.value),
    };
  }
  return out;
}

int _count(String id, Object? path, Object? value) {
  if (value is int && value > 0) return value;
  throw FormatException('$id $path must be a positive integer, got $value');
}

/// The file's leading comment block (up to the first non-comment line).
String baselineHeader(String text) {
  final header = <String>[];
  for (final line in text.split('\n')) {
    if (line.startsWith('#') || line.trim().isEmpty) {
      header.add(line);
    } else {
      break;
    }
  }
  while (header.isNotEmpty && header.last.trim().isEmpty) {
    header.removeLast();
  }
  return header.join('\n');
}

/// Baseline text: [header], then rules and paths in sorted order.
String serializeBaseline(String header, Map<String, Map<String, int>> data) {
  final b = StringBuffer(header);
  if (header.isNotEmpty) b.write('\n');
  for (final id in (data.keys.toList()..sort())) {
    final files = data[id]!;
    if (files.isEmpty) continue;
    b.write('\n$id:\n');
    for (final path in (files.keys.toList()..sort())) {
      b.write('  $path: ${files[path]}\n');
    }
  }
  return b.toString();
}

/// Registers one test per rule. In update mode (`UPDATE_BASELINE=1`) it lowers
/// the baseline instead of failing on a fall; a rise still fails.
void ratchetTests(List<Rule> rules) {
  final update = Platform.environment['UPDATE_BASELINE'] == '1';
  final file = File(baselinePath);
  final baseline = parseBaseline(file.readAsStringSync());
  final rewritten = <String, Map<String, int>>{};

  for (final rule in rules) {
    test(rule.id, () {
      final actual = rule.scan();
      final allowed = baseline[rule.id] ?? const <String, int>{};
      var failures = checkRule(rule, actual, allowed);
      if (update) {
        rewritten[rule.id] = lowered(actual, allowed);
        failures = failures
            .where(
              (f) =>
                  !f.contains(' is clean now.') && !f.contains(' went down.'),
            )
            .toList();
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  if (update) {
    tearDownAll(() {
      final text = file.readAsStringSync();
      final current = parseBaseline(text);
      current.addAll(rewritten);
      file.writeAsStringSync(serializeBaseline(baselineHeader(text), current));
    });
  }
}
