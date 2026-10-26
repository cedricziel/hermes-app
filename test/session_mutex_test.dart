import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/session_mutex_native.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'native lock excludes another isolate and releases after failure',
    () async {
      final dir = await Directory.systemTemp.createTemp('hermes-session-lock-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/lock.sqlite';
      final lock = SqliteSessionMutex(path: path);
      await expectLater(
        lock.run(() async {
          final busy = await Isolate.run(() async {
            try {
              await SqliteSessionMutex(
                path: path,
                timeout: Duration.zero,
              ).run(() async => null);
              return false;
            } on SqliteException catch (error) {
              return error.resultCode == 5;
            }
          });
          expect(busy, isTrue);
          throw StateError('body failed');
        }),
        throwsStateError,
      );
      expect(
        await Isolate.run(
          () => SqliteSessionMutex(path: path).run(() async => 'released'),
        ),
        'released',
      );
    },
  );
}
