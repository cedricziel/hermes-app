import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/surfaces/chat_hints.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_builder.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/surfaces/surface_snapshots.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_surface_storage.dart';
import '../support/recording_tracer.dart';

const debounce = Duration(milliseconds: 40);

ChatHints hints({String title = 'Trip plan', String? snippet}) => ChatHints(
  profile: 'default',
  threads: [
    ThreadHint(
      id: 'd1',
      title: title,
      updatedAt: DateTime.utc(2026, 10, 10, 9),
      snippet: snippet,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeSurfaceStorage storage;
  late SurfaceSnapshotStore store;
  late RecordingTracer tracer;
  late SurfaceSnapshots snapshots;
  late StreamController<void> signedOut;
  late DateTime now;

  HermesRepositories newRepositories() => HermesRepositories(
    server.client(),
    telemetry: ConnectionTelemetry(
      tracer: tracer,
      serverAttributes: const {'hermes.version': '1.2.3'},
    ),
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    now = DateTime.utc(2026, 10, 10, 12);
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [
          {'name': 'default'},
          {'name': 'work'},
        ],
      })
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/cron/delivery-targets', {'detail': 'no'}, status: 404);
    storage = FakeSurfaceStorage();
    store = SurfaceSnapshotStore(storage: storage);
    tracer = RecordingTracer();
    signedOut = StreamController<void>.broadcast();
    snapshots = SurfaceSnapshots(
      store: store,
      signedOut: signedOut.stream,
      debounce: debounce,
      remoteInterval: const Duration(minutes: 5),
      now: () => now,
      builderFor: (repositories) => SurfaceSnapshotBuilder(
        repositories,
        timeout: const Duration(milliseconds: 200),
        now: () => now,
      ),
    )..repositories = newRepositories();
    addTearDown(() async {
      snapshots.dispose();
      await signedOut.close();
      await store.dispose();
    });
  });

  SurfaceSnapshot lastWrite() => SurfaceSnapshot.fromJson(storage.saved.last)!;

  Future<void> nextWrite() =>
      store.writes.first.timeout(const Duration(seconds: 2));

  int remoteReads() => server.requestsTo('GET', '/api/profiles').length;

  test('chat changes are written after a short wait, together', () async {
    snapshots
      ..chatChanged(SurfaceTrigger.reply, hints(title: 'First'))
      ..chatChanged(SurfaceTrigger.reply, hints(title: 'Second'));

    await Future<void>.delayed(debounce ~/ 2);
    expect(storage.saved, isEmpty);
    await nextWrite();

    expect(storage.saved, hasLength(1));
    expect(lastWrite().recentChats.single.title, 'Second');
    expect(lastWrite().profile, 'default');
  });

  test('the first write reads the server, later ones within five minutes '
      'do not', () async {
    snapshots.chatChanged(SurfaceTrigger.threads, hints());
    await nextWrite();
    expect(remoteReads(), 1);

    now = now.add(const Duration(minutes: 1));
    snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Changed'));
    await nextWrite();
    expect(remoteReads(), 1);
    expect(lastWrite().recentChats.single.title, 'Changed');

    now = now.add(const Duration(minutes: 5));
    snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Again'));
    await nextWrite();
    expect(remoteReads(), 2);
  });

  test('going to the background writes at once and reads the server', () async {
    snapshots.chatChanged(SurfaceTrigger.threads, hints());
    await nextWrite();
    now = now.add(const Duration(minutes: 1));

    snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(remoteReads(), 2);
    expect(tracer.spans.map((s) => s.attributes['trigger']), [
      'threads',
      'pause',
      'pause',
    ]);
  });

  test('coming back to the front writes nothing', () async {
    snapshots.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(debounce * 2);

    expect(storage.saved, isEmpty);
  });

  test('nothing is built while signed out', () async {
    snapshots.repositories = null;

    snapshots.chatChanged(SurfaceTrigger.reply, hints());
    snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(debounce * 2);

    expect(storage.saved, isEmpty);
    expect(server.requests, isEmpty);
  });

  group('sign-out', () {
    test('writes the signed-out form', () async {
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();

      signedOut.add(null);
      await nextWrite();

      expect(lastWrite().signedIn, isFalse);
      expect(lastWrite().recentChats, isEmpty);
    });

    test('drops a write that was waiting', () async {
      snapshots.chatChanged(SurfaceTrigger.reply, hints());

      signedOut.add(null);
      await Future<void>.delayed(debounce * 3);

      expect(
        storage.saved.map(SurfaceSnapshot.fromJson).map((s) => s!.signedIn),
        [false],
      );
    });

    test('drops a build under way', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => gate.future);
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await Future<void>.delayed(debounce * 2);

      signedOut.add(null);
      await nextWrite();
      gate.complete((status: 200, body: {'profiles': []}));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(lastWrite().signedIn, isFalse);
      expect(storage.saved, hasLength(1));
    });
  });

  group('App Lock', () {
    late AppLockController lock;

    setUp(() async {
      lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await lock.load();
      snapshots.dispose();
      snapshots = SurfaceSnapshots(
        store: store,
        appLock: lock,
        debounce: debounce,
        now: () => now,
      )..repositories = newRepositories();
    });

    Future<void> turn(bool on) async {
      final written = nextWrite();
      await lock.setEnabled(on);
      await written;
    }

    test('leaves titles and snippets out while it is on', () async {
      await turn(true);

      snapshots.chatChanged(
        SurfaceTrigger.reply,
        hints(snippet: 'Booked the flights'),
      );
      await nextWrite();

      expect(lastWrite().recentChats.single.title, '');
      expect(lastWrite().recentChats.single.snippet, isNull);
      expect(lastWrite().recentChats.single.url, contains('id=d1'));
    });

    test('writes them again once it is off', () async {
      await turn(true);
      snapshots.chatChanged(SurfaceTrigger.reply, hints(snippet: 'Booked'));
      await nextWrite();

      await turn(false);

      expect(lastWrite().recentChats.single.title, 'Trip plan');
      expect(lastWrite().recentChats.single.snippet, 'Booked');
    });

    test('hides what is stored as soon as it is turned on', () async {
      snapshots.chatChanged(SurfaceTrigger.reply, hints());
      await nextWrite();
      expect(lastWrite().recentChats.single.title, 'Trip plan');

      await turn(true);

      expect(lastWrite().recentChats.single.title, '');
    });
  });

  group('builds', () {
    test('one at a time, and a request meanwhile runs once after', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => gate.future);
      snapshots.dispose();
      snapshots = SurfaceSnapshots(
        store: store,
        debounce: Duration.zero,
        now: () => now,
      )..repositories = newRepositories();

      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      snapshots
        ..chatChanged(SurfaceTrigger.reply, hints(title: 'Two'))
        ..chatChanged(SurfaceTrigger.request, hints(title: 'Three'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(tracer.spans, hasLength(1));

      gate.complete((status: 200, body: {'profiles': []}));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(tracer.spans.map((s) => s.attributes['trigger']), [
        'threads',
        'request',
      ]);
      expect(lastWrite().recentChats.single.title, 'Three');
    });
  });

  group('telemetry', () {
    test('records the build with its trigger and failed sources', () async {
      server.on('GET', '/api/profiles', {'detail': 'no'}, status: 500);

      snapshots.chatChanged(SurfaceTrigger.threads, hints(title: 'Secret'));
      await nextWrite();

      final span = tracer.spans.single;
      expect(span.name, 'surface.snapshot.build');
      expect(span.attributes, {
        'hermes.version': '1.2.3',
        'trigger': 'threads',
        'sources_failed': 1,
      });
      expect(span.ended, isTrue);
    });
  });
}
