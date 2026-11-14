import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/session_mutex.dart';
import 'package:hermes_app/src/background/background_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _key = 'hermes.background.announced.v1';

/// Reads yield to the other writer first, as two isolates would interleave.
class _SlowReadPrefs extends SharedPreferencesAsync {
  @override
  Future<List<String>?> getStringList(String key) async {
    final value = await super.getStringList(key);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return value;
  }
}

class _FailingReadPrefs extends SharedPreferencesAsync {
  @override
  Future<List<String>?> getStringList(String key) async =>
      throw StateError('preferences unreadable');
}

class _CountingMutex extends MemorySessionMutex {
  var runs = 0;

  @override
  Future<T> run<T>(Future<T> Function() body) {
    runs++;
    return super.run(body);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          _key: ['old-1', 'old-2'],
        });
  });

  test('two runs marking at once keep each other\'s marks', () async {
    final lock = MemorySessionMutex();
    final a = AnnouncedRequests(prefs: _SlowReadPrefs(), mutex: lock);
    final b = AnnouncedRequests(prefs: _SlowReadPrefs(), mutex: lock);

    await Future.wait([
      a.add(['from-a']),
      b.add(['from-b']),
    ]);

    final stored = await SharedPreferencesAsync().getStringList(_key);
    expect(stored, containsAll(['old-1', 'old-2', 'from-a', 'from-b']));
  });

  test('marking takes the lock', () async {
    final lock = _CountingMutex();
    await AnnouncedRequests(mutex: lock).add(['x']);
    expect(lock.runs, 1);
  });

  test('a failed read writes nothing back and fails the mark', () async {
    final announced = AnnouncedRequests(prefs: _FailingReadPrefs());

    await expectLater(announced.add(['new']), throwsA(isA<StateError>()));

    expect(await SharedPreferencesAsync().getStringList(_key), [
      'old-1',
      'old-2',
    ]);
    expect(await announced.read(), isEmpty);
  });

  test('a failed read does not remember the id in memory', () async {
    final announced = AnnouncedRequests(prefs: _FailingReadPrefs());
    await announced.add(['new']).catchError((Object _) {});
    expect(await announced.read(), isNot(contains('new')));
  });
}
