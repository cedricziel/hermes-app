import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/rfb/display_socket.dart';
import 'package:hermes_app/src/bot_screen/viewer/bot_screen_viewer_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_rfb_server.dart';
import '../../support/recording_tracer.dart';
import '../bot_screen_repository_test.dart' show statusJson;

const _key = '/home/u/.hermes/profiles/work';

/// A [Random] that always draws [value], so a jittered delay is its bound
/// times [value].
class _Fixed implements Random {
  _Fixed(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

enum _Open { ok, notAllowed, unreachable }

late List<FakeDisplayChannel> channels;

FakeDisplayChannel get channel => channels.last;

void main() {
  late FakeAsync async;
  late StreamController<GatewayConnectionEvent> broadcasts;
  late BotScreenRepository repository;
  late BotScreenController screen;
  late BotScreenViewerController viewer;
  late RecordingTracer tracer;
  late List<({String path, String ticket})> opened;
  late List<Map<String, Object?>> observed;
  late List<String> logged;
  late List<_Open> openScript;
  late List<Duration> openTimes;
  late List<Completer<void>> openGates;
  late bool running;
  late bool statusFails;
  late bool observeFails;
  var minted = 0;

  void settle() => async.flushMicrotasks();

  void handshake() {
    for (final part in rfbHandshake(8, 4)) {
      channel.serverSend(part);
      settle();
    }
  }

  void update(int red) {
    channel.serverSend(
      rfbUpdate([
        rfbRawRect(0, 0, 8, 4, [red, 0, 0]),
      ]),
    );
    settle();
  }

  void closeWith(int? code) {
    channel.serverClose(code);
    settle();
  }

  void lease(String who) {
    broadcasts.add(
      GatewayConnectionEvent.received(
        Object(),
        GatewayEvent(
          type: 'display.lease',
          sessionId: '',
          payload: {
            'profile_key': _key,
            'lease': {'holder': who, 'epoch': 4},
          },
        ),
      ),
    );
    settle();
  }

  /// Runs [body] under fake time with a viewer for the profile `work`, whose
  /// screen runs and is held by Hermes.
  void scenario(void Function() body, {Random? random, bool start = true}) {
    fakeAsync((zone) {
      async = zone;
      minted = 0;
      opened = [];
      channels = [];
      observed = [];
      logged = [];
      openScript = [];
      openTimes = [];
      openGates = [];
      running = true;
      statusFails = false;
      observeFails = false;
      tracer = RecordingTracer();
      broadcasts = StreamController<GatewayConnectionEvent>.broadcast();
      repository = BotScreenRepository((
        method,
        params, {
        required timeout,
      }) async {
        switch (method) {
          case 'display.observe':
            observed.add(params);
            if (observeFails || !running) {
              throw const GatewayRpcException(5300, 'not running');
            }
            return {
              'ticket': 'ticket-${++minted}',
              'path': '/api/display/ws',
              'viewer_id': 'viewer-1',
              ...statusJson(),
            };
          case 'display.status':
            if (statusFails) throw const GatewayRpcException(5300, 'broken');
            return statusJson(running: running);
          case 'display.thumbnail':
            return {'data_url': null};
          case 'display.start':
            running = true;
            return statusJson();
        }
        throw GatewayRpcException(kGatewayMethodNotFound, method);
      });
      screen = BotScreenController(
        repository,
        broadcasts.stream,
        profile: 'work',
      );
      viewer = BotScreenViewerController(
        repository: repository,
        screen: screen,
        openSocket: (path, ticket) async {
          opened.add((path: path, ticket: ticket));
          openTimes.add(async.elapsed);
          if (openGates.isNotEmpty) await openGates.removeAt(0).future;
          final result = openScript.isEmpty ? _Open.ok : openScript.removeAt(0);
          switch (result) {
            case _Open.notAllowed:
              throw const DisplaySocketError(DisplaySocketErrorKind.notAllowed);
            case _Open.unreachable:
              throw const DisplaySocketError(
                DisplaySocketErrorKind.unreachable,
              );
            case _Open.ok:
              final next = FakeDisplayChannel();
              channels.add(next);
              return next;
          }
        },
        profile: 'work',
        random: random ?? _Fixed(0.5),
        telemetry: ConnectionTelemetry(
          tracer: tracer,
          events: (name, [attributes = const {}]) =>
              logged.add('$name $attributes'),
          serverAttributes: const {'hermes.version': '0.22.0'},
        ),
      );
      try {
        if (start) {
          viewer.start();
          settle();
        }
        body();
      } finally {
        viewer.dispose();
        screen.dispose();
        unawaited(broadcasts.close());
        settle();
      }
    });
  }

  group('opening', () {
    test('observes the profile and opens the stream with its ticket', () {
      scenario(() {
        expect(observed.single['profile'], 'work');
        expect(opened, [(path: '/api/display/ws', ticket: 'ticket-1')]);
        expect(viewer.phase, BotScreenViewerPhase.connecting);

        handshake();
        update(200);

        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(viewer.framebuffer?.width, 8);
        expect(viewer.framebuffer?.height, 4);
        expect(viewer.framebuffer?.rgba[0], 200);
        expect(viewer.revision, greaterThan(0));
      });
    });

    test('writes nothing but the handshake and update requests', () {
      scenario(() {
        handshake();
        update(10);

        final messages = clientMessages(channel.sentBytes);
        expect(messages.map((m) => m.first).toSet(), {0, 2, 3});
      });
    });
  });

  group('closing', () {
    test('disposing closes with 1000, drops the picture, reconnects not', () {
      scenario(() {
        handshake();
        update(10);
        final first = channel;

        viewer.dispose();
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(first.sentCloseCode, 1000);
        expect(opened, hasLength(1));
        expect(observed, hasLength(1));
        expect(viewer.framebuffer, isNull);
      });
    });
  });

  group('stream endings', () {
    test('4000 observes again and reconnects as a watcher', () {
      scenario(() {
        handshake();
        closeWith(4000);

        expect(observed, hasLength(2));
        expect(observed.last['viewer_id'], 'viewer-1');
        expect(opened.last.ticket, 'ticket-2');
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
      });
    });

    test('4001 shows the screen off and does not retry', () {
      scenario(() {
        handshake();
        closeWith(4001);
        async.elapse(const Duration(minutes: 1));

        expect(viewer.phase, BotScreenViewerPhase.off);
        expect(opened, hasLength(1));
        expect(viewer.framebuffer, isNull);
      });
    });

    test('4401 observes once more and reconnects with the new ticket', () {
      scenario(() {
        closeWith(4401);

        expect(observed, hasLength(2));
        expect(opened.last.ticket, 'ticket-2');
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
      });
    });

    test('a second 4401 in a row is an error', () {
      scenario(() {
        closeWith(4401);
        closeWith(4401);
        async.elapse(const Duration(minutes: 1));

        expect(viewer.phase, BotScreenViewerPhase.failed);
        expect(opened, hasLength(2));
      });
    });

    test('a 4401 after a good stream gets its one retry again', () {
      scenario(() {
        closeWith(4401);
        handshake();
        closeWith(4401);

        expect(viewer.phase, isNot(BotScreenViewerPhase.failed));
        expect(opened, hasLength(3));
      });
    });

    test('1003 is a protocol error and does not retry', () {
      scenario(() {
        handshake();
        closeWith(1003);
        async.elapse(const Duration(minutes: 1));

        expect(viewer.phase, BotScreenViewerPhase.failed);
        expect(opened, hasLength(1));
      });
    });

    test('an upgrade refused with 403 says viewing is not allowed', () {
      scenario(() {
        openScript.add(_Open.notAllowed);
        viewer.start();
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(viewer.phase, BotScreenViewerPhase.notAllowed);
        expect(opened, hasLength(1));
      }, start: false);
    });
  });

  group('reconnecting', () {
    test('an abnormal close reconnects after a jittered, growing delay', () {
      scenario(() {
        handshake();
        update(10);
        closeWith(null);

        expect(viewer.phase, BotScreenViewerPhase.reconnecting);
        expect(viewer.framebuffer, isNotNull, reason: 'dimmed, not dropped');
        async.elapse(const Duration(milliseconds: 149));
        expect(opened, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(opened, hasLength(2));

        // The second stream fails before its handshake: 600 ms bound * 0.5.
        closeWith(null);
        async.elapse(const Duration(milliseconds: 299));
        expect(opened, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(opened, hasLength(3));
      });
    });

    test('the picture comes back by itself when the network does', () {
      scenario(() {
        handshake();
        closeWith(null);
        async.elapse(const Duration(seconds: 1));
        expect(opened, hasLength(2));

        handshake();
        update(30);

        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(viewer.framebuffer?.rgba[0], 30);
      });
    });

    test('gives up after 5 attempts and Try Again starts over', () {
      scenario(() {
        openScript.addAll(List.filled(20, _Open.unreachable));
        viewer.start();
        settle();
        async.elapse(const Duration(minutes: 5));

        // The first try and five more.
        expect(opened, hasLength(6));
        expect(viewer.phase, BotScreenViewerPhase.unreachable);
        async.elapse(const Duration(minutes: 5));
        expect(opened, hasLength(6));

        openScript.clear();
        viewer.retry();
        settle();
        expect(opened, hasLength(7));
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
      }, start: false);
    });

    test('a connection that is reached again earns all 5 attempts anew', () {
      scenario(() {
        handshake();
        for (var i = 0; i < 4; i++) {
          closeWith(null);
          async.elapse(const Duration(seconds: 20));
        }
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);

        openScript.addAll(List.filled(5, _Open.unreachable));
        closeWith(null);
        async.elapse(const Duration(minutes: 5));

        expect(viewer.phase, BotScreenViewerPhase.unreachable);
        // 5 opens to reach the screen, then the 5 reconnects that are refused.
        expect(opened, hasLength(5 + 5));
      });
    });

    test('a decode failure reconnects too', () {
      scenario(() {
        handshake();
        channel.serverSend(rfbUpdate([rfbRectHeader(0, 0, 4, 4, 99)]));
        settle();
        async.elapse(const Duration(seconds: 1));

        expect(opened, hasLength(2));
      });
    });
  });

  group('observe failing', () {
    test('a stopped screen shows Off, with no retry', () {
      scenario(() {
        running = false;
        viewer.start();
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(viewer.phase, BotScreenViewerPhase.off);
        expect(opened, isEmpty);
        expect(observed, hasLength(1));
      }, start: false);
    });

    test('a running screen that cannot be observed is an error to retry', () {
      scenario(() {
        observeFails = true;
        viewer.start();
        settle();
        async.elapse(const Duration(minutes: 5));

        expect(viewer.phase, BotScreenViewerPhase.unreachable);
        expect(observed, hasLength(6));
      }, start: false);
    });

    test('a status that cannot be read is an error, not Off', () {
      scenario(() {
        running = false;
        statusFails = true;
        viewer.start();
        settle();

        expect(viewer.phase, isNot(BotScreenViewerPhase.off));
      }, start: false);
    });

    test('Start Screen starts it and then watches', () {
      scenario(() {
        running = false;
        viewer.start();
        settle();
        expect(viewer.phase, BotScreenViewerPhase.off);

        unawaited(viewer.startScreen());
        settle();

        expect(opened, hasLength(1));
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
      }, start: false);
    });
  });

  group('not visible', () {
    test('leaving the foreground closes with 1000 and drops the picture', () {
      scenario(() {
        handshake();
        update(10);
        final first = channel;

        viewer.foreground = false;
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(first.sentCloseCode, 1000);
        expect(viewer.framebuffer, isNull);
        expect(opened, hasLength(1));
        expect(observed, hasLength(1));
      });
    });

    test('returning observes again with a new ticket', () {
      scenario(() {
        handshake();
        viewer.foreground = false;
        settle();

        viewer.foreground = true;
        settle();

        expect(observed, hasLength(2));
        expect(opened.last.ticket, 'ticket-2');
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
      });
    });

    test('App Lock closes the stream and unlocking reopens it', () {
      scenario(() {
        handshake();
        final first = channel;

        viewer.unlocked = false;
        settle();
        expect(first.sentCloseCode, 1000);
        expect(viewer.framebuffer, isNull);

        viewer.unlocked = true;
        settle();
        expect(opened, hasLength(2));
      });
    });

    test('a stream that was closing does not trigger a reconnect', () {
      scenario(() {
        handshake();
        viewer.foreground = false;
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(opened, hasLength(1));
      });
    });

    test('pausing while the ticket is requested opens nothing', () {
      scenario(() {
        viewer.start();
        viewer.foreground = false;
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(channels, isEmpty);
      }, start: false);
    });
  });

  group('someone else in control', () {
    test('blanks the picture and keeps the stream open', () {
      scenario(() {
        handshake();
        update(10);
        expect(viewer.framebuffer, isNotNull);
        expect(viewer.someoneElseInControl, isFalse);

        lease('human');

        expect(viewer.someoneElseInControl, isTrue);
        expect(viewer.phase, BotScreenViewerPhase.blanked);
        expect(viewer.framebuffer, isNull);
        expect(channel.sentCloseCode, isNull);
        update(20);
        expect(viewer.framebuffer, isNull);

        lease('agent');

        expect(viewer.someoneElseInControl, isFalse);
        expect(viewer.framebuffer?.rgba[0], 20);
      });
    });

    test('shows no picture until the lease is known', () {
      scenario(() {
        statusFails = true;
        viewer.start();
        settle();
        handshake();
        update(10);

        expect(viewer.framebuffer, isNull);
        expect(viewer.phase, BotScreenViewerPhase.connecting);

        statusFails = false;
        async.elapse(const Duration(seconds: 2));

        expect(viewer.framebuffer, isNotNull);
        expect(viewer.phase, BotScreenViewerPhase.live);
      }, start: false);
    });
  });

  group('telemetry', () {
    test('a stream records only the named attributes', () {
      scenario(() {
        handshake();
        update(10);
        viewer.dispose();
        settle();

        final span = tracer.spans.single;
        expect(span.name, 'bot_screen.stream');
        expect(span.ended, isTrue);
        expect(span.attributes, {
          'hermes.version': '0.22.0',
          'outcome': 'closed',
          'close_code': 1000,
          'encodings_used': 'raw',
          'kib_received': '<256',
        });
      });
    });

    test('each ending has its outcome', () {
      scenario(() {
        final outcomes = <Object?>[];
        void ended(void Function() cause) {
          final span = tracer.spans.last;
          cause();
          outcomes.add(span.attributes['outcome']);
        }

        handshake();
        ended(() => closeWith(4001));
        expect(viewer.phase, BotScreenViewerPhase.off);

        viewer.retry();
        settle();
        ended(() => closeWith(4401));
        ended(() => closeWith(4401));

        viewer.retry();
        settle();
        handshake();
        ended(() => closeWith(1003));

        viewer.retry();
        settle();
        ended(() => closeWith(null));

        expect(outcomes, ['gone', 'ticket', 'ticket', 'protocol', 'error']);
      });
    });

    test('a run superseded while opening ends its own span, not the next', () {
      scenario(() {
        final first = Completer<void>();
        final second = Completer<void>();
        openGates.addAll([first, second]);
        viewer.start();
        settle();
        viewer.foreground = false;
        settle();
        viewer.foreground = true;
        settle();
        expect(opened, hasLength(2));

        first.complete();
        settle();
        expect(tracer.spans, hasLength(2));
        expect(tracer.spans[0].ended, isTrue);
        expect(tracer.spans[0].attributes['outcome'], 'closed');
        expect(tracer.spans[1].ended, isFalse);

        second.complete();
        settle();
        handshake();
        update(1);
        viewer.dispose();
        settle();

        expect(tracer.spans[1].ended, isTrue);
        expect(tracer.spans[1].attributes['encodings_used'], 'raw');
      }, start: false);
    });

    test('a refused upgrade is not_allowed', () {
      scenario(() {
        openScript.add(_Open.notAllowed);
        viewer.start();
        settle();

        expect(tracer.spans.single.attributes['outcome'], 'not_allowed');
      }, start: false);
    });

    test('an ending the app did not cause is logged with step and type', () {
      scenario(() {
        handshake();
        update(1);
        closeWith(4001);

        expect(logged, [
          'bot_screen.stream_failed {step: decode, error_type: gone}',
        ]);
      });
    });

    test('a stream that never finished its handshake logs that step', () {
      scenario(() {
        closeWith(null);

        expect(logged.first, contains('step: handshake'));
        expect(logged.first, contains('error_type: closed'));
      });
    });

    test('a refused upgrade and an observe failure are logged', () {
      scenario(() {
        openScript.add(_Open.notAllowed);
        viewer.start();
        settle();
        expect(logged.last, contains('step: connect'));
        expect(logged.last, contains('error_type: notAllowed'));

        observeFails = true;
        viewer.retry();
        settle();
        expect(logged.where((l) => l.contains('step: observe')), isNotEmpty);
      }, start: false);
    });

    test('closing it ourselves logs no failure', () {
      scenario(() {
        handshake();
        viewer.foreground = false;
        settle();
        viewer.dispose();
        settle();

        expect(
          logged.where((l) => l.startsWith('bot_screen.stream_failed')),
          isEmpty,
        );
      });
    });

    test('no span or log carries the ticket, the id or the path', () {
      scenario(() {
        handshake();
        update(1);
        closeWith(4401);
        handshake();
        closeWith(null);
        async.elapse(const Duration(seconds: 30));
        viewer.dispose();
        settle();

        final everything = [
          for (final Span span in tracer.spans)
            (span as RecordingSpan).attributes.toString(),
          ...logged,
        ].join('\n');
        for (final secret in ['ticket-', 'viewer-1', '/api/display/ws']) {
          expect(everything, isNot(contains(secret)));
        }
      });
    });
  });
}
