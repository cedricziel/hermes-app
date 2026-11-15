import 'dart:io';

import 'package:yaml/yaml.dart';

import 'scanner.dart';

/// One exception in `tool/style_score_allowlist.yaml`.
///
/// It silences up to [count] findings in [path] of [category] whose snippet
/// contains [match] (and, when set, that sit on [line]). Matching by snippet
/// keeps an entry valid while the file is edited around it.
class AllowEntry {
  AllowEntry({
    required this.path,
    required this.category,
    required this.reason,
    this.match,
    this.line,
    this.count = 1,
  });

  final String path;
  final String category;
  final String reason;
  final String? match;
  final int? line;
  final int count;
  var used = 0;

  bool matches(Finding f) =>
      f.path == path &&
      f.category == category &&
      (match == null || f.snippet.contains(match!)) &&
      (line == null || f.line == line);

  String describe() =>
      '$path $category'
      '${match == null ? '' : ' "$match"'}'
      '${line == null ? '' : ' line $line'}'
      ' (used $used of $count)';
}

class AllowlistError implements Exception {
  AllowlistError(this.message);
  final String message;
  @override
  String toString() => message;
}

List<AllowEntry> parseAllowlist(String yaml) {
  final doc = loadYaml(yaml);
  if (doc == null) return [];
  final list = doc is YamlMap ? doc['allow'] : doc;
  if (list == null) return [];
  if (list is! YamlList) {
    throw AllowlistError('the allowlist must be a list (or `allow:` list)');
  }
  final categories = {...scoredCategories, ...informationalCategories};
  final entries = <AllowEntry>[];
  for (final (i, raw) in list.indexed) {
    if (raw is! YamlMap) throw AllowlistError('entry ${i + 1} is not a map');
    String? field(String key) => raw[key]?.toString();
    final path = field('path');
    final category = field('category');
    final reason = field('reason');
    if (path == null || category == null) {
      throw AllowlistError('entry ${i + 1}: path and category are required');
    }
    if (!categories.contains(category)) {
      throw AllowlistError('entry ${i + 1}: unknown category $category');
    }
    if (reason == null || reason.trim().isEmpty) {
      throw AllowlistError('entry ${i + 1} ($path): a reason is required');
    }
    entries.add(
      AllowEntry(
        path: path,
        category: category,
        reason: reason,
        match: field('match'),
        line: raw['line'] as int?,
        count: (raw['count'] as int?) ?? 1,
      ),
    );
  }
  return entries;
}

List<AllowEntry> loadAllowlist(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];
  return parseAllowlist(file.readAsStringSync());
}

/// Splits [findings] into those still counted and those an entry silences.
({List<Finding> kept, int allowed}) applyAllowlist(
  List<Finding> findings,
  List<AllowEntry> entries,
) {
  final kept = <Finding>[];
  var allowed = 0;
  for (final f in findings) {
    final entry = entries
        .where((e) => e.used < e.count && e.matches(f))
        .firstOrNull;
    if (entry == null) {
      kept.add(f);
    } else {
      entry.used++;
      allowed++;
    }
  }
  return (kept: kept, allowed: allowed);
}

/// Entries that matched fewer findings than their count: stale or too wide.
List<AllowEntry> unusedEntries(List<AllowEntry> entries) =>
    entries.where((e) => e.used < e.count).toList();
