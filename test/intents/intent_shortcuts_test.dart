import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/intents/intent_shortcuts.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';

import '../support/fake_surface_storage.dart';

SurfaceSnapshot snapshot(String title, {int minute = 0}) => SurfaceSnapshot(
  updatedAt: DateTime.utc(2026, 1, 1, 13, minute),
  recentChats: [
    RecentChat(
      profile: 'default',
      id: 'a',
      title: title,
      updatedAt: DateTime.utc(2026, 1, 1, 12),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SurfaceSnapshotStore store;
  late List<String> calls;
  Exception? failure;

  setUp(() {
    store = SurfaceSnapshotStore(storage: FakeSurfaceStorage());
    calls = [];
    failure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kShortcutsChannel), (
          call,
        ) async {
          calls.add(call.method);
          if (failure != null) throw failure!;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(kShortcutsChannel), null);
    await store.dispose();
  });

  Future<void> write(SurfaceSnapshot snapshot) async {
    await store.write(snapshot);
    await Future<void>.delayed(Duration.zero);
  }

  test('asks iOS to refresh the shortcuts once per snapshot write', () async {
    final shortcuts = IntentShortcuts(store: store)..start();

    await write(snapshot('Trip plan'));
    expect(calls, ['refreshShortcuts']);

    await write(snapshot('Taxes'));
    expect(calls, ['refreshShortcuts', 'refreshShortcuts']);
    await shortcuts.dispose();
  });

  test('does not ask again for a write that changed nothing', () async {
    final shortcuts = IntentShortcuts(store: store)..start();

    await write(snapshot('Trip plan'));
    await write(snapshot('Trip plan', minute: 5));

    expect(calls, ['refreshShortcuts']);
    await shortcuts.dispose();
  });

  test('stops asking once disposed', () async {
    final shortcuts = IntentShortcuts(store: store)..start();
    await shortcuts.dispose();

    await write(snapshot('Trip plan'));

    expect(calls, isEmpty);
  });

  test('swallows a channel error', () async {
    final shortcuts = IntentShortcuts(store: store)..start();

    failure = PlatformException(code: 'boom');
    await write(snapshot('Trip plan'));
    failure = MissingPluginException();
    await write(snapshot('Taxes'));

    expect(calls, ['refreshShortcuts', 'refreshShortcuts']);
    await shortcuts.dispose();
  });

  group('forPlatform', () {
    test('exists on iOS only', () {
      expect(
        IntentShortcuts.forPlatform(store: store, platform: TargetPlatform.iOS),
        isNotNull,
      );
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          IntentShortcuts.forPlatform(store: store, platform: platform),
          isNull,
          reason: '$platform',
        );
      }
    });

    test('needs a snapshot store', () {
      expect(
        IntentShortcuts.forPlatform(store: null, platform: TargetPlatform.iOS),
        isNull,
      );
    });
  });
}
