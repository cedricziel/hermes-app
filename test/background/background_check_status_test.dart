import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_app/src/background/background_check_status.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _UnavailablePrefs extends SharedPreferencesAsync {
  @override
  Future<String?> getString(String key) async =>
      throw StateError('storage unavailable');
}

class _PausedCompletionPrefs extends SharedPreferencesAsync {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> setString(String key, String value) async {
    if (value.contains('"outcome":"completed"')) {
      entered.complete();
      await release.future;
    }
    await super.setString(key, value);
  }
}

class _PrefsFailures {
  bool failRemoval = false;
  bool failActivation = false;
}

class _FailedClearPrefs extends SharedPreferencesAsync {
  final failures = _PrefsFailures();
  @override
  Future<void> remove(String key) async {
    if (failures.failRemoval) throw StateError('removal unavailable');
    await super.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failures.failActivation && value.contains('"generation"')) {
      throw StateError('activation unavailable');
    }
    await super.setString(key, value);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('attempt without terminal outcome stays incomplete', () async {
    final store = BackgroundCheckStore();
    await store.activate('account-hash');
    await store.begin();
    expect(
      (await store.read('account-hash'))?.outcome,
      BackgroundCheckOutcome.incomplete,
    );
    expect(await store.read('another-account'), isNull);
  });
  test('older completion cannot overwrite newer attempt', () async {
    final store = BackgroundCheckStore();
    await store.activate('account-hash');
    final old = await store.begin();
    final fresh = await store.begin();
    await store.finish(fresh, BackgroundCheckOutcome.partial);
    await store.finish(old, BackgroundCheckOutcome.completed);
    expect(
      (await store.read('account-hash'))?.outcome,
      BackgroundCheckOutcome.partial,
    );
  });
  test('sign out prevents an old writer restoring visible status', () async {
    final store = BackgroundCheckStore();
    await store.activate('account-hash');
    final attempt = await store.begin();
    await store.clear();
    await store.finish(attempt, BackgroundCheckOutcome.completed);
    await store.activate('account-hash');
    expect(await store.read('account-hash'), isNull);
  });
  test('latest check retains previous completed check time', () async {
    final store = BackgroundCheckStore();
    await store.activate('account-hash');
    await store.finish(await store.begin(), BackgroundCheckOutcome.completed);
    final completed = (await store.read('account-hash'))!.completedAt;
    await store.begin();
    expect((await store.read('account-hash'))!.completedAt, completed);
  });
  test('failed logout cleanup keeps the retired store unreadable', () async {
    final prefs = _FailedClearPrefs();
    final store = BackgroundCheckStore(prefs: prefs);
    await store.activate('account-hash');
    await store.finish(await store.begin(), BackgroundCheckOutcome.completed);
    prefs.failures.failRemoval = true;
    await store.clear();

    expect(await store.read('account-hash'), isNull);
    expect(await store.begin(), isNull);
  });

  test(
    'same-account login after failed cleanup rejects an old completion',
    () async {
      final prefs = _FailedClearPrefs();
      final store = BackgroundCheckStore(prefs: prefs);
      final oldWriter = BackgroundCheckStore(prefs: prefs);
      await store.activate('account-hash');
      final old = await oldWriter.begin();
      prefs.failures.failRemoval = true;
      await store.clear();
      await store.activate('account-hash');
      await oldWriter.finish(old, BackgroundCheckOutcome.completed);

      expect(
        await BackgroundCheckStore(prefs: prefs).read('account-hash'),
        isNull,
      );
    },
  );

  test(
    'a failed fresh activation cannot revive the retired account status',
    () async {
      final prefs = _FailedClearPrefs();
      final store = BackgroundCheckStore(prefs: prefs);
      await store.activate('account-hash');
      await store.finish(await store.begin(), BackgroundCheckOutcome.completed);
      prefs.failures
        ..failRemoval = true
        ..failActivation = true;
      await store.clear();
      await store.activate('account-hash');

      expect(await store.read('account-hash'), isNull);
      expect(await store.begin(), isNull);
    },
  );

  test(
    'a fresh store preserves status when no logout retired the account',
    () async {
      final store = BackgroundCheckStore();
      await store.activate('account-hash');
      await store.finish(await store.begin(), BackgroundCheckOutcome.completed);
      final restarted = BackgroundCheckStore();
      await restarted.activate('account-hash');

      expect(
        (await restarted.read('account-hash'))?.outcome,
        BackgroundCheckOutcome.completed,
      );
    },
  );
  test(
    'status stores only content-free account hash generation and outcomes',
    () async {
      final store = BackgroundCheckStore();
      await store.activate('account-hash');
      await store.finish(await store.begin(), BackgroundCheckOutcome.locked);
      final payload = jsonEncode(await SharedPreferencesAsync().getAll());
      expect(payload, isNot(contains('https://')));
      expect(payload, isNot(contains('prompt')));
      expect(payload, isNot(contains('token')));
      expect(
        (await store.read('account-hash'))?.outcome,
        BackgroundCheckOutcome.locked,
      );
    },
  );
  test('unavailable status storage fails silently', () async {
    final store = BackgroundCheckStore(prefs: _UnavailablePrefs());
    await expectLater(store.activate('account-hash'), completes);
    expect(await store.begin(), isNull);
    expect(await store.read('account-hash'), isNull);
    await expectLater(store.clear(), completes);
  });
  test('completion already writing cannot replace a newer attempt', () async {
    final prefs = _PausedCompletionPrefs();
    final store = BackgroundCheckStore(prefs: prefs);
    await store.activate('account-hash');
    final old = await store.begin();
    final finishing = store.finish(old, BackgroundCheckOutcome.completed);
    await prefs.entered.future;
    await store.begin();
    prefs.release.complete();
    await finishing;
    expect(
      (await store.read('account-hash'))?.outcome,
      BackgroundCheckOutcome.incomplete,
    );
  });
  test(
    'completion already writing cannot restore status after sign out',
    () async {
      final prefs = _PausedCompletionPrefs();
      final store = BackgroundCheckStore(prefs: prefs);
      await store.activate('account-hash');
      final old = await store.begin();
      final finishing = store.finish(old, BackgroundCheckOutcome.completed);
      await prefs.entered.future;
      await store.clear();
      await store.activate('account-hash');
      prefs.release.complete();
      await finishing;
      expect(await store.read('account-hash'), isNull);
      expect(await prefs.getKeys(), hasLength(1));
    },
  );
}
