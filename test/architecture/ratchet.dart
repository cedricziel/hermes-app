/// A shrink-only baseline for source-scan guards.
///
/// A [Rule] is an id (`arch.<name>`, `style.<name>` or `test.<name>`), a scan
/// that returns violations per repo-relative path, and a message that names
/// the building block to use instead.
///
/// Each namespace has one baseline file, `test/architecture/baseline/<ns>.yaml`
/// (rule id -> path -> allowed count), and exactly one test file that calls
/// `ratchetTests(rules, namespace: '<ns>')`, so a baseline file has one writer.
/// [ratchetTests] registers one test per rule, comparing the scan with the
/// file:
///
/// - more violations in a file than its entry (or a file with no entry) fails
///   with the offending lines and the message;
/// - fewer violations than the entry fails with the exact edit to make, so the
///   baseline only shrinks;
/// - a baseline id that none of the namespace's rules claims fails too.
///
/// With `UPDATE_BASELINE=1` the file is rewritten instead, lowering counts and
/// removing entries, empty rule ids and orphan ids; it never raises a count or
/// adds an entry. The rewrite goes through a temp file in the same directory
/// and a rename.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The directory of the baseline files, relative to the repository root.
const baselineDir = 'test/architecture/baseline';

/// The baseline file of [namespace].
String baselinePathFor(String namespace) => '$baselineDir/$namespace.yaml';

const namespaces = ['arch', 'style', 'test'];

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
  final baselinePath = baselinePathFor(rule.id.split('.').first);
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

/// Writes [text] to [file] through a temp file in the same directory and a
/// rename, so a reader never sees half a file.
void writeFileAtomically(File file, String text) {
  final temp = File('${file.path}.tmp$pid');
  try {
    temp.writeAsStringSync(text);
    temp.renameSync(file.path);
  } finally {
    if (temp.existsSync()) temp.deleteSync();
  }
}

/// Namespaces and rule ids registered in this process, to reject a repeat.
final _registered = <String>{};
final _claimedNamespaces = <String>{};

/// Forgets what was registered. Only for this library's own test.
@visibleForTesting
void resetRegisteredRules() {
  _registered.clear();
  _claimedNamespaces.clear();
}

/// Throws on an unknown namespace, or one already registered in this process.
void claimNamespace(String namespace) {
  if (!namespaces.contains(namespace)) {
    throw ArgumentError('unknown namespace $namespace');
  }
  if (!_claimedNamespaces.add(namespace)) {
    throw ArgumentError('ratchetTests($namespace) was called twice');
  }
}

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
/// and one test that no baseline entry names a rule nobody registered. Call
/// it once per namespace, from one test file. In update mode
/// (`UPDATE_BASELINE=1`) the baseline is lowered instead of failing on a
/// fall, and orphan ids are removed; a rise still fails.
void ratchetTests(List<Rule> rules, {required String namespace}) {
  claimNamespace(namespace);
  final update = Platform.environment['UPDATE_BASELINE'] == '1';
  final file = File(baselinePathFor(namespace));
  final baseline = file.existsSync()
      ? parseBaseline(file.readAsStringSync())
      : <String, Map<String, int>>{};
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
          'remove ${orphans.join(', ')} from ${file.path}: no $namespace '
          'rule has that id',
    );
  });

  if (update && file.existsSync()) {
    tearDownAll(() {
      final text = file.readAsStringSync();
      final current = parseBaseline(text)..addAll(rewritten);
      for (final id in orphans) {
        current.remove(id);
      }
      writeFileAtomically(
        file,
        serializeBaseline(baselineHeader(text), current),
      );
    });
  }
}

/// Test files that call `ratchetTests(..., namespace: 'x')`, by namespace.
/// Comment lines are skipped; [skip] is a path that is not scanned.
Map<String, List<String>> findRegistrations(Directory root, {String? skip}) {
  final call = RegExp(r'ratchetTests\([^;]*namespace:\s*.(\w+).');
  final found = <String, List<String>>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path == skip) continue;
    final text = entity
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    for (final m in call.allMatches(text)) {
      found.putIfAbsent(m.group(1)!, () => []).add(path);
    }
  }
  return found;
}

/// Problems between registrations and baseline files: a namespace registered
/// from two places, or a baseline file nobody registers.
List<String> checkRegistrations(
  Map<String, List<String>> registrations,
  Iterable<String> baselineFileNamespaces,
) => [
  for (final entry in registrations.entries)
    if (entry.value.length > 1)
      'namespace ${entry.key} is registered by ${entry.value.length} files '
          '(${entry.value.join(', ')}): call ratchetTests once per namespace',
  for (final ns in baselineFileNamespaces)
    if (!registrations.containsKey(ns))
      '${baselinePathFor(ns)} has no test file calling '
          "ratchetTests(..., namespace: '$ns')",
];
