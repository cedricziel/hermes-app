import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/shard_assignment.dart';

const catalog = 'test/widgetbook_test.dart';

List<String> diskFiles() => [
  for (final e in Directory('test').listSync(recursive: true))
    if (e is File && e.path.endsWith('_test.dart'))
      e.path.replaceAll('\\', '/'),
]..sort();

Map<String, double> realWeights() {
  final decoded =
      jsonDecode(File('test/shard_weights.json').readAsStringSync()) as Map;
  return {
    for (final e in decoded.entries)
      e.key as String: (e.value as num).toDouble(),
  };
}

void checkPartition(
  List<String> files,
  Map<String, double> weights, {
  int total = 4,
}) {
  final shards = assignShards(
    files: files,
    weights: weights,
    catalog: catalog,
    total: total,
  );
  expect(shards, hasLength(total));
  final flat = [for (final s in shards) ...s];
  expect(flat.length, files.toSet().length, reason: 'a file twice or lost');
  expect(flat.toSet(), files.toSet());
  for (var i = 1; i < total; i++) {
    expect(shards[i], isNot(contains(catalog)));
  }
  if (files.contains(catalog)) expect(shards[0], contains(catalog));
  final again = assignShards(
    files: files.reversed,
    weights: weights,
    catalog: catalog,
    total: total,
  );
  expect(again, shards, reason: 'not deterministic');
  if (files.length >= total) {
    for (final s in shards) {
      expect(s, isNotEmpty);
    }
  }
}

void main() {
  final files = diskFiles();
  final real = realWeights();
  final random = Random(7);
  final randomWeights = {for (final f in files) f: random.nextDouble() * 100};
  final stale = {
    for (final e in real.entries.toList().skip(40)) e.key: e.value,
    'test/deleted_a_test.dart': 99.0,
    'test/deleted_b_test.dart': 5.0,
  };
  final synthetic = [
    catalog,
    for (var i = 0; i < 25; i++) 'test/synthetic/f${i}_test.dart',
  ];

  final cases = <String, Map<String, double>>{
    'real weights': real,
    'empty weights': {},
    'stale weights': stale,
    'random weights': randomWeights,
  };

  for (final c in cases.entries) {
    test('partitions the files on disk with ${c.key}', () {
      expect(files, contains(catalog));
      checkPartition(files, c.value);
    });
    test('partitions a synthetic list with ${c.key}', () {
      checkPartition(synthetic, c.value);
    });
  }

  test('works for other shard totals and a list without the catalog', () {
    for (final total in [1, 2, 3, 5, 8]) {
      checkPartition(files, real, total: total);
    }
    checkPartition(synthetic.skip(1).toList(), real);
  });

  test('a new file missing from the weights is assigned', () {
    final withNew = [...files, 'test/brand_new_test.dart'];
    final shards = assignShards(
      files: withNew,
      weights: real,
      catalog: catalog,
      total: 4,
    );
    expect([
      for (final s in shards) ...s,
    ], contains('test/brand_new_test.dart'));
  });

  test('an unknown file counts as the median of the known ones', () {
    final shards = assignShards(
      files: ['a', 'b', 'c', 'd', catalog],
      weights: {'a': 10, 'b': 30, 'c': 20},
      catalog: catalog,
      total: 2,
    );
    // d weighs 20 (median) and so does the catalog: b, c, d, a in that order.
    expect(shards[0], [catalog, 'c', 'a']);
    expect(shards[1], ['b', 'd']);
  });

  test('longest first, lowest load first, ties to the lowest index', () {
    final shards = assignShards(
      files: ['a', 'b', 'c', 'd'],
      weights: {'a': 5, 'b': 5, 'c': 3, 'd': 3},
      catalog: catalog,
      total: 2,
    );
    expect(shards, [
      ['a', 'c'],
      ['b', 'd'],
    ]);
  });

  test('the real weights balance the predicted wall time', () {
    // Weights are per-file wall seconds; a shard's files overlap about 1.6x,
    // so their wall is `scale` x the summed weights (CI measured 0.59-0.66).
    // The catalog runs alone: its wall is 400 s, its weight 400 / scale.
    const scale = 0.62;
    const catalogWall = 400.0;
    expect(real[catalog], closeTo(catalogWall / scale, 5));
    final loads = shardLoads(
      assignShards(files: files, weights: real, catalog: catalog, total: 4),
      real,
    );
    final walls = [
      catalogWall + (loads[0] - real[catalog]!) * scale,
      for (final l in loads.skip(1)) l * scale,
    ];
    final spread = walls.reduce(max) - walls.reduce(min);
    expect(spread / walls.reduce(max), lessThan(0.05), reason: '$walls');
  });

  test('the weights file is sorted', () {
    final keys = real.keys.toList();
    expect(keys, [...keys]..sort());
  });
}
