import 'dart:convert';
import 'dart:io';

import 'shard_assignment.dart';

// Test sharding by measured duration.
//
//   dart run tool/shard_weights.dart assign <index> <total>
//       Prints the shard's test files, one per line. The catalog is not
//       listed: scripts/test-shard.sh runs it first on shard 0.
//   dart run tool/shard_weights.dart list <index> <total>
//       Same, with the catalog included.
//   dart run tool/shard_weights.dart update <report.json>...
//       Rebuilds test/shard_weights.json from `flutter test --file-reporter
//       json:<path>` reports (CI uploads them as `test-report-<shard>`).
const catalog = 'test/widgetbook_test.dart';
const weightsPath = 'test/shard_weights.json';

// Weights are per-file wall seconds (first suite event to last testDone). Files
// of one invocation run about 1.6x in parallel, so an invocation's wall time is
// about `weightScale` x the sum of its files' weights (CI: shards 1-3 Test
// steps came to 0.59-0.66 x their weight sums). The catalog runs alone, so its
// measured wall time (about 400 s) is real wall seconds; its weight is
// catalogWall / weightScale (400 / 0.62 = 645.2) to share the others' unit.
// `update` re-derives both from the reports.
const catalogWall = 400.0;
const weightScale = 0.62;
const catalogWeight = 645.2;

Future<void> main(List<String> args) async {
  exitCode = run(args);
}

int run(List<String> args) {
  if (args.isEmpty) return _usage();
  switch (args.first) {
    case 'assign' || 'list':
      if (args.length != 3) return _usage();
      final index = int.tryParse(args[1]);
      final total = int.tryParse(args[2]);
      if (index == null || total == null || total < 1) return _usage();
      if (index < 0 || index >= total) return _usage();
      final shards = assignShards(
        files: listTestFiles(),
        weights: readWeights(),
        catalog: catalog,
        total: total,
      );
      for (final f in shards[index]) {
        if (args.first == 'list' || f != catalog) stdout.writeln(f);
      }
      return 0;
    case 'update':
      if (args.length < 2) return _usage();
      return update(args.skip(1).toList());
  }
  return _usage();
}

int _usage() {
  stderr.writeln(
    'usage: dart run tool/shard_weights.dart '
    '(assign|list <index> <total> | update <report.json>...)',
  );
  return 64;
}

/// Same files as `find test -name '*_test.dart' | sort`.
List<String> listTestFiles() {
  final files = [
    for (final e in Directory(
      'test',
    ).listSync(recursive: true, followLinks: false))
      if (e is File && e.path.endsWith('_test.dart'))
        e.path.replaceAll('\\', '/'),
  ]..sort();
  return files;
}

Map<String, double> readWeights() {
  final file = File(weightsPath);
  if (!file.existsSync()) return {};
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return {};
    return {
      for (final e in decoded.entries)
        if (e.key is String && e.value is num)
          e.key as String: (e.value as num).toDouble(),
    };
  } on FormatException {
    return {};
  }
}

/// What one `--file-reporter json` report says.
class Report {
  Report(this.weights, this.wall);

  /// Seconds per test file: from the suite's first event to its last test
  /// finishing.
  final Map<String, double> weights;

  /// Wall seconds of the whole invocation: first to last event of the report.
  final double wall;
}

/// Parses one report. Lines that are not JSON, or have odd shapes, are skipped.
Report parseReport(String content, String root, {Set<String>? known}) {
  final suitePath = <int, String>{};
  final suiteStart = <int, int>{};
  final suiteEnd = <int, int>{};
  final testSuite = <int, int>{};
  int? first;
  int? last;
  for (final line in const LineSplitter().convert(content)) {
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (event is! Map) continue;
    final time = event['time'];
    if (time is! num) continue;
    final ms = time.toInt();
    if (first == null || ms < first) first = ms;
    if (last == null || ms > last) last = ms;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite'];
        if (suite is Map && suite['id'] is int && suite['path'] is String) {
          final id = suite['id'] as int;
          suitePath[id] = suite['path'] as String;
          suiteStart[id] = ms;
          suiteEnd[id] = ms;
        }
      case 'testStart':
        final test = event['test'];
        if (test is Map && test['id'] is int && test['suiteID'] is int) {
          testSuite[test['id'] as int] = test['suiteID'] as int;
        }
      case 'testDone':
        final suite = testSuite[event['testID']];
        if (suite != null && ms > (suiteEnd[suite] ?? 0)) suiteEnd[suite] = ms;
    }
  }
  final result = <String, double>{};
  suitePath.forEach((id, path) {
    final name = relativeTestPath(path, root, known: known);
    if (name == null) return;
    final seconds = (suiteEnd[id]! - suiteStart[id]!) / 1000;
    result[name] = (seconds * 10).round() / 10;
  });
  final wall = first == null ? 0.0 : (last! - first) / 1000;
  return Report(result, wall);
}

/// The repo-relative path of a suite, or null for anything outside `test/`.
/// Reports from CI carry the runner's absolute paths, so after the local
/// [root] fails to match, the path is cut at a `/test/` segment: the first one
/// that leaves a file in [known], else the last.
String? relativeTestPath(String path, String root, {Set<String>? known}) {
  var p = path.startsWith('file://') ? Uri.parse(path).toFilePath() : path;
  p = p.replaceAll('\\', '/');
  final r = root.replaceAll('\\', '/');
  if (p.startsWith('$r/')) p = p.substring(r.length + 1);
  if (!p.endsWith('_test.dart')) return null;
  if (p.startsWith('test/')) return p;
  final cuts = <int>[];
  for (var i = p.indexOf('/test/'); i >= 0; i = p.indexOf('/test/', i + 1)) {
    cuts.add(i + 1);
  }
  if (cuts.isEmpty) return null;
  for (final cut in cuts) {
    if (known != null && known.contains(p.substring(cut))) {
      return p.substring(cut);
    }
  }
  return p.substring(cuts.last);
}

int update(List<String> reports) {
  final measured = <String, double>{};
  var catalogSeconds = 0.0; // wall of the invocation that ran the catalog
  var otherWall = 0.0; // wall of every other invocation
  var otherWeights = 0.0; // weights of the files those ran
  final root = Directory.current.path;
  final existing = listTestFiles().toSet();
  for (final path in reports) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('missing report: $path');
      return 1;
    }
    final report = parseReport(file.readAsStringSync(), root, known: existing);
    measured.addAll(report.weights);
    if (report.weights.containsKey(catalog)) {
      catalogSeconds += report.wall;
    } else {
      otherWall += report.wall;
      otherWeights += report.weights.values.fold(0.0, (a, b) => a + b);
    }
  }
  if (measured.isEmpty) {
    stderr.writeln('no test files found in the reports');
    return 1;
  }
  final old = readWeights();
  final next = <String, double>{};
  // Files the reports did not cover keep their old weight; deleted files drop.
  for (final f in listTestFiles()) {
    final w = measured[f] ?? old[f];
    if (w != null) next[f] = w;
  }
  // The catalog's weight is its invocation's wall time divided by the scale
  // (other invocations' wall / their summed weights). Without a catalog report,
  // or without other reports to get the scale from, the old weight stays.
  if (catalogSeconds > 0 && otherWall > 0 && otherWeights > 0) {
    final scale = otherWall / otherWeights;
    next[catalog] = (catalogSeconds / scale * 10).round() / 10;
    stdout.writeln(
      'scale ${scale.toStringAsFixed(2)}, catalog ${next[catalog]}',
    );
  } else {
    next[catalog] = old[catalog] ?? catalogWeight;
  }
  final keys = next.keys.toList()..sort();
  final out = {for (final k in keys) k: next[k]};
  File(
    weightsPath,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('wrote ${keys.length} weights to $weightsPath');
  return 0;
}
