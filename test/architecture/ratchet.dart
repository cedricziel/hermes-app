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
///   baseline only shrinks;
/// - a baseline id in the registered namespace that no rule claims fails too.
///
/// With `UPDATE_BASELINE=1` the file is rewritten instead, lowering counts and
/// removing entries and orphan ids; it never raises a count or adds an entry.
/// The rewrite is locked and atomic, so test files may run in parallel; running
/// with `--concurrency=1` is still the tidier way.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
                '("$path: ${allowed[path]}") from $baselinePath (and the '
                '${rule.id} line if it was the last).'
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

/// Parses baseline text into rule id -> path -> count. Throws a
/// [FormatException] naming the line on a bad shape. A rule key with no
/// entries (`arch.x:`) is an empty map.
Map<String, Map<String, int>> parseBaseline(String text) {
  final doc = loadYaml(text);
  if (doc == null) return {};
  if (doc is! YamlMap) throw const FormatException('baseline is not a map');
  final out = <String, Map<String, int>>{};
  for (final rule in doc.nodes.entries) {
    final id = _key(rule.key, 'rule id');
    if (!_idPattern.hasMatch(id)) {
      throw FormatException('${_line(rule.key)}bad rule id "$id"');
    }
    final files = rule.value;
    if (files is YamlScalar && files.value == null) {
      out[id] = {};
      continue;
    }
    if (files is! YamlMap) {
      throw FormatException('${_line(files)}$id must map paths to counts');
    }
    final counts = <String, int>{};
    for (final file in files.nodes.entries) {
      final path = _key(file.key, 'path');
      if (path.contains(r'\')) {
        throw FormatException(
          '${_line(file.key)}$id: path "$path" must use / separators',
        );
      }
      final value = file.value;
      if (value is! YamlScalar ||
          value.value is! int ||
          (value.value as int) < 1) {
        throw FormatException(
          '${_line(value)}$id $path must be a positive integer',
        );
      }
      counts[path] = value.value as int;
    }
    out[id] = counts;
  }
  return out;
}

String _line(Object? node) =>
    node is YamlNode ? 'line ${node.span.start.line + 1}: ' : '';

String _key(Object? node, String what) {
  if (node is YamlScalar && node.value is String) return node.value as String;
  throw FormatException('${_line(node)}$what must be a string');
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

/// Baseline text: [header], then rules and paths in sorted order. A rule with
/// no entries is left out.
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

/// Baseline ids in [namespace] that are not in [registered].
List<String> orphanIds(
  Map<String, Map<String, int>> baseline,
  String namespace,
  Set<String> registered,
) => [
  for (final id in baseline.keys)
    if (id.startsWith('$namespace.') && !registered.contains(id)) id,
]..sort();

/// FNV-1a, the same in every process (`String.hashCode` is not).
String _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

/// Applies [change] to the baseline file under an exclusive lock and writes
/// the result through a temp file and a rename, so concurrent writers neither
/// interleave nor lose each other's edits.
void updateBaselineFile(
  File file,
  void Function(Map<String, Map<String, int>> current) change,
) {
  // A lock file, created exclusively: `RandomAccessFile.lock` does not
  // keep two isolates of one process apart. It lives in the system temp
  // directory, not in the repository, and is stolen when older than 30 s.
  final lock = File(
    '${Directory.systemTemp.path}/hermes_baseline_'
    '${_stableHash(file.absolute.path)}.lock',
  );
  final started = DateTime.now();
  while (true) {
    try {
      lock.createSync(exclusive: true);
      break;
    } on FileSystemException {
      if (DateTime.now().difference(started) > const Duration(seconds: 30)) {
        if (lock.existsSync()) lock.deleteSync();
        continue;
      }
      sleep(const Duration(milliseconds: 5));
    }
  }
  try {
    final text = file.readAsStringSync();
    final current = parseBaseline(text);
    change(current);
    final temp = File('${file.path}.tmp$pid');
    temp.writeAsStringSync(serializeBaseline(baselineHeader(text), current));
    temp.renameSync(file.path);
  } finally {
    if (lock.existsSync()) lock.deleteSync();
  }
}

/// Rule ids registered in this process, to reject a duplicate.
final _registered = <String>{};

/// Forgets the registered ids. Only for this library's own test.
@visibleForTesting
void resetRegisteredRules() => _registered.clear();

/// Checks [rules] are in [namespace] and that no id is repeated, here or in an
/// earlier registration in this process. Returns the ids.
Set<String> claimRuleIds(String namespace, List<Rule> rules) {
  final ids = <String>{};
  for (final rule in rules) {
    if (!rule.id.startsWith('$namespace.')) {
      throw ArgumentError('${rule.id} is not in the $namespace namespace');
    }
    if (!ids.add(rule.id) || _registered.contains(rule.id)) {
      throw ArgumentError('rule id ${rule.id} is registered twice');
    }
  }
  _registered.addAll(ids);
  return ids;
}

/// Registers one test per rule of [namespace] (`arch`, `style` or `test`),
/// and one test that no baseline entry in that namespace names a rule nobody
/// registered. In update mode (`UPDATE_BASELINE=1`) the baseline is lowered
/// instead of failing on a fall, and orphan ids are removed; a rise still
/// fails. A rule id registered twice throws.
void ratchetTests(List<Rule> rules, {required String namespace}) {
  final update = Platform.environment['UPDATE_BASELINE'] == '1';
  final file = File(baselinePath);
  final baseline = parseBaseline(file.readAsStringSync());
  final rewritten = <String, Map<String, int>>{};
  final ids = claimRuleIds(namespace, rules);

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

  final orphans = orphanIds(baseline, namespace, ids);
  test('$namespace baseline names only registered rules', () {
    if (update) return;
    expect(
      orphans,
      isEmpty,
      reason:
          'remove ${orphans.join(', ')} from $baselinePath: no $namespace '
          'rule has that id',
    );
  });

  if (update) {
    tearDownAll(() {
      updateBaselineFile(file, (current) {
        current.addAll(rewritten);
        for (final id in orphans) {
          current.remove(id);
        }
      });
    });
  }
}
