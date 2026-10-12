import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';

class _HeldWrite extends SharedPreferencesAsync {
  final started = Completer<void>();
  final release = Completer<void>();
  final requests = <String>[];
  int get writes => requests.length;
  @override
  Future<void> setString(String key, String value) async {
    requests.add(key);
    if (writes == 1) {
      started.complete();
      await release.future;
    }
    await super.setString(key, value);
  }
}

class _HeldRead extends SharedPreferencesAsync {
  final started = Completer<void>();
  final release = Completer<void>();
  final requests = <String>[];
  int get reads => requests.length;
  @override
  Future<String?> getString(String key) async {
    final value = await super.getString(key);
    requests.add(key);
    if (reads == 1) {
      started.complete();
      await release.future;
    }
    return value;
  }
}

const _args = ConversationWindowArgs(
  threadId: 'private-A',
  profile: null,
  title: 'Private',
  baseUrl: 'https://hermes.test',
  authRequired: true,
  ownerKey: 'owner-A',
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a held old save cannot overwrite explicit forgetting', () async {
    final prefs = _HeldWrite();
    final store = ConversationWindowStore(prefs);
    final saving = store.save([_args]);
    await prefs.started.future;
    final forgetting = store.save(const []);
    try {
      await pumpEventQueue();
      expect(prefs.writes, 1);
    } finally {
      prefs.release.complete();
      await Future.wait([saving, forgetting]);
    }
    expect(await store.load(), isEmpty);
  });

  test('a stale restore read cannot consume the new restore attempt', () async {
    final prefs = _HeldRead();
    final store = ConversationWindowStore(prefs);
    await store.save([_args]);
    final host = FakeConversationWindowHost();
    final windows = ConversationWindows(
      host: host,
      store: store,
      connection: () => (baseUrl: _args.baseUrl, authRequired: true),
      ownerKey: () => 'owner-A',
      headers: ({rejected}) async => const {},
    );
    addTearDown(windows.dispose);
    addTearDown(host.dispose);
    final old = windows.restore();
    await prefs.started.future;
    await windows.closeAll(forget: false);
    final resumed = windows.restore();
    prefs.release.complete();
    await Future.wait([old, resumed]);
    expect(host.created.values.single.threadId, 'private-A');
    expect(windows.windows.length, 1);
  });
}
