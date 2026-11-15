// Assigns test files to CI shards by measured duration.
//
// Pure: no file system, so `test/tool/shard_assignment_test.dart` can drive
// it with synthetic lists. `tool/shard_weights.dart` is the command line.

/// How an invocation's wall time follows from its files' weights:
/// `wall = overheadSeconds + secondsPerWeight * (sum of weights)`.
///
/// The overhead is what one `flutter test` run costs before and between its
/// files (compile, startup). Shard 0 runs two invocations when it gets files
/// besides the catalog, so it pays it twice.
class ShardModel {
  const ShardModel({this.overheadSeconds = 0, this.secondsPerWeight = 1});

  final double overheadSeconds;
  final double secondsPerWeight;

  /// The overhead in weight units.
  double get overheadWeight => overheadSeconds / secondsPerWeight;
}

/// Returns one list of files per shard.
///
/// The catalog is pinned to shard 0. The other files go longest first (ties by
/// path) to the shard with the lowest load so far (ties to the lowest index).
/// Shard 0's first extra file also charges it [ShardModel.overheadWeight] for
/// the second invocation. A file without a weight counts as the median of the
/// known weights of the other files, or 1.0 when none is known. Weights of
/// absent files are ignored.
List<List<String>> assignShards({
  required Iterable<String> files,
  required Map<String, double> weights,
  required String catalog,
  required int total,
  ShardModel model = const ShardModel(),
}) {
  if (total < 1) throw ArgumentError.value(total, 'total', 'must be positive');
  final all = files.toSet();
  final others = all.where((f) => f != catalog).toList();
  final weightOf = effectiveWeight(all, weights, catalog);

  others.sort((a, b) {
    final byWeight = weightOf(b).compareTo(weightOf(a));
    return byWeight != 0 ? byWeight : a.compareTo(b);
  });

  final shards = List.generate(total, (_) => <String>[]);
  final loads = List<double>.filled(total, 0);
  // Shard 0 has a second invocation to pay for once it gets a non-catalog file.
  var secondRunCharged = !all.contains(catalog);
  if (all.contains(catalog)) {
    shards[0].add(catalog);
    loads[0] += weightOf(catalog);
  }
  double loadIf(int i) =>
      loads[i] + (i == 0 && !secondRunCharged ? model.overheadWeight : 0);
  for (final f in others) {
    var best = 0;
    for (var i = 1; i < total; i++) {
      if (loadIf(i) < loadIf(best)) best = i;
    }
    if (best == 0 && !secondRunCharged) {
      loads[0] += model.overheadWeight;
      secondRunCharged = true;
    }
    shards[best].add(f);
    loads[best] += weightOf(f);
  }
  return shards;
}

/// The weight assignment uses for a file: its entry in [weights], else the
/// median of the known weights of the other [files] (1.0 if none is known).
/// One function for [assignShards] and [shardLoads], so they cannot disagree.
double Function(String file) effectiveWeight(
  Iterable<String> files,
  Map<String, double> weights,
  String catalog,
) {
  final known = [
    for (final f in files)
      if (f != catalog && weights.containsKey(f)) weights[f]!,
  ]..sort();
  final fallback = known.isEmpty
      ? 1.0
      : known.length.isOdd
      ? known[known.length ~/ 2]
      : (known[known.length ~/ 2 - 1] + known[known.length ~/ 2]) / 2;
  return (file) => weights[file] ?? fallback;
}

/// The load of each shard as assignment saw it (weights only, no overhead).
List<double> shardLoads(
  List<List<String>> shards,
  Map<String, double> weights, {
  required String catalog,
}) {
  final weightOf = effectiveWeight(
    [for (final shard in shards) ...shard],
    weights,
    catalog,
  );
  return [
    for (final shard in shards)
      shard.fold<double>(0, (sum, f) => sum + weightOf(f)),
  ];
}

/// Predicted wall seconds per shard under [model]: each invocation costs the
/// overhead plus its weights; shard 0 runs the catalog alone, then the rest.
List<double> predictedWalls(
  List<List<String>> shards,
  Map<String, double> weights, {
  required String catalog,
  ShardModel model = const ShardModel(),
}) {
  final weightOf = effectiveWeight(
    [for (final shard in shards) ...shard],
    weights,
    catalog,
  );
  double invocation(Iterable<String> files) =>
      model.overheadSeconds +
      model.secondsPerWeight * files.fold<double>(0, (s, f) => s + weightOf(f));
  return [
    for (var i = 0; i < shards.length; i++)
      if (i == 0 && shards[i].contains(catalog))
        invocation([catalog]) +
            (shards[i].length > 1
                ? invocation(shards[i].where((f) => f != catalog))
                : 0)
      else
        invocation(shards[i]),
  ];
}
