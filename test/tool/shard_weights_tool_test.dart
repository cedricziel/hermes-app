import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/shard_weights.dart';

void main() {
  group('relativeTestPath', () {
    const root = '/home/me/hermes-app';

    test('strips the local root', () {
      expect(
        relativeTestPath('$root/test/a/b_test.dart', root),
        'test/a/b_test.dart',
      );
    });

    test('reads a CI runner path from another checkout', () {
      expect(
        relativeTestPath(
          '/home/runner/work/hermes-app/hermes-app/test/a/b_test.dart',
          root,
        ),
        'test/a/b_test.dart',
      );
    });

    test('reads file URIs and Windows separators', () {
      expect(
        relativeTestPath('file:///home/runner/w/r/test/x_test.dart', root),
        'test/x_test.dart',
      );
      expect(
        relativeTestPath(
          r'D:\a\r\r\test\y_test.dart'.replaceAll(r'\', '/'),
          root,
        ),
        'test/y_test.dart',
      );
    });

    test('prefers the cut that names a known file, else the last', () {
      const path = '/home/test/work/test/t_test.dart';
      expect(
        relativeTestPath(path, root, known: {'test/t_test.dart'}),
        'test/t_test.dart',
      );
      expect(
        relativeTestPath(
          '/home/test/work/test/t_test.dart',
          root,
          known: {'test/work/test/t_test.dart'},
        ),
        'test/work/test/t_test.dart',
      );
      expect(relativeTestPath(path, root), 'test/t_test.dart');
    });

    test('ignores files outside test/ and non-test files', () {
      expect(relativeTestPath('/x/lib/a_test.dart', root), isNull);
      expect(relativeTestPath('/x/test/a.dart', root), isNull);
    });
  });

  group('parseReport', () {
    test('reads weights and wall from a runner-style report', () {
      const base = '/home/runner/work/hermes-app/hermes-app';
      final report = [
        '{"type":"start","time":0}',
        '{"type":"suite","suite":{"id":0,"path":"$base/test/a_test.dart"},"time":1000}',
        '{"type":"testStart","test":{"id":1,"suiteID":0},"time":1100}',
        '{"type":"testDone","testID":1,"time":3500}',
        'not json',
        '{"type":"done","time":4000}',
      ].join('\n');
      final parsed = parseReport(report, '/elsewhere');
      expect(parsed.weights, {'test/a_test.dart': 2.5});
      expect(parsed.wall, 4.0);
    });
  });

  test('scripts/test-shard.sh fails when assign fails, for every shard', () {
    if (Platform.isWindows) return;
    final dir = Directory.systemTemp.createTempSync('fake_dart');
    addTearDown(() => dir.deleteSync(recursive: true));
    final fake = File('${dir.path}/dart')
      ..writeAsStringSync('#!/bin/sh\nexit 255\n');
    Process.runSync('chmod', ['+x', fake.path]);
    final env = {'PATH': '${dir.path}:${Platform.environment['PATH']}'};
    for (var shard = 0; shard < 4; shard++) {
      for (final list in ['', '1']) {
        final result = Process.runSync(
          'bash',
          ['scripts/test-shard.sh', '$shard', '4'],
          environment: {...env, 'TEST_SHARD_LIST': list},
        );
        expect(result.exitCode, isNot(0), reason: 'shard $shard list=$list');
      }
    }
  });
}
