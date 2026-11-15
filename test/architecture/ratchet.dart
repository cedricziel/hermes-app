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
/// removing entries of registered rules (and rule ids left empty); it never
/// raises a count or adds an entry, and it keeps orphan ids. Only
/// `UPDATE_BASELINE=prune` also removes orphan ids, once the rule is really
/// gone. The rewrite goes through a temp file in the same directory and a
/// rename.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'source_scan.dart';

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

/// The baseline after an update: [rewritten] rules replace theirs, orphan ids
/// are removed only when [prune]. Never adds a path or raises a count.
Map<String, Map<String, int>> updatedBaseline(
  Map<String, Map<String, int>> current,
  Map<String, Map<String, int>> rewritten,
  List<String> orphans, {
  required bool prune,
}) {
  final out = {...current, ...rewritten};
  if (prune) {
    for (final id in orphans) {
      out.remove(id);
    }
  }
  return out;
}

/// Registers one test per rule of [namespace] (`arch`, `style` or `test`),
/// and one test that no baseline entry names a rule nobody registered. Call
/// it once per namespace, from the top-level `main()` of one `*_test.dart`.
/// With `UPDATE_BASELINE=1` the baseline is lowered instead of failing on a
/// fall (orphan ids are kept and still fail); `UPDATE_BASELINE=prune` also
/// removes orphan ids. A rise still fails.
void ratchetTests(List<Rule> rules, {required String namespace}) {
  claimNamespace(namespace);
  final mode = Platform.environment['UPDATE_BASELINE'];
  final prune = mode == 'prune';
  final update = mode == '1' || prune;
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
    if (prune) return;
    expect(
      orphans,
      isEmpty,
      reason:
          '${orphans.join(', ')} in ${file.path} has no $namespace rule: '
          'register the rule again, or, if the rule is really gone, remove '
          'the id and then run UPDATE_BASELINE=prune once',
    );
  });

  if (update && file.existsSync()) {
    tearDownAll(() {
      final text = file.readAsStringSync();
      writeFileAtomically(
        file,
        serializeBaseline(
          baselineHeader(text),
          updatedBaseline(
            parseBaseline(text),
            rewritten,
            orphans,
            prune: prune,
          ),
        ),
      );
    });
  }
}

/// Every `ratchetTests` use under [roots], and what is wrong with it.
class Registrations {
  /// Namespace -> the places that register it with a literal.
  final byNamespace = <String, List<String>>{};

  /// Uses that are not allowed: a call outside the top-level `main()` of a
  /// `*_test.dart` file, a `namespace:` that is not a literal naming a known
  /// namespace, a tear-off, or a namespace registered twice.
  final problems = <String>[];
}

const _registrationRule =
    'call ratchetTests directly from exactly one *_test.dart per namespace, '
    'with a literal namespace';

final _ident = RegExp(r'\bratchetTests\b');
const _notTypes = {'return', 'await', 'yield', 'else', 'case', 'in', 'throw'};

/// True when the `ratchetTests` at [start] in [code] is a declaration: a
/// return type (`void`, `Future<void>`) comes right before it.
bool _isDeclaration(String code, int start) {
  final before = code.substring(0, start).trimRight();
  if (before.endsWith('>')) return !before.endsWith('=>');
  final word = RegExp(r'(\w+)$').firstMatch(before)?.group(1);
  return word != null && !_notTypes.contains(word);
}

/// The ranges of the top-level `main()` bodies in [code]: (start of the body,
/// end, whether it is an arrow body).
List<(int, int, bool)> _mainBodies(String code) {
  final out = <(int, int, bool)>[];
  for (final m in RegExp(
    r'^(?:[\w<>?.]+\s+)?main\s*\(',
    multiLine: true,
  ).allMatches(code)) {
    final params = callEnd(code, m.end);
    var i = params;
    while (i < code.length && ' \n\t'.contains(code[i])) {
      i++;
    }
    if (code.startsWith('async', i)) i += 5;
    while (i < code.length && ' \n\t'.contains(code[i])) {
      i++;
    }
    if (i < code.length && code[i] == '{') {
      out.add((i, blockEnd(code, i), false));
    } else if (code.startsWith('=>', i)) {
      final semi = code.indexOf(';', i);
      out.add((i + 2, semi < 0 ? code.length : semi, true));
    }
  }
  return out;
}

/// True when [offset] sits directly in a `main()` body: at brace depth 1 and
/// parenthesis depth 0 of a block body, or right after the `=>` of an arrow
/// body.
bool _directlyInMain(String code, int offset, List<(int, int, bool)> mains) {
  for (final (start, end, arrow) in mains) {
    if (offset <= start || offset >= end) continue;
    if (arrow) {
      if (RegExp(r'^\s*(?:\w+\s*\.\s*)?$')
          .hasMatch(code.substring(start, offset))) {
        return true;
      }
      continue;
    }
    var braces = 0;
    var parens = 0;
    for (var i = start; i < offset; i++) {
      final c = code[i];
      if (c == '{') braces++;
      if (c == '}') braces--;
      if (c == '(') parens++;
      if (c == ')') parens--;
    }
    if (braces == 1 && parens == 0) return true;
  }
  return false;
}

/// The literal of the call's own `namespace:` argument (depth 0 of its
/// arguments, found in [code], read from [text]), or null.
String? _namespaceLiteral(String code, String text, int argStart, int argEnd) {
  var depth = 0;
  for (var i = argStart; i < argEnd; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 &&
        code.startsWith('namespace', i) &&
        (i == 0 || !RegExp(r'\w').hasMatch(code[i - 1]))) {
      final m = RegExp(r"""^namespace\s*:\s*(?:'(\w+)'|"(\w+)")\s*(?:,|\))""")
          .firstMatch(text.substring(i, argEnd));
      return m == null ? null : (m.group(1) ?? m.group(2));
    }
  }
  return null;
}

/// Scans the comment-free code of every Dart file under [roots]. Each
/// `ratchetTests(` call must sit directly in the body of the top-level
/// `main()` of a `*_test.dart` file, with a literal namespace.
Registrations findRegistrations(List<Directory> roots) {
  final out = Registrations();
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final file = SourceFile(path, entity.readAsStringSync());
      final code = file.code;
      final mains = path.endsWith('_test.dart')
          ? _mainBodies(code)
          : const <(int, int, bool)>[];
      for (final m in _ident.allMatches(code)) {
        if (_isDeclaration(code, m.start)) continue;
        final where = '$path:${file.lineOf(m.start)}';
        var open = m.end;
        while (open < code.length && ' \n\t'.contains(code[open])) {
          open++;
        }
        if (open >= code.length || code[open] != '(') {
          out.problems.add(
            '$where: ratchetTests is used as a value, not called: '
            '$_registrationRule',
          );
          continue;
        }
        if (!_directlyInMain(code, m.start, mains)) {
          out.problems.add(
            '$where: ratchetTests is not called directly in the top-level '
            'main() of a *_test.dart file: $_registrationRule',
          );
          continue;
        }
        final ns = _namespaceLiteral(
          code,
          file.text,
          open + 1,
          callEnd(code, open + 1),
        );
        if (ns == null) {
          out.problems.add(
            '$where: the namespace argument is not a string literal: '
            '$_registrationRule',
          );
        } else if (!namespaces.contains(ns)) {
          out.problems.add('$where: unknown namespace "$ns" ($namespaces)');
        } else {
          out.byNamespace.putIfAbsent(ns, () => []).add(where);
        }
      }
    }
  }
  for (final entry in out.byNamespace.entries) {
    if (entry.value.length > 1) {
      out.problems.add(
        'namespace ${entry.key} is registered ${entry.value.length} times '
        '(${entry.value.join(', ')}): $_registrationRule',
      );
    }
  }
  return out;
}

/// Problems between registrations and baseline files: a bad call, a namespace
/// registered twice, or a baseline file nobody registers.
List<String> checkRegistrations(
  Registrations registrations,
  Iterable<String> baselineFileNamespaces,
) => [
  ...registrations.problems,
  for (final ns in baselineFileNamespaces)
    if (!registrations.byNamespace.containsKey(ns))
      '${baselinePathFor(ns)} has no test file calling '
          "ratchetTests(..., namespace: '$ns')",
];
