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

  test('the real weights balance the shards', () {
    final loads = shardLoads(
      assignShards(files: files, weights: real, catalog: catalog, total: 4),
      real,
    );
    final spread = loads.reduce(max) - loads.reduce(min);
    expect(spread, lessThan(60), reason: '$loads');
  });

  test('the weights file is sorted', () {
    final keys = real.keys.toList();
    expect(keys, [...keys]..sort());
  });
}
