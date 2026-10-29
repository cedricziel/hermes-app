import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_viewer_ids.dart';
import 'package:hermes_app/src/bot_screen/viewer/bot_screen_viewer_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_display_server.dart';
import '../../support/fake_gateway.dart';
import '../../support/fake_rfb_server.dart';
import '../../support/recording_tracer.dart';

class _Fixed implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

late List<FakeDisplayChannel> channels;

FakeDisplayChannel get channel => channels.last;

void main() {
  late FakeAsync async;
  late FakeGateway gateway;
  late FakeDisplayServer server;
  late HermesGatewayTransport transport;
  late BotScreenController screen;
  late BotScreenViewerController viewer;
  late BotScreenViewerIds ids;
  late RecordingTracer tracer;
  late List<String> logged;
  late int connects;

  void settle() => async.flushMicrotasks();

  void handshake() {
    for (final part in rfbHandshake(8, 4)) {
      channel.serverSend(part);
      settle();
    }
    channel.serverSend(
      rfbUpdate([
        rfbRawRect(0, 0, 8, 4, [0, 0, 0]),
      ]),
    );
    settle();
  }

  /// Runs [body] under fake time with a viewer of the profile `work` that
  /// watches a live stream.
  void scenario(
    void Function() body, {
    bool broadcasts = true,
    bool live = true,
    Duration coverGrace = const Duration(seconds: 2),
  }) {
    fakeAsync((zone) {
      async = zone;
      connects = 0;
      channels = [];
      logged = [];
      tracer = RecordingTracer();
      ids = BotScreenViewerIds();
      gateway = FakeGateway();
      server = FakeDisplayServer(gateway, connection: () => connects)
        ..broadcasts = broadcasts;
      transport = HermesGatewayTransport(
        connect: () {
          connects++;
          return gateway.connect();
        },
      );
      final telemetry = ConnectionTelemetry(
        tracer: tracer,
        events: (name, [attributes = const {}]) =>
            logged.add('$name $attributes'),
      );
      final repository = BotScreenRepository(
        transport.requestKeepingConnection,
        connectionRpc: transport.requestKeepingConnectionOnClient,
        pinnedRpc: transport.requestOn,
        telemetry: telemetry,
      );
      screen = BotScreenController(
        repository,
        transport.connectionEvents,
        profile: 'work',
        viewerIds: ids,
        events: telemetry.events,
      );
      viewer = BotScreenViewerController(
        repository: repository,
        screen: screen,
        openSocket: (path, ticket) async {
          final next = server.openStream(ticket);
          channels.add(next);
          return next;
        },
        profile: 'work',
        random: _Fixed(),
        telemetry: telemetry,
        coverGrace: coverGrace,
      );
      try {
        viewer.start();
        settle();
        if (live) handshake();
        body();
      } finally {
        viewer.dispose();
        screen.dispose();
        transport.close();
        settle();
      }
    });
  }

  int count(Iterable<String> events, String name) =>
      events.where((e) => e.startsWith(name)).length;

  group('taking over', () {
    test('acquires with the observed id on the observing connection and is '
        'in control from the answer, without a broadcast', () {
      scenario(broadcasts: false, () {
        expect(viewer.control, BotScreenControl.watching);
        expect(viewer.canTakeOver, isTrue);

        unawaited(viewer.takeOver());
        settle();

        expect(server.acquired, ['viewer-1']);
        expect(viewer.control, BotScreenControl.inControl);
        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(viewer.framebuffer, isNotNull);
        expect(connects, 1);
        expect(logged, ['bot_screen.takeover {outcome: acquired}']);
      });
    });

    test('says it is acquiring until the answer comes', () {
      scenario(() {
        gateway.silent.add('display.lease.acquire');

        unawaited(viewer.takeOver());
        settle();

        expect(viewer.control, BotScreenControl.acquiring);
        expect(viewer.canTakeOver, isFalse);
      });
    });

    test('a connection that was replaced observes again and retries once '
        'with the new id', () {
      scenario(() {
        gateway.drop();
        settle();

        unawaited(viewer.takeOver());
        settle();

        expect(connects, 2);
        expect(server.mintedIds, ['viewer-1', 'viewer-2']);
        expect(server.observedWith.last, 'viewer-1');
        expect(server.acquired, ['viewer-2']);
        expect(viewer.control, BotScreenControl.inControl);
        expect(logged, [
          'bot_screen.takeover {outcome: retried}',
          'bot_screen.takeover {outcome: acquired}',
        ]);
      });
    });

    test('the retry reconnects the stream with the new ticket, so input goes '
        'on the stream of the id that holds the lease', () {
      scenario(() {
        gateway.drop();
        settle();
        final first = channel;

        unawaited(viewer.takeOver());
        settle();

        expect(first.sentCloseCode, 1000);
        expect(channels, hasLength(2));
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(viewer.control, BotScreenControl.inControl);
      });
    });

    test('a take over whose retry is refused still follows the new id with '
        'its stream, so a later one holds the lease on the stream it uses', () {
      scenario(() {
        gateway.drop();
        settle();
        server.refuseAcquire = true;
        unawaited(viewer.takeOver());
        settle();
        expect(viewer.control, BotScreenControl.watching);
        handshake();
        server.refuseAcquire = false;

        unawaited(viewer.takeOver());
        settle();

        expect(viewer.control, BotScreenControl.inControl);
        expect(server.openStreams, [server.holderId]);
      });
    });

    test(
      'in control means the stream\'s own id holds the lease: a lease naming '
      'another id of this app is watching, which Take over repairs',
      () {
        scenario(() {
          unawaited(viewer.takeOver());
          settle();
          expect(viewer.control, BotScreenControl.inControl);

          // The lease now names another id of this app, not the stream's.
          ids.add('viewer-other');
          screen.adoptLease(
            BotScreenLease(
              holder: BotScreenHolder.human,
              viewerHash: BotScreenViewerIds.hashOf('viewer-other'),
              epoch: 99,
            ),
          );
          settle();

          expect(viewer.control, BotScreenControl.watching);
          expect(viewer.canTakeOver, isTrue);
          expect(viewer.phase, BotScreenViewerPhase.live);
        });
      },
    );

    test('a viewer_mismatch observes again and retries once', () {
      scenario(() {
        server.forget(connects);

        unawaited(viewer.takeOver());
        settle();

        expect(server.observedWith, [null, 'viewer-1']);
        expect(server.acquired, ['viewer-1', 'viewer-2']);
        expect(viewer.control, BotScreenControl.inControl);
      });
    });

    test('a second failure is refused and the viewer keeps watching', () {
      scenario(() {
        server.refuseAcquire = true;

        unawaited(viewer.takeOver());
        settle();

        expect(server.acquired, hasLength(2));
        expect(viewer.control, BotScreenControl.watching);
        expect(logged, [
          'bot_screen.takeover {outcome: retried}',
          'bot_screen.takeover {outcome: refused}',
        ]);
      });
    });

    test('another refusal is not retried', () {
      scenario(() {
        gateway.handlers['display.lease.acquire'] = (_) =>
            throw const FakeRpcError(5300, 'broken');

        unawaited(viewer.takeOver());
        settle();

        expect(connects, 1);
        expect(viewer.control, BotScreenControl.watching);
        expect(logged, ['bot_screen.takeover {outcome: refused}']);
      });
    });

    test('is not offered while someone else is in control or no picture '
        'shows', () {
      scenario(() {
        server.takeBy('someone-else');
        settle();

        expect(viewer.phase, BotScreenViewerPhase.blanked);
        expect(viewer.canTakeOver, isFalse);
        unawaited(viewer.takeOver());
        settle();
        expect(server.acquired, isEmpty);
      });
      scenario(live: false, () {
        expect(viewer.canTakeOver, isFalse);
      });
    });

    test('names the same viewer id for the lease and the stream', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();

        expect(server.holderId, 'viewer-1');
        expect(server.observedWith, [null]);
        expect(ids.holds(BotScreenViewerIds.hashOf('viewer-1')), isTrue);
      });
    });
  });

  group('handing back', () {
    test(
      'releases on the same connection and watches again from the answer',
      () {
        scenario(broadcasts: false, () {
          unawaited(viewer.takeOver());
          settle();

          unawaited(viewer.handBack());
          settle();

          expect(server.released, ['viewer-1']);
          expect(viewer.control, BotScreenControl.watching);
          expect(viewer.canTakeOver, isTrue);
          expect(connects, 1);
          expect(logged.last, 'bot_screen.handback {reason: button}');
        });
      },
    );

    test('says it is handing back until the answer comes', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        gateway.silent.add('display.lease.release');

        unawaited(viewer.handBack());
        settle();

        expect(viewer.control, BotScreenControl.releasing);
      });
    });

    test('the stream stays open', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        unawaited(viewer.handBack());
        settle();

        expect(channel.sentCloseCode, isNull);
        expect(viewer.phase, BotScreenViewerPhase.live);
      });
    });

    test('after the gateway connection changed, a hand back closes the stream '
        'cleanly, which the bridge takes as a release, and watches again', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        final first = channel;
        gateway.drop();
        settle();

        unawaited(viewer.handBack());
        settle();

        // The lease named an id the new connection cannot release, so the
        // stream that holds it is closed instead of taking the lease again
        // with a new id, which the bridge would answer by evicting the stream.
        expect(server.acquired, ['viewer-1']);
        expect(first.sentCloseCode, 1000);
        expect(server.holder, 'agent');
        expect(viewer.control, BotScreenControl.watching);
        expect(count(logged, 'bot_screen.lost_control'), 0);
        expect(logged.last, 'bot_screen.handback {reason: button}');
        expect(channels, hasLength(2));
        handshake();
        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(viewer.control, BotScreenControl.watching);
      });
    });

    test('a 4000 that arrives while handing back is not lost control', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        gateway.silent.add('display.lease.release');

        unawaited(viewer.handBack());
        settle();
        channel.serverClose(4000);
        settle();

        expect(count(logged, 'bot_screen.lost_control'), 0);
        expect(viewer.control, isNot(BotScreenControl.lost));
      });
    });

    test('a release that fails twice is an error and leaves control as it '
        'was', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        gateway.handlers['display.lease.release'] = (_) =>
            throw const FakeRpcError(5300, 'broken');

        unawaited(viewer.handBack());
        settle();

        expect(viewer.control, BotScreenControl.inControl);
        expect(logged.last, 'bot_screen.handback {reason: error}');
      });
    });

    test('does nothing when this device is not in control', () {
      scenario(() {
        unawaited(viewer.handBack());
        settle();

        expect(server.released, isEmpty);
        expect(logged, isEmpty);
      });
    });

    test('a forced hand back goes through the screen and logs its reason', () {
      scenario(() {
        server.takeBy('stranded-before-restart');
        settle();
        expect(screen.someoneElseInControl, isTrue);

        unawaited(viewer.forceHandBack());
        settle();

        expect(server.released, [null]);
        expect(server.holder, 'agent');
        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(logged.last, 'bot_screen.handback {reason: force}');
      });
    });
  });

  group('losing control', () {
    test('another viewer taking the lease moves to lost and says why', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();

        server.takeBy('someone-else');
        settle();

        expect(viewer.control, BotScreenControl.lost);
        expect(viewer.phase, BotScreenViewerPhase.blanked);
        expect(logged.where((e) => !e.startsWith('bot_screen.stream_failed')), [
          'bot_screen.takeover {outcome: acquired}',
          'bot_screen.lost_control {cause: other_holder}',
        ]);
      });
    });

    test('a 4000 close moves to lost, reconnects as a watcher and logs once '
        'though the lease change is read afterwards', () {
      scenario(broadcasts: false, () {
        unawaited(viewer.takeOver());
        settle();

        server.takeBy('someone-else');
        channel.serverClose(4000);
        settle();

        expect(viewer.control, BotScreenControl.lost);
        expect(viewer.phase, BotScreenViewerPhase.blanked);
        expect(channels, hasLength(2));
        expect(count(logged, 'bot_screen.lost_control'), 1);
        expect(
          logged,
          contains('bot_screen.lost_control {cause: control_taken}'),
        );
        expect(server.observedWith, hasLength(2));
      });
    });

    test('a lease that went back to Hermes is lost too, and can be taken '
        'again', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();

        server.giveToAgent();
        settle();

        expect(viewer.control, BotScreenControl.lost);
        expect(viewer.canTakeOver, isTrue);

        unawaited(viewer.takeOver());
        settle();
        expect(viewer.control, BotScreenControl.inControl);
      });
    });

    test('the notice says who has the screen now', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        server.giveToAgent();
        settle();
        expect(viewer.control, BotScreenControl.lost);
        expect(viewer.lostText, 'Hermes took control back.');

        unawaited(viewer.takeOver());
        settle();
        server.takeBy('someone-else');
        settle();
        expect(viewer.control, BotScreenControl.lost);
        expect(viewer.lostText, 'Someone else took control.');
      });
    });

    test('dismissing the notice goes back to watching', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        server.giveToAgent();
        settle();

        viewer.dismissLost();

        expect(viewer.control, BotScreenControl.watching);
      });
    });

    test('handing back is not losing control', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        unawaited(viewer.handBack());
        settle();

        expect(viewer.control, BotScreenControl.watching);
        expect(count(logged, 'bot_screen.lost_control'), 0);
      });
    });
  });

  group('while in control', () {
    void takeOver() {
      unawaited(viewer.takeOver());
      settle();
    }

    test('backgrounding closes the stream with 4100 at once and keeps the '
        'lease', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.foreground = false;
        settle();

        expect(first.sentCloseCode, 4100);
        expect(server.holder, 'human');
        expect(server.released, isEmpty);
      });
    });

    test('returning observes with the old id and is still in control without '
        'asking again', () {
      scenario(() {
        takeOver();
        viewer.foreground = false;
        settle();

        viewer.foreground = true;
        settle();

        expect(server.observedWith.last, 'viewer-1');
        expect(server.acquired, ['viewer-1']);
        expect(channels, hasLength(2));
        handshake();
        expect(viewer.control, BotScreenControl.inControl);
        expect(viewer.phase, BotScreenViewerPhase.live);
      });
    });

    test('returning on a new connection takes the lease with the new id '
        'without asking', () {
      scenario(() {
        takeOver();
        viewer.foreground = false;
        settle();
        gateway.drop();
        settle();

        viewer.foreground = true;
        settle();

        expect(server.mintedIds, ['viewer-1', 'viewer-2']);
        expect(server.acquired, ['viewer-1', 'viewer-2']);
        expect(server.holderId, 'viewer-2');
        handshake();
        expect(viewer.control, BotScreenControl.inControl);
        expect(logged.last, 'bot_screen.takeover {outcome: resumed}');
      });
    });

    test('a cover of 1 second keeps the stream', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.unlocked = false;
        settle();
        async.elapse(const Duration(seconds: 1));
        viewer.unlocked = true;
        settle();
        async.elapse(const Duration(seconds: 5));

        expect(first.sentCloseCode, isNull);
        expect(channels, hasLength(1));
        expect(server.observedWith, hasLength(1));
        expect(viewer.control, BotScreenControl.inControl);
      });
    });

    test('a cover of 3 seconds closes the stream with 4100 after 2 seconds '
        'and returning keeps control', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.unlocked = false;
        settle();
        async.elapse(const Duration(milliseconds: 1900));
        expect(first.sentCloseCode, isNull);
        async.elapse(const Duration(milliseconds: 200));
        expect(first.sentCloseCode, 4100);
        async.elapse(const Duration(seconds: 1));
        viewer.unlocked = true;
        settle();

        expect(channels, hasLength(2));
        handshake();
        expect(viewer.control, BotScreenControl.inControl);
        expect(server.released, isEmpty);
      });
    });

    test('a stream that ends while covered is opened again once the cover '
        'passes', () {
      scenario(() {
        takeOver();

        viewer.unlocked = false;
        settle();
        channel.serverClose(1006);
        settle();
        async.elapse(const Duration(seconds: 1));
        viewer.unlocked = true;
        settle();

        expect(channels, hasLength(2));
        handshake();
        expect(viewer.control, BotScreenControl.inControl);
      });
    });

    test('the picture is hidden at once while covered, though the stream stays '
        'open through the grace period', () {
      scenario(() {
        takeOver();
        final first = channel;
        expect(viewer.framebuffer, isNotNull);

        viewer.unlocked = false;
        settle();

        expect(viewer.framebuffer, isNull);
        expect(viewer.phase, BotScreenViewerPhase.connecting);
        expect(first.sentCloseCode, isNull);

        async.elapse(const Duration(seconds: 1));
        viewer.unlocked = true;
        settle();

        expect(viewer.framebuffer, isNotNull);
        expect(viewer.phase, BotScreenViewerPhase.live);
        expect(channels, hasLength(1));
      });
    });

    test('backgrounding during the grace closes at once', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.unlocked = false;
        settle();
        async.elapse(const Duration(milliseconds: 500));
        viewer.foreground = false;
        settle();

        expect(first.sentCloseCode, 4100);
      });
    });

    test('another route covering the viewer closes with 4100 at once', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.visible = false;
        settle();

        expect(first.sentCloseCode, 4100);
      });
    });

    test('disposing while in control sends a release and closes with 1000', () {
      scenario(() {
        takeOver();
        final first = channel;

        viewer.dispose();
        settle();

        expect(server.released, ['viewer-1']);
        expect(first.sentCloseCode, 1000);
      });
    });
  });

  group('while watching', () {
    test('every pause still closes with 1000', () {
      for (final pause in <void Function()>[
        () => viewer.foreground = false,
        () => viewer.unlocked = false,
        () => viewer.visible = false,
      ]) {
        scenario(() {
          final first = channel;

          pause();
          settle();

          expect(first.sentCloseCode, 1000);
          expect(server.released, isEmpty);
        });
      }
    });

    test('a cover closes at once, with no grace', () {
      scenario(() {
        final first = channel;

        viewer.unlocked = false;
        settle();

        expect(first.sentCloseCode, 1000);
      });
    });
  });

  group('shutting down', () {
    for (final reason in ['sign_out', 'profile', 'server', 'close']) {
      test('$reason releases on the pinned connection, then closes with '
          '1000', () {
        scenario(() {
          unawaited(viewer.takeOver());
          settle();
          final first = channel;
          Object? closedAtRelease = 'not called';
          gateway.handlers['display.lease.release'] = (params) {
            closedAtRelease = first.sentCloseCode;
            server.released.add(params['viewer_id'] as String?);
            server.giveToAgent();
            return {'lease': server.lease};
          };

          unawaited(viewer.shutDown(reason));
          settle();

          expect(closedAtRelease, isNull);
          expect(first.sentCloseCode, 1000);
          expect(server.holder, 'agent');
          expect(logged.last, 'bot_screen.handback {reason: $reason}');
        });
      });
    }

    test('a release that gets no answer still closes after 2 seconds', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        final first = channel;
        gateway.silent.add('display.lease.release');

        unawaited(viewer.shutDown('sign_out'));
        settle();
        async.elapse(const Duration(milliseconds: 1900));
        expect(first.sentCloseCode, isNull);
        async.elapse(const Duration(milliseconds: 200));
        settle();

        expect(first.sentCloseCode, 1000);
      });
    });

    test('after the gateway connection changed it closes the stream cleanly '
        'and logs the reason, not lost control', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        final first = channel;
        gateway.drop();
        settle();

        unawaited(viewer.shutDown('sign_out'));
        settle();

        expect(first.sentCloseCode, 1000);
        expect(server.holder, 'agent');
        expect(server.acquired, ['viewer-1']);
        expect(count(logged, 'bot_screen.lost_control'), 0);
        expect(logged.last, 'bot_screen.handback {reason: sign_out}');
        expect(channels, hasLength(1));
      });
    });

    test('the gateway closing at the same moment still logs the reason, since '
        'the release was sent and the close frees the lease', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        final first = channel;

        unawaited(viewer.shutDown('sign_out'));
        unawaited(transport.close());
        settle();

        expect(first.sentCloseCode, 1000);
        expect(server.holder, 'agent');
        expect(logged.last, 'bot_screen.handback {reason: sign_out}');
      });
    });

    test('a take over that was still being repeated when the viewer shut '
        'down is released and opens no stream', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        gateway.drop();
        settle();
        viewer.foreground = false;
        settle();
        gateway.silent.add('display.lease.acquire');
        viewer.foreground = true;
        settle();
        // The lease names the old id and the new one is being taken.
        final acquire = gateway.requests.lastWhere(
          (r) => r['method'] == 'display.lease.acquire',
        );
        expect((acquire['params'] as Map)['viewer_id'], server.mintedIds.last);
        final streams = channels.length;

        unawaited(viewer.shutDown('close'));
        settle();
        server.takeBy(server.mintedIds.last);
        gateway.replyTo(acquire, {'lease': server.lease});
        settle();
        async.elapse(const Duration(seconds: 5));

        expect(channels, hasLength(streams));
        expect(server.holder, 'agent');
      });
    });

    test('while watching it only closes', () {
      scenario(() {
        final first = channel;

        unawaited(viewer.shutDown('close'));
        settle();

        expect(server.released, isEmpty);
        expect(first.sentCloseCode, 1000);
        expect(logged, isEmpty);
      });
    });

    test('stops reconnecting', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();

        unawaited(viewer.shutDown('close'));
        settle();
        async.elapse(const Duration(minutes: 1));

        expect(channels, hasLength(1));
        expect(server.observedWith, hasLength(1));
      });
    });
  });

  group('what telemetry sees', () {
    test('the stream span says whether the user took over', () {
      scenario(() {
        viewer.foreground = false;
        settle();
        viewer.foreground = true;
        settle();
        handshake();
        unawaited(viewer.takeOver());
        settle();
        viewer.foreground = false;
        settle();

        final spans = tracer.spans
            .where((span) => span.name == 'bot_screen.stream')
            .toList();
        expect(spans.map((span) => span.attributes['took_over']), [
          false,
          true,
        ]);
        expect(spans.map((span) => span.attributes['close_code']), [
          1000,
          4100,
        ]);
      });
    });

    test('no log, span or error holds a viewer id', () {
      scenario(() {
        unawaited(viewer.takeOver());
        settle();
        server.takeBy('someone-else');
        settle();
        viewer.foreground = false;
        settle();

        final everything = [
          ...logged,
          for (final span in tracer.spans) '${span.attributes}',
        ].join(' ');
        for (final id in [...server.mintedIds, 'someone-else']) {
          expect(everything, isNot(contains(id)));
          expect(everything, isNot(contains(BotScreenViewerIds.hashOf(id))));
        }
      });
    });
  });
}
