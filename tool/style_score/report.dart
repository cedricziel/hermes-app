import 'allowlist.dart';
import 'scanner.dart';

/// Everything a run measured, ready to print or serialise. The JSON keeps
/// per-category counts at the top level so a later ratchet can compare them
/// with a stored baseline.
class StyleReport {
  StyleReport(this.findings, {this.allowlisted = 0, this.unused = const []});

  final List<Finding> findings;
  final int allowlisted;
  final List<AllowEntry> unused;

  Iterable<Finding> get scored =>
      findings.where((f) => scoredCategories.contains(f.category));

  int get total => scored.length;

  Map<String, int> _count(
    Iterable<Finding> of,
    String Function(Finding) key, [
    Iterable<String> seed = const [],
  ]) {
    final out = {for (final k in seed) k: 0};
    for (final f in of) {
      out[key(f)] = (out[key(f)] ?? 0) + 1;
    }
    return Map.fromEntries(
      out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Map<String, int> get categories =>
      _count(scored, (f) => f.category, scoredCategories);

  Map<String, int> get informational => _count(
    findings.where((f) => informationalCategories.contains(f.category)),
    (f) => f.category,
    informationalCategories,
  );

  /// Counts of the tagged subcounts, e.g. `font.role` and `font.offRole`.
  Map<String, int> get subcounts => _count(
    scored.where((f) => f.tag != null),
    (f) => f.tag!,
    ['font.offRole', 'font.role'],
  );

  Map<String, int> get groups =>
      _count(scored, (f) => f.category.split('.').first);

  Map<String, int> get areas => _count(scored, (f) => areaOf(f.path));

  Map<String, Map<String, int>> get areaCategories {
    final out = <String, Map<String, int>>{};
    for (final f in scored) {
      final cats = out.putIfAbsent(areaOf(f.path), () => {});
      cats[f.category] = (cats[f.category] ?? 0) + 1;
    }
    return {
      for (final k in out.keys.toList()..sort())
        k: Map.fromEntries(
          out[k]!.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
    };
  }

  /// Files by descending score, ties by path.
  List<MapEntry<String, int>> get files {
    final counts = _count(scored, (f) => f.path);
    return counts.entries.toList()..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  }

  Map<String, Map<String, int>> _rules(Iterable<Finding> of) {
    final out = <String, Map<String, int>>{};
    for (final f in of) {
      final files = out.putIfAbsent(f.ruleId, () => {});
      files[f.path] = (files[f.path] ?? 0) + 1;
    }
    return {
      for (final k in out.keys.toList()..sort())
        k: Map.fromEntries(
          out[k]!.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
    };
  }

  /// Per rule, per file counts of the scored rules: the shape of a ratchet
  /// baseline.
  Map<String, Map<String, int>> get rules => _rules(scored);

  Map<String, Map<String, int>> get informationalRules => _rules(
    findings.where((f) => informationalCategories.contains(f.category)),
  );

  /// [rules] as YAML, rule -> `path: count`, for a baseline file.
  String ratchetYaml() {
    final b = StringBuffer();
    rules.forEach((rule, files) {
      b.writeln('$rule:');
      files.forEach((path, n) => b.writeln('  $path: $n'));
    });
    return b.toString();
  }

  List<Finding> get sortedFindings => [...findings]
    ..sort((a, b) {
      var c = a.path.compareTo(b.path);
      if (c == 0) c = a.line.compareTo(b.line);
      if (c == 0) c = a.category.compareTo(b.category);
      return c;
    });

  Map<String, Object?> toJson({bool list = true}) => {
    'schema': 1,
    'total': total,
    'categories': categories,
    'groups': groups,
    'subcounts': subcounts,
    'informational': informational,
    'rules': rules,
    'informationalRules': informationalRules,
    'areas': areas,
    'areaCategories': areaCategories,
    'files': {for (final e in files) e.key: e.value},
    'allowlisted': allowlisted,
    'unusedAllowlist': [for (final e in unused) e.describe()],
    'spacingScale': (spacingScale.toList()..sort()),
    'radiusScale': (radiusScale.toList()..sort()),
    if (list) 'findings': [for (final f in sortedFindings) f.toJson()],
  };

  String text({int top = 20, bool list = true}) {
    final b = StringBuffer();
    String row(String k, int v) =>
        '  ${k.padRight(28)}${v.toString().padLeft(6)}';
    b.writeln('Style score S: $total');
    if (allowlisted > 0) {
      b.writeln('($allowlisted allowlisted hits not counted)');
    }
    b.writeln('\nBy category');
    categories.forEach((k, v) {
      b.writeln(row(k, v));
      if (k == 'a.font') {
        subcounts.forEach((t, n) => b.writeln(row('  $t', n)));
      }
    });
    b.writeln(
      '\nInformational, not in S (no duration or icon-size tokens exist yet)',
    );
    informational.forEach((k, v) => b.writeln(row(k, v)));
    b.writeln('\nBy area');
    for (final e
        in areas.entries.toList()..sort(
          (a, b) => b.value.compareTo(a.value) != 0
              ? b.value.compareTo(a.value)
              : a.key.compareTo(b.key),
        )) {
      b.writeln(row(e.key, e.value));
    }
    b.writeln('\nBy area and category');
    areaCategories.forEach((area, cats) {
      b.writeln(
        '  $area: ${cats.entries.map((e) => '${e.key}=${e.value}').join('  ')}',
      );
    });
    b.writeln('\nTop $top files');
    for (final e in files.take(top)) {
      b.writeln(row(e.key, e.value));
    }
    for (final e in unused) {
      b.writeln('\nwarning: unused allowlist entry: ${e.describe()}');
    }
    if (list) {
      b.writeln('\nFindings');
      for (final f in sortedFindings) {
        b.writeln('${f.path}:${f.line}  ${f.category}  ${f.snippet}');
      }
    }
    return b.toString();
  }
}
