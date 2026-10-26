import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'session_mutex.dart';

SessionMutex createSessionMutex() => SqliteSessionMutex();

/// SQLite's connection-level write lock also excludes other Flutter engines
/// in this process (unlike POSIX process-scoped file locks). The database holds
/// no credentials. Each operation owns a connection and releases it on error.
class SqliteSessionMutex implements SessionMutex {
  SqliteSessionMutex({this.path, this.timeout = const Duration(seconds: 3)});

  final String? path;
  final Duration timeout;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    final location =
        path ??
        '${(await getApplicationSupportDirectory()).path}/session-lock.sqlite';
    await File(location).parent.create(recursive: true);
    final db = sqlite3.open(location);
    var acquired = false;
    final elapsed = Stopwatch()..start();
    try {
      while (!acquired) {
        try {
          db.execute('BEGIN IMMEDIATE');
          acquired = true;
        } on SqliteException catch (error) {
          if (error.resultCode != 5 || elapsed.elapsed >= timeout) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
      return await body();
    } finally {
      try {
        if (acquired) db.execute('ROLLBACK');
      } finally {
        db.close();
      }
    }
  }
}
