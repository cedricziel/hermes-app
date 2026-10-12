import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart' show StatusCode;
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
  late SurfaceSession session;

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
    session = SurfaceSession.signedIn;
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
    store = SurfaceSnapshotStore(
      storage: storage,
      widgetKinds: const ['Recent'],
    );
    tracer = RecordingTracer();
    signedOut = StreamController<void>.broadcast();
    snapshots = SurfaceSnapshots(
      store: store,
      session: () => session,
      signedOut: signedOut.stream,
      debounce: debounce,
      remoteInterval: const Duration(minutes: 5),
      pauseWindow: const Duration(milliseconds: 100),
      now: () => now,
      builderFor: (repositories) => SurfaceSnapshotBuilder(
        repositories,
        timeout: const Duration(milliseconds: 300),
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

  /// A background run, in another isolate, stores what it read of every
  /// profile on top of the revision it built from.
  Future<void> backgroundWrites({
    required List<PendingRequest> pending,
    KanbanSummary? kanban,
  }) async {
    final stored = SurfaceSnapshot.fromJson(storage.saved.last)!;
    final other = SurfaceSnapshotStore(
      storage: storage,
      widgetKinds: const ['Recent'],
    );
    addTearDown(other.dispose);
    final written = await other.writeIfCurrent(
      SurfaceSnapshot(
        updatedAt: now.add(const Duration(minutes: 1)),
        revision: stored.revision,
        profile: 'default',
        recentChats: stored.recentChats,
        pending: pending,
        kanban: kanban,
      ),
      appLockOn: () async => false,
    );
    expect(written, isNotNull);
  }

  PendingRequest workRequest() => PendingRequest(
    profile: 'work',
    threadId: 'w1',
    threadTitle: 'Numbers',
    kind: PendingKind.approval,
    requestId: 'r-work',
    createdAt: now,
  );

  test(
    'a background write is built upon by the next one, not undone',
    () async {
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();
      await backgroundWrites(pending: [workRequest()]);

      now = now.add(const Duration(minutes: 2));
      snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Changed'));
      await nextWrite();

      expect(lastWrite().recentChats.single.title, 'Changed');
      expect(lastWrite().pending.map((p) => p.requestId), ['r-work']);
    },
  );

  test(
    'resuming adopts what a background run stored while suspended',
    () async {
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();
      await backgroundWrites(
        pending: const [],
        kanban: const KanbanSummary(blocked: 3, review: 1),
      );

      snapshots.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      now = now.add(const Duration(minutes: 2));
      // A change that reads no server: only the held base can carry the
      // Kanban counts over.
      snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Changed'));
      await nextWrite();

      expect(lastWrite().kanban?.blocked, 3);
    },
  );

  test('each write is one revision on', () async {
    snapshots.chatChanged(SurfaceTrigger.threads, hints());
    await nextWrite();
    final first = lastWrite().revision;

    now = now.add(const Duration(minutes: 1));
    snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Changed'));
    await nextWrite();

    expect(lastWrite().revision, first + 1);
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
    ]);
  });

  group('going to the background', () {
    Future<void> settle([int milliseconds = 150]) =>
        Future<void>.delayed(Duration(milliseconds: milliseconds));

    void workChat() => server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 'w1', title: 'Quarterly', lastActive: 1780000000),
      ]),
      query: {'profile': 'work'},
    );

    test('writes once when the server answers quickly', () async {
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();
      expect(storage.reloads, 1);
      workChat();
      now = now.add(const Duration(minutes: 1));

      snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();

      expect(storage.saved, hasLength(2));
      expect(storage.reloads, 2);
      expect(lastWrite().recentChats.map((c) => c.id), contains('w1'));
    });

    test(
      'publishes partial data and releases the pause build when sources hang',
      () async {
        snapshots.chatChanged(SurfaceTrigger.threads, hints());
        await nextWrite();
        final gate = Completer<FakeResponse>();
        server.onRequest('GET', '/api/profiles', (_) => gate.future);
        snapshots.chatChanged(SurfaceTrigger.reply, hints(title: 'Renamed'));

        snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
        await settle();
        expect(storage.saved, hasLength(2));
        expect(lastWrite().recentChats.single.title, 'Renamed');
        expect(tracer.spans.last.ended, isTrue);
        expect(tracer.spans.last.status, StatusCode.error);

        workChat();
        gate.complete((
          status: 200,
          body: {
            'profiles': [
              {'name': 'default'},
              {'name': 'work'},
            ],
          },
        ));
        await settle();

        expect(storage.saved, hasLength(2));
        expect(tracer.spans.every((span) => span.ended), isTrue);

        snapshots.didChangeAppLifecycleState(AppLifecycleState.resumed);
        snapshots.chatChanged(
          SurfaceTrigger.reply,
          hints(title: 'After resume'),
        );
        await nextWrite();
        expect(lastWrite().recentChats.single.title, 'After resume');
      },
    );
  });

  test('coming back to the front writes nothing', () async {
    snapshots.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(debounce * 2);

    expect(storage.saved, isEmpty);
  });

  test('nothing is built while signed out, repositories or not', () async {
    session = SurfaceSession.signedOut;

    snapshots.chatChanged(SurfaceTrigger.reply, hints());
    snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(debounce * 2);

    expect(storage.saved, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('going to the background at the login screen keeps the signed-out '
      'form', () async {
    snapshots.chatChanged(SurfaceTrigger.threads, hints());
    await nextWrite();
    signedOut.add(null);
    await nextWrite();
    session = SurfaceSession.signedOut;

    snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(lastWrite().signedIn, isFalse);
    expect(storage.saved, hasLength(2));
  });

  test('a pause after the sign-out, before the app learns of it, writes '
      'nothing', () async {
    snapshots.chatChanged(SurfaceTrigger.threads, hints());
    await nextWrite();
    signedOut.add(null);
    session = SurfaceSession.signedOut;
    await nextWrite();

    snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      storage.saved.map(SurfaceSnapshot.fromJson).map((s) => s!.signedIn),
      [true, false],
    );
  });

  group('at the login screen', () {
    SurfaceSnapshot account() => SurfaceSnapshot(updatedAt: now, profile: 'a');

    test('a stored snapshot of a signed-in account is replaced', () async {
      storage.saved.add(account().encode());
      session = SurfaceSession.signedOut;

      snapshots.sessionChanged();
      await nextWrite();

      expect(lastWrite().signedIn, isFalse);
      expect(lastWrite().profile, isNull);
    });

    test('a signed-out snapshot is left alone', () async {
      storage.saved.add(SurfaceSnapshot.signedOut(now).encode());
      session = SurfaceSession.signedOut;

      snapshots.sessionChanged();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(storage.saved, hasLength(1));
    });

    test('nothing happens while the session is signed in or unknown', () async {
      storage.saved.add(account().encode());

      for (final other in [SurfaceSession.signedIn, SurfaceSession.unknown]) {
        session = other;
        snapshots.sessionChanged();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(storage.saved, hasLength(1));
    });
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

    test('forgets a snapshot that was being read meanwhile', () async {
      storage.saved.add(
        SurfaceSnapshot(
          updatedAt: now,
          profile: 'old',
          pending: [
            PendingRequest(
              profile: 'old',
              threadId: 't1',
              threadTitle: 'Old chat',
              kind: PendingKind.approval,
              requestId: 'r1',
              createdAt: now,
            ),
          ],
        ).encode(),
      );
      final gate = storage.loadGate = Completer<void>();
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await Future<void>.delayed(debounce * 2);

      signedOut.add(null);
      await nextWrite();
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      snapshots.chatChanged(SurfaceTrigger.reply, hints());
      await nextWrite();

      expect(lastWrite().signedIn, isTrue);
      expect(lastWrite().pending, isEmpty);
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
        session: () => session,
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

    test('hides it without waiting for the server', () async {
      snapshots.chatChanged(SurfaceTrigger.reply, hints());
      await nextWrite();
      server.onRequest(
        'GET',
        '/api/profiles',
        (_) => Completer<FakeResponse>().future,
      );

      await turn(true);

      expect(lastWrite().recentChats.single.title, '');
    });

    test('a build that finishes after it was turned on is hidden', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => gate.future);
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await Future<void>.delayed(debounce * 2);

      await lock.setEnabled(true);
      gate.complete((
        status: 200,
        body: {
          'profiles': [
            {'name': 'default'},
          ],
        },
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(storage.saved, isNotEmpty);
      expect(
        storage.saved
            .map(SurfaceSnapshot.fromJson)
            .expand((s) => s!.recentChats),
        everyElement(
          isA<RecentChat>().having((c) => c.title, 'title', isEmpty),
        ),
      );
    });

    test('brings back the titles of every profile once it is off', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(
            id: 'w1',
            title: 'Quarterly numbers',
            lastActive: 1780000000,
          ),
        ]),
        query: {'profile': 'work'},
      );
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();
      expect(
        lastWrite().recentChats.map((c) => c.title),
        contains('Quarterly numbers'),
      );
      await turn(true);
      expect(lastWrite().recentChats.map((c) => c.title), everyElement(''));

      await turn(false);

      expect(
        lastWrite().recentChats.map((c) => c.title),
        containsAll(['Quarterly numbers', 'Trip plan']),
      );
    });
  });

  group('builds', () {
    test('one at a time, and a request meanwhile runs once after', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => gate.future);
      snapshots.dispose();
      snapshots = SurfaceSnapshots(
        store: store,
        session: () => session,
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

  group('local only', () {
    late AppLockController lock;

    setUp(() async {
      lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await lock.load();
      snapshots.dispose();
      snapshots = SurfaceSnapshots(
        store: store,
        session: () => session,
        appLock: lock,
        localOnly: true,
        debounce: debounce,
        pauseWindow: const Duration(milliseconds: 100),
        now: () => now,
      )..repositories = newRepositories();
    });

    int serverCalls() => server.requests.length;

    ChatHints withRequest() => ChatHints(
      profile: 'default',
      requests: [
        RequestHint(
          threadId: 'd1',
          threadTitle: 'Trip plan',
          kind: PendingKind.approval,
          requestId: 'r1',
          seenAt: now,
        ),
      ],
    );

    test('lists the open requests without asking the server', () async {
      snapshots.chatChanged(SurfaceTrigger.request, withRequest());
      await nextWrite();

      expect(lastWrite().pending.map((p) => p.requestId), ['r1']);
      expect(serverCalls(), 0);
    });

    test('going to the background asks the server for nothing', () async {
      snapshots.chatChanged(SurfaceTrigger.request, withRequest());
      await nextWrite();

      snapshots.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(serverCalls(), 0);
    });

    test('turning App Lock off asks the server for nothing', () async {
      snapshots.chatChanged(SurfaceTrigger.request, withRequest());
      await nextWrite();

      await lock.setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await lock.setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(serverCalls(), 0);
    });

    test('records no build span', () async {
      snapshots.chatChanged(SurfaceTrigger.request, withRequest());
      await nextWrite();

      expect(tracer.spans, isEmpty);
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
      expect(span.status, StatusCode.error);
    });

    test('successful builds do not record an error', () async {
      snapshots.chatChanged(SurfaceTrigger.threads, hints());
      await nextWrite();
      expect(tracer.spans.single.status, isNot(StatusCode.error));
    });
  });
}
