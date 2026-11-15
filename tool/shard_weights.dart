import 'dart:convert';
import 'dart:io';

import 'shard_assignment.dart';

// Test sharding by measured duration.
//
//   dart tool/shard_weights.dart assign <index> <total>
//       Prints the shard's test files, one per line. The catalog is not
//       listed: scripts/test-shard.sh runs it first on shard 0.
//   dart tool/shard_weights.dart list <index> <total>
//       Same, with the catalog included.
//   dart tool/shard_weights.dart update <report.json>...
//       Rebuilds test/shard_weights.json from `flutter test --file-reporter
//       json:<path>` reports (CI uploads them as `test-report-<shard>`).
const catalog = 'test/widgetbook_test.dart';
const weightsPath = 'test/shard_weights.json';

// Weights are per-file wall seconds (first suite event to last testDone). An
// invocation's wall time is `c + b * (sum of its files' weights)`: files overlap
// (b about 0.5-0.7) and every `flutter test` run pays a fixed `c` (compile,
// startup). `_model` in the weights file holds c and b; `update` fits them by
// least squares over the non-catalog invocations of the reports. The catalog
// runs alone, so its weight is (its wall - c) / b, in the same unit as the
// rest. Shard 0 pays `c` again for its second invocation (see assignShards).
// Keys starting with `_` in the weights file are never test files.
const catalogWeight = 645.2;
const modelKey = '_model';

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
        model: readModel(),
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
    'usage: dart tool/shard_weights.dart '
    '(assign|list <index> <total> | update <report.json>...)',
  );
  return 64;
}

/// Same files as `find test -name '*_test.dart' | sort`: symlinked files
/// count, symlinked directories are not entered.
List<String> listTestFiles([String dir = 'test']) {
  final files = [
    for (final e in Directory(
      dir,
    ).listSync(recursive: true, followLinks: false))
      if (e.path.endsWith('_test.dart') &&
          (e is File || (e is Link && FileSystemEntity.isFileSync(e.path))))
        e.path.replaceAll('\\', '/'),
  ]..sort();
  return files;
}

Object? _readWeightsJson() {
  final file = File(weightsPath);
  if (!file.existsSync()) return null;
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException {
    return null;
  }
}

/// File weights only: reserved `_` keys and non-numbers are skipped.
Map<String, double> readWeights() => parseWeights(_readWeightsJson());

Map<String, double> parseWeights(Object? decoded) {
  if (decoded is! Map) return {};
  return {
    for (final e in decoded.entries)
      if (e.key is String &&
          !(e.key as String).startsWith('_') &&
          e.value is num)
        e.key as String: (e.value as num).toDouble(),
  };
}

/// The overhead model from the weights file; zero overhead when absent or odd.
ShardModel readModel() => parseModel(_readWeightsJson());

ShardModel parseModel(Object? decoded) {
  final model = decoded is Map ? decoded[modelKey] : null;
  if (model is! Map) return const ShardModel();
  final c = model['invocationOverheadSeconds'];
  final b = model['secondsPerWeight'];
  if (c is! num || b is! num || c < 0 || b <= 0) return const ShardModel();
  return ShardModel(
    overheadSeconds: c.toDouble(),
    secondsPerWeight: b.toDouble(),
  );
}

/// Least squares for `wall = c + b * weight` over (weight, wall) points.
/// Null when there are fewer than 3 points, no spread, a non-positive slope or
/// a negative intercept (the caller then falls back to a single scale).
ShardModel? fitModel(List<(double, double)> points) {
  if (points.length < 3) return null;
  final n = points.length;
  final mx = points.fold(0.0, (s, p) => s + p.$1) / n;
  final my = points.fold(0.0, (s, p) => s + p.$2) / n;
  final sxx = points.fold(0.0, (s, p) => s + (p.$1 - mx) * (p.$1 - mx));
  if (sxx <= 0) return null;
  final sxy = points.fold(0.0, (s, p) => s + (p.$1 - mx) * (p.$2 - my));
  final b = sxy / sxx;
  final c = my - b * mx;
  if (b <= 0 || c < 0) return null;
  return ShardModel(overheadSeconds: c, secondsPerWeight: b);
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
  final points = <(double, double)>[]; // (weights, wall) per other invocation
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
      final sum = report.weights.values.fold(0.0, (a, b) => a + b);
      otherWeights += sum;
      points.add((sum, report.wall));
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
  // wall = c + b * weight over the non-catalog invocations. Too few points or
  // an implausible fit: c = 0 and one scale (their wall over their weights).
  ShardModel? model;
  if (otherWall > 0 && otherWeights > 0) {
    model = fitModel(points);
    if (model == null) {
      stderr.writeln(
        'warning: could not fit an overhead from ${points.length} '
        'invocation(s); using no overhead and one scale',
      );
      model = ShardModel(secondsPerWeight: otherWall / otherWeights);
    }
  }
  if (model != null && catalogSeconds > 0) {
    next[catalog] =
        (((catalogSeconds - model.overheadSeconds) / model.secondsPerWeight) *
                10)
            .round() /
        10;
    stdout.writeln(
      'overhead ${model.overheadSeconds.toStringAsFixed(1)} s, '
      '${model.secondsPerWeight.toStringAsFixed(3)} s per weight, '
      'catalog ${next[catalog]}',
    );
  } else {
    model = readModel();
    next[catalog] = old[catalog] ?? catalogWeight;
  }
  final keys = next.keys.toList()..sort();
  final out = <String, Object?>{
    modelKey: {
      'invocationOverheadSeconds': (model.overheadSeconds * 10).round() / 10,
      'secondsPerWeight': (model.secondsPerWeight * 1000).round() / 1000,
    },
    for (final k in keys) k: next[k],
  };
  File(
    weightsPath,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('wrote ${keys.length} weights to $weightsPath');
  return 0;
}
