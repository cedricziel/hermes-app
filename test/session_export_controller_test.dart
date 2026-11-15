import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/session_export_controller.dart';
import 'package:hermes_app/src/chat/session_export_telemetry.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/chat/widgets/session_export_failure.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import 'support/fake_hermes_server.dart';
import 'support/recorded_breadcrumbs.dart';
import 'support/recorded_events.dart';
import 'support/recording_tracer.dart';

const _marker = 'MARKER-8d1f';

/// Serves the body in chunks the test releases, so a request can be observed
/// while it is in flight.
class _ChunkedServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  // Closed by the tests that finish the body.
  // ignore: close_sinks
  final chunks = StreamController<Uint8List>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody(
      chunks.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  HermesApiClient client() => HermesApiClient(
    Dio(BaseOptions(baseUrl: 'http://hermes.test'))..httpClientAdapter = this,
  );
}

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;

  void fire() {
    if (!cancelled) callback();
  }
}

Uint8List _json(Object o) => Uint8List.fromList(utf8.encode(jsonEncode(o)));

Uint8List _session({int messages = 2, String content = 'hi'}) => _json({
  'id': 'abc',
  'messages': [
    for (var i = 0; i < messages; i++) {'role': 'user', 'content': content},
  ],
});

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late RecordedBreadcrumbs crumbs;
  late List<({String name, Uint8List bytes})> saves;
  late List<_FakeTimer> timers;
  late int cleared;
  late Completer<bool>? saveGate;
  var saveResult = true;

  SessionExportController build(
    HermesApiClient api, {
    bool withClear = true,
    bool throwsOnSave = false,
  }) => SessionExportController(
    api: api,
    save: (name, bytes) async {
      saves.add((name: name, bytes: bytes));
      if (throwsOnSave) throw StateError('sheet broke $_marker');
      return saveGate?.future ?? saveResult;
    },
    telemetry: SessionExportTelemetry(
      ConnectionTelemetry(
        events: (n, [a = const {}]) => events(n, a),
        tracer: tracer,
        serverAttributes: const {'hermes.version': '0.22.2'},
      ),
      crumbs.breadcrumbs,
    ),
    clearTemporaryFiles: withClear ? () async => cleared++ : null,
    timer: (d, cb) {
      final t = _FakeTimer(cb);
      timers.add(t);
      return t;
    },
  );

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    crumbs = RecordedBreadcrumbs();
    saves = [];
    timers = [];
    cleared = 0;
    saveGate = null;
    saveResult = true;
  });

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('begin', () {
    test('a chat without a profile is not offered and nothing is sent', () {
      final c = build(server.client());
      expect(c.begin('abc', null), isFalse);
      expect(c.phase, isNull);
      expect(server.requests, isEmpty);
    });

    test('shows the confirmation and sends nothing', () {
      final c = build(server.client());
      expect(c.begin('abc', 'work'), isTrue);
      expect(c.phase, isA<SessionExportConfirm>());
      expect(c.busy, isFalse);
      expect(server.requests, isEmpty);
    });
  });

  group('a complete export', () {
    test('hands the received bytes to the save callback unchanged', () async {
      final body = _session();
      server.on('GET', '/api/sessions/abc/export', body);
      final c = build(server.client())
        ..begin('abc', 'work', fileName: 'x.json');
      final result = await c.confirm();
      expect(result, SessionExportSaveResult.saved);
      expect(saves.single.name, 'x.json');
      expect(saves.single.bytes, body);
      expect(c.phase, isNull);
      expect(c.busy, isFalse);
      expect(c.holdsBytes, isFalse);
      expect(server.requests.single.queryParameters['profile'], 'work');
    });

    test(
      'a cancelled save sheet is reported and keeps the bytes out',
      () async {
        server.on('GET', '/api/sessions/abc/export', _session());
        saveResult = false;
        final c = build(server.client())..begin('abc', 'work');
        expect(await c.confirm(), SessionExportSaveResult.cancelled);
        expect(c.holdsBytes, isFalse);
        expect(crumbs.named('session_export.cancelled'), hasLength(1));
        expect(crumbs.named('session_export.saved'), isEmpty);
      },
    );

    test('a second press while it runs sends nothing', () async {
      final chunked = _ChunkedServer();
      final c = build(chunked.client())..begin('abc', 'work');
      final first = c.confirm();
      expect(c.busy, isTrue);
      expect(await c.confirm(), isNull);
      expect(c.begin('other', 'work'), isFalse);
      await tick();
      expect(chunked.requests, hasLength(1));
      chunked.chunks.add(_session());
      await chunked.chunks.close();
      await first;
      expect(chunked.requests, hasLength(1));
      expect(saves, hasLength(1));
    });
  });

  group('progress', () {
    test('forwards received bytes and stalls after 10 s without one', () async {
      final chunked = _ChunkedServer();
      final c = build(chunked.client())..begin('abc', 'work');
      final done = c.confirm();
      expect(c.phase, isA<SessionExportProgress>());
      expect((c.phase! as SessionExportProgress).stalled, isFalse);
      timers.single.fire();
      expect((c.phase! as SessionExportProgress).stalled, isTrue);

      final body = _session();
      chunked.chunks.add(Uint8List.sublistView(body, 0, 10));
      await tick();
      await tick();
      final p = c.phase! as SessionExportProgress;
      expect(p.stalled, isFalse);
      expect(p.receivedBytes, 10);
      expect(timers.single.cancelled, isTrue);

      chunked.chunks.add(Uint8List.sublistView(body, 10));
      await chunked.chunks.close();
      await done;
    });

    test('a byte before 10 s means the stall never shows', () async {
      final chunked = _ChunkedServer();
      final c = build(chunked.client())..begin('abc', 'work');
      final done = c.confirm();
      chunked.chunks.add(Uint8List(5));
      await tick();
      await tick();
      timers.single.fire();
      expect((c.phase! as SessionExportProgress).stalled, isFalse);
      c.cancel();
      await done;
    });
  });

  group('failures', () {
    Future<SessionExportFailure> failWith(
      int status,
      Object? body, {
      String id = 'abc',
    }) async {
      server.on('GET', '/api/sessions/$id/export', body, status: status);
      final c = build(server.client())..begin(id, 'work');
      expect(await c.confirm(), isNull);
      expect(saves, isEmpty);
      expect(c.holdsBytes, isFalse);
      expect(c.busy, isFalse);
      return (c.phase! as SessionExportFailed).kind;
    }

    test('maps statuses to kinds', () async {
      expect(
        await failWith(404, {'detail': 'Session not found'}),
        SessionExportFailure.gone,
      );
      expect(
        await failWith(404, {'detail': "Profile 'x' not found"}),
        SessionExportFailure.profileMissing,
      );
      expect(
        await failWith(400, {'detail': 'bad'}),
        SessionExportFailure.profileInvalid,
      );
      expect(
        await failWith(404, {'detail': 'Not Found'}),
        SessionExportFailure.unsupported,
      );
      expect(await failWith(503, {}), SessionExportFailure.unreadable);
      expect(await failWith(500, {}), SessionExportFailure.failed);
    });

    test('an invalid id is failed, not a crash, and sends nothing', () async {
      final c = build(server.client())..begin('..', 'work');
      await c.confirm();
      expect(
        (c.phase! as SessionExportFailed).kind,
        SessionExportFailure.failed,
      );
      expect(server.requests, isEmpty);
    });

    test('a truncated or wrong-shaped body is incomplete', () async {
      for (final body in [
        Uint8List.fromList(utf8.encode('{"id":"abc","messages":[{"role"')),
        _json({'id': 'abc'}),
        _json([1]),
      ]) {
        server.on('GET', '/api/sessions/abc/export', body);
        final c = build(server.client())..begin('abc', 'work');
        await c.confirm();
        expect(
          (c.phase! as SessionExportFailed).kind,
          SessionExportFailure.incomplete,
        );
        expect(saves, isEmpty);
        expect(c.holdsBytes, isFalse);
      }
    });

    test('a connection that drops after bytes is incomplete', () async {
      final chunked = _ChunkedServer();
      final c = build(chunked.client())..begin('abc', 'work');
      final done = c.confirm();
      chunked.chunks.add(Uint8List(5));
      await tick();
      await tick();
      chunked.chunks.addError(const HttpException('closed'));
      await done;
      expect(
        (c.phase! as SessionExportFailed).kind,
        SessionExportFailure.incomplete,
      );
    });

    test('retry returns to the confirmation and sends nothing', () async {
      server.on('GET', '/api/sessions/abc/export', {}, status: 500);
      final c = build(server.client())..begin('abc', 'work');
      await c.confirm();
      c.retry();
      expect(c.phase, isA<SessionExportConfirm>());
      expect(server.requests, hasLength(1));
      c.close();
      expect(c.phase, isNull);
    });

    test('a save that throws is failed and keeps no bytes', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      final c = build(server.client(), throwsOnSave: true)
        ..begin('abc', 'work');
      expect(await c.confirm(), isNull);
      expect(
        (c.phase! as SessionExportFailed).kind,
        SessionExportFailure.failed,
      );
      expect(c.holdsBytes, isFalse);
      expect(c.busy, isFalse);
    });
  });

  group('drops', () {
    for (final (name, drop)
        in <(String, void Function(SessionExportController))>[
          ('cancel', (c) => c.cancel()),
          ('a profile or server change', (c) => c.contextChanged()),
          ('sign-out', (c) => c.signedOut()),
          ('App Lock', (c) => c.locked()),
        ]) {
      test('$name ends the request silently and saves nothing', () async {
        final chunked = _ChunkedServer();
        final c = build(chunked.client())..begin('abc', 'work');
        final done = c.confirm();
        chunked.chunks.add(Uint8List(5));
        await tick();
        await tick();
        drop(c);
        expect(c.phase, isNull);
        expect(c.busy, isFalse);
        expect(c.holdsBytes, isFalse);
        expect(await done, isNull);
        expect(c.phase, isNull);
        expect(saves, isEmpty);
        expect(tracer.spans.single.attributes['outcome'], 'cancelled');
        expect(events.namesStartingWith('session_export'), isEmpty);
        // It is free for the next export.
        expect(c.begin('abc', 'work'), isTrue);
      });
    }

    test('a lock while the body is held drops it before the save', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      final c = build(server.client())..begin('abc', 'work');
      final done = c.confirm();
      c.locked();
      expect(await done, isNull);
      expect(saves, isEmpty);
      expect(c.holdsBytes, isFalse);
    });

    test('a save that returns after a lock reports droppedByLock', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      saveGate = Completer<bool>();
      final c = build(server.client())..begin('abc', 'work');
      final done = c.confirm();
      await tick();
      await tick();
      await tick();
      expect(saves, hasLength(1));
      expect(c.busy, isTrue);
      c.locked();
      expect(c.holdsBytes, isFalse);
      saveGate!.complete(true);
      expect(await done, SessionExportSaveResult.droppedByLock);
      expect(c.busy, isFalse);
      expect(crumbs.named('session_export.saved'), isEmpty);
    });
  });

  group('temporary files', () {
    test('cleared when the save sheet returns, saved or cancelled', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      final c = build(server.client())..begin('abc', 'work');
      await c.confirm();
      expect(cleared, 1);
      saveResult = false;
      c.begin('abc', 'work');
      await c.confirm();
      expect(cleared, 2);
    });

    test('cleared on lock and on sign-out', () async {
      final c = build(server.client());
      c.locked();
      expect(cleared, 1);
      c.signedOut();
      expect(cleared, 2);
    });

    test('nothing to clear where no hook is given', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      final c = build(server.client(), withClear: false)..begin('abc', 'work');
      expect(await c.confirm(), SessionExportSaveResult.saved);
      c.locked();
    });
  });

  group('privacy', () {
    test('a marker in id, profile, name and body reaches no sink', () async {
      final logged = <String>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (d) => logged.add('${d.exception} ${d.stack}');
      final oldPrint = debugPrint;
      debugPrint = (m, {wrapWidth}) => logged.add('$m');
      addTearDown(() {
        FlutterError.onError = oldOnError;
        debugPrint = oldPrint;
      });
      final id = 'id$_marker';
      final enc = Uri.encodeComponent(id);
      final bodies = <Object>[
        Uint8List.fromList(
          utf8.encode('{"id":"$_marker","messages":[{"x":"$_marker'),
        ),
        _session(content: _marker),
      ];
      final errors = <String>[];
      for (final body in bodies) {
        server.on('GET', '/api/sessions/$enc/export', body);
        final c = build(server.client())
          ..begin(id, 'profile$_marker', fileName: 'name$_marker.json');
        await c.confirm();
        errors.add('${c.phase} ${c.phase.runtimeType}');
      }
      server.on('GET', '/api/sessions/$enc/export', {
        'detail': "Profile '$_marker' not found",
      }, status: 404);
      final c = build(server.client())
        ..begin(id, 'profile$_marker', fileName: 'name$_marker.json');
      await c.confirm();
      final c2 = build(server.client(), throwsOnSave: true);
      server.on('GET', '/api/sessions/$enc/export', _session());
      c2.begin(id, 'profile$_marker');
      await c2.confirm();

      final sinks = [
        ...logged,
        ...errors,
        crumbs.text,
        for (final s in tracer.spans) ...[
          s.name,
          s.attributes.keys.join(' '),
          s.attributes.values.join(' '),
          s.eventDetails.join(' '),
          '${s.statusDescription}',
        ],
        for (final n in events.namesStartingWith('')) n,
        for (final n in events.namesStartingWith('session_export'))
          ...events.named(n).map((a) => '$a'),
      ].join('\n');
      expect(sinks, isNot(contains(_marker)));
      expect(sinks, isNotEmpty);
    });
  });

  group('telemetry', () {
    test(
      'a saved export: started, ready span with buckets, saved crumb',
      () async {
        server.on('GET', '/api/sessions/abc/export', _session(messages: 3));
        final c = build(server.client())..begin('abc', 'work');
        await c.confirm();
        final span = tracer.spans.single;
        expect(span.name, 'session_export.fetch');
        expect(span.ended, isTrue);
        expect(span.attributes, {
          'hermes.version': '0.22.2',
          'outcome': 'ready',
          'bytes_bucket': '<100KB',
          'messages_bucket': '1-50',
        });
        expect(crumbs.all.map((c) => c.$1), [
          'session_export.started',
          'session_export.saved',
        ]);
        expect(events.namesStartingWith('session_export'), isEmpty);
      },
    );

    test('a failure logs its reason and the outcome name only', () async {
      server.on('GET', '/api/sessions/abc/export', {
        'detail': "Profile 'x' not found",
      }, status: 404);
      final c = build(server.client())..begin('abc', 'work');
      await c.confirm();
      expect(tracer.spans.single.attributes['outcome'], 'profile_missing');
      expect(events.named('session_export.failed'), [
        {'reason': 'profile_missing'},
      ]);
    });

    test('a user cancel is a crumb and a cancelled span, no event', () async {
      final chunked = _ChunkedServer();
      final c = build(chunked.client())..begin('abc', 'work');
      final done = c.confirm();
      await tick();
      c.cancel();
      await done;
      expect(crumbs.named('session_export.cancelled'), hasLength(1));
      expect(tracer.spans.single.attributes['outcome'], 'cancelled');
    });

    test('every failure kind has a snake_case slug', () {
      expect(SessionExportFailure.values.map((k) => k.slug), [
        'gone',
        'unsupported',
        'profile_missing',
        'profile_invalid',
        'unreadable',
        'lost',
        'incomplete',
        'offline',
        'failed',
      ]);
    });

    test('buckets', () {
      expect(sessionExportBytesBucket(0), '<100KB');
      expect(sessionExportBytesBucket(6 * 1024 * 1024), '<50MB');
      expect(sessionExportBytesBucket(60 * 1024 * 1024), '>=50MB');
      expect(sessionExportMessagesBucket(0), '0');
      expect(sessionExportMessagesBucket(501), '>500');
    });

    test('a broken tracer never breaks the export', () async {
      server.on('GET', '/api/sessions/abc/export', _session());
      final c = SessionExportController(
        api: server.client(),
        save: (n, b) async => true,
        telemetry: SessionExportTelemetry(
          ConnectionTelemetry(tracer: ThrowingTracer()),
        ),
      )..begin('abc', 'work');
      expect(await c.confirm(), SessionExportSaveResult.saved);
    });
  });
}
