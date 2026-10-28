import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';

import '../support/fake_gateway.dart';
import 'bot_screen_repository_test.dart' show jpeg, statusJson;

const _key = '/home/u/.hermes/profiles/work';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenController controller;
  late FakeAsync async;
  var running = true;
  var holder = 'agent';
  var startFails = false;
  final logged = <String>[];

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  void settle() => async.flushMicrotasks();

  Map<String, Object?> lastRequest(String method) =>
      gateway.requests.lastWhere((r) => r['method'] == method);

  void broadcastStatus({bool isRunning = true, String key = _key}) {
    gateway.event('display.status', '', {
      ...statusJson(running: isRunning),
      'profile_key': key,
    });
    settle();
  }

  void broadcastLease(String who, {String key = _key}) {
    gateway.event('display.lease', '', {
      'profile_key': key,
      'lease': {'holder': who, 'since': 1.0, 'epoch': 4},
    });
    settle();
  }

  /// Runs [body] under fake time with a controller for the profile `work`.
  void scenario(
    void Function() body, {
    Stream<GatewayConnectionEvent> Function()? events,
  }) {
    fakeAsync((zone) {
      async = zone;
      running = true;
      holder = 'agent';
      startFails = false;
      logged.clear();
      gateway = FakeGateway();
      gateway.handlers['display.status'] = (_) =>
          statusJson(running: running, lease: {'holder': holder, 'epoch': 1});
      gateway.handlers['display.start'] = (_) {
        if (startFails) throw const FakeRpcError(5300, 'cannot start');
        running = true;
        return statusJson(running: true);
      };
      gateway.handlers['display.thumbnail'] = (_) => {
        'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
      };
      transport = HermesGatewayTransport(connect: gateway.connect);
      controller = BotScreenController(
        BotScreenRepository(transport.requestKeepingConnection),
        events?.call() ?? transport.connectionEvents,
        profile: 'work',
        events: (name, [attributes = const {}]) =>
            logged.add('$name $attributes'),
      );
      try {
        body();
      } finally {
        controller.dispose();
        transport.close();
        settle();
      }
    });
  }

  group('polling', () {
    test('sends nothing while no surface asks', () {
      scenario(() {
        async.elapse(const Duration(seconds: 30));

        expect(gateway.requests, isEmpty);
        expect(controller.status, isNull);
      });
    });

    test('reads the status, then a frame at once and every 3 seconds', () {
      scenario(() {
        controller.watch();
        settle();

        expect(calls('display.status'), 1);
        expect(calls('display.thumbnail'), 1);
        expect(controller.status?.running, isTrue);
        expect(controller.frame, jpeg);

        async.elapse(const Duration(seconds: 3));
        expect(calls('display.thumbnail'), 2);
        async.elapse(const Duration(seconds: 6));
        expect(calls('display.thumbnail'), 4);
      });
    });

    test('stops when the last surface lets go', () {
      scenario(() {
        final first = controller.watch();
        final second = controller.watch();
        settle();

        first.release();
        async.elapse(const Duration(seconds: 3));
        expect(calls('display.thumbnail'), 2);

        second.release();
        second.release();
        async.elapse(const Duration(seconds: 30));
        expect(calls('display.thumbnail'), 2);
      });
    });

    test('does not ask for frames of a screen that is not running', () {
      scenario(() {
        running = false;
        controller.watch();
        async.elapse(const Duration(seconds: 12));

        expect(calls('display.status'), 1);
        expect(calls('display.thumbnail'), 0);
        expect(controller.frame, isNull);
      });
    });

    test('pauses in the background and under App Lock', () {
      scenario(() {
        controller.watch();
        settle();
        expect(calls('display.thumbnail'), 1);

        controller.foreground = false;
        async.elapse(const Duration(seconds: 9));
        expect(calls('display.thumbnail'), 1);

        controller.foreground = true;
        settle();
        expect(calls('display.thumbnail'), 2);

        controller.unlocked = false;
        async.elapse(const Duration(seconds: 9));
        expect(calls('display.thumbnail'), 2);
        expect(controller.frame, isNull);

        controller.unlocked = true;
        async.elapse(const Duration(seconds: 3));
        expect(calls('display.thumbnail'), greaterThan(2));
        expect(controller.frame, jpeg);
      });
    });

    test('never has two requests in flight', () {
      scenario(() {
        gateway.silent.add('display.thumbnail');
        controller.watch();
        async.elapse(const Duration(seconds: 9));

        expect(calls('display.thumbnail'), 1);
      });
    });

    test('a server without the feature gets no polling', () {
      scenario(() {
        gateway.handlers['display.status'] = (_) =>
            throw const FakeRpcError(-32601, 'unknown method');
        controller.watch();
        async.elapse(const Duration(seconds: 12));

        expect(controller.unsupported, isTrue);
        expect(calls('display.thumbnail'), 0);
      });
    });
  });

  group('following broadcasts', () {
    test('a human taking the lease clears the frame at once', () {
      scenario(() {
        controller.watch();
        settle();
        expect(controller.frame, isNotNull);

        broadcastLease('human');

        expect(controller.frame, isNull);
        expect(controller.suppressed, isTrue);
        expect(controller.status?.lease.holder, BotScreenHolder.human);
      });
    });

    test('a lease for another profile changes nothing', () {
      scenario(() {
        controller.watch();
        settle();

        broadcastLease('human', key: '/home/u/.hermes/profiles/other');

        expect(controller.frame, jpeg);
        expect(controller.status?.lease.holder, BotScreenHolder.agent);
      });
    });

    test('a status for another profile changes nothing', () {
      scenario(() {
        controller.watch();
        settle();

        broadcastStatus(isRunning: false, key: '/elsewhere');

        expect(controller.frame, jpeg);
        expect(controller.status?.running, isTrue);
      });
    });

    test('the screen stopping clears the frame and ends polling', () {
      scenario(() {
        controller.watch();
        settle();

        broadcastStatus(isRunning: false);
        async.elapse(const Duration(seconds: 9));

        expect(controller.frame, isNull);
        expect(controller.status?.running, isFalse);
        expect(calls('display.thumbnail'), 1);
      });
    });

    test('the screen starting begins polling', () {
      scenario(() {
        running = false;
        controller.watch();
        settle();
        expect(calls('display.thumbnail'), 0);

        broadcastStatus();
        settle();

        expect(calls('display.thumbnail'), 1);
      });
    });

    test('a suppressed frame drops the frame and says someone else has it', () {
      scenario(() {
        controller.watch();
        settle();
        holder = 'human';
        gateway.handlers['display.thumbnail'] = (_) => {
          'data_url': null,
          'suppressed': 'human_has_control',
        };

        async.elapse(const Duration(seconds: 3));

        expect(controller.frame, isNull);
        expect(controller.suppressed, isTrue);
        expect(controller.status?.lease.holder, BotScreenHolder.human);
      });
    });
  });

  group('re-reading the status', () {
    test('when a surface starts showing the screen', () {
      scenario(() {
        final handle = controller.watch();
        settle();
        handle.release();
        controller.watch();
        settle();

        expect(calls('display.status'), 2);
      });
    });

    test('after the connection is lost while the screen is shown', () {
      scenario(() {
        controller.watch();
        settle();
        expect(calls('display.status'), 1);

        gateway.drop();
        settle();

        expect(calls('display.status'), 2);
      });
    });

    test('not when the connection is lost with nothing shown', () {
      scenario(() {
        final handle = controller.watch();
        settle();
        handle.release();

        gateway.drop();
        settle();

        expect(calls('display.status'), 1);
      });
    });

    test('when the app returns to the foreground', () {
      scenario(() {
        controller.watch();
        settle();
        controller.foreground = false;

        controller.foreground = true;
        settle();

        expect(calls('display.status'), 2);
      });
    });

    test('with every 10th frame request, which notices a takeover made '
        'through another process', () {
      scenario(() {
        controller.watch();
        settle();
        for (var i = 0; i < 8; i++) {
          async.elapse(const Duration(seconds: 3));
        }
        expect(calls('display.thumbnail'), 9);
        expect(calls('display.status'), 1);

        holder = 'human';
        async.elapse(const Duration(seconds: 3));

        expect(calls('display.thumbnail'), 10);
        expect(calls('display.status'), 2);
        expect(controller.status?.lease.holder, BotScreenHolder.human);
      });
    });
  });

  group('answers that arrive too late', () {
    BotScreenWatch holdFrameRequest() {
      gateway.silent.add('display.thumbnail');
      final handle = controller.watch();
      settle();
      return handle;
    }

    void answerFrame() {
      gateway.replyTo(gateway.requestOf('display.thumbnail'), {
        'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
      });
      settle();
    }

    test('a frame answered after the app left the foreground is dropped', () {
      scenario(() {
        holdFrameRequest();
        controller.foreground = false;

        answerFrame();

        expect(controller.frame, isNull);
      });
    });

    test('a frame answered after the last surface let go is dropped', () {
      scenario(() {
        final handle = holdFrameRequest();
        handle.release();
        settle();

        answerFrame();

        expect(controller.frame, isNull);
      });
    });

    test('a frame answered after another surface took over the demand is '
        'still shown', () {
      scenario(() {
        holdFrameRequest();
        controller.watch();

        answerFrame();

        expect(controller.frame, jpeg);
      });
    });

    test('a frame answered after App Lock covered the app is dropped', () {
      scenario(() {
        holdFrameRequest();
        controller.unlocked = false;

        gateway.replyTo(gateway.requestOf('display.thumbnail'), {
          'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
        });
        settle();
        controller.unlocked = true;

        expect(controller.frame, isNull);
      });
    });

    test('a frame answered after dispose is dropped without a rebuild', () {
      scenario(() {
        holdFrameRequest();
        var notified = 0;
        controller.addListener(() => notified++);
        controller.dispose();

        gateway.replyTo(gateway.requestOf('display.thumbnail'), {
          'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
        });
        settle();

        expect(notified, 0);
        expect(controller.frame, isNull);
      });
    });
  });

  group('start', () {
    test('goes from off to starting to running', () {
      scenario(() {
        running = false;
        gateway.silent.add('display.start');
        controller.watch();
        settle();
        expect(controller.status?.running, isFalse);

        final states = <bool>[];
        controller.addListener(() => states.add(controller.starting));
        final done = controller.start();
        settle();
        expect(controller.starting, isTrue);

        gateway.silent.remove('display.start');
        gateway.replyTo(
          gateway.requestOf('display.start'),
          statusJson(running: true),
        );
        settle();

        expect(controller.starting, isFalse);
        expect(controller.status?.running, isTrue);
        expect(controller.startError, isNull);
        expect(states, containsAllInOrder([true, false]));
        expect(done, completes);
      });
    });

    test('App Lock during a start still ends starting and re-reads the '
        'status', () {
      scenario(() {
        running = false;
        gateway.silent.add('display.start');
        controller.watch();
        settle();
        controller.start();
        settle();
        expect(controller.starting, isTrue);

        controller.unlocked = false;
        gateway.replyTo(
          gateway.requestOf('display.start'),
          statusJson(running: true),
        );
        settle();
        running = true;
        controller.unlocked = true;
        settle();

        expect(controller.starting, isFalse);
        expect(calls('display.status'), 2);
        expect(controller.status?.running, isTrue);
      });
    });

    test('goes back to off with the failure', () {
      scenario(() {
        running = false;
        startFails = true;
        controller.watch();
        settle();

        controller.start();
        settle();

        expect(controller.starting, isFalse);
        expect(controller.status?.running, isFalse);
        expect(controller.startError, BotScreenFailure.display);
      });
    });
  });

  group('start outcome', () {
    test('is logged as started, with nothing else', () {
      scenario(() {
        running = false;
        controller.watch();
        settle();

        controller.start();
        settle();

        expect(logged, ['bot_screen.start {outcome: started}']);
      });
    });

    test('is logged as blocked when Hermes names a blocker', () {
      scenario(() {
        running = false;
        gateway.handlers['display.start'] = (_) =>
            statusJson(running: false, extra: {'blocker': 'Not enough memory'});
        controller.watch();
        settle();

        controller.start();
        settle();

        expect(logged, ['bot_screen.start {outcome: blocked}']);
      });
    });

    test('is logged as error when the start fails', () {
      scenario(() {
        running = false;
        startFails = true;
        controller.watch();
        settle();

        controller.start();
        settle();

        expect(logged, ['bot_screen.start {outcome: error}']);
      });
    });

    test('is not logged when nothing was sent', () {
      scenario(() {
        running = false;
        controller.watch();
        settle();
        controller.foreground = false;

        controller.start();
        settle();

        expect(logged, isEmpty);
      });
    });
  });

  group('what a surface that is gone leaves behind', () {
    test('the last surface letting go drops the frame', () {
      scenario(() {
        final handle = controller.watch();
        settle();
        expect(controller.frame, jpeg);

        handle.release();
        settle();

        expect(controller.frame, isNull);
      });
    });

    test('another surface still asking keeps the frame', () {
      scenario(() {
        final first = controller.watch();
        controller.watch();
        settle();

        first.release();
        settle();

        expect(controller.frame, jpeg);
      });
    });

    test('the app leaving the foreground drops the frame', () {
      scenario(() {
        controller.watch();
        settle();

        controller.foreground = false;

        expect(controller.frame, isNull);
        async.elapse(const Duration(seconds: 9));
        expect(controller.frame, isNull);
      });
    });
  });

  group('retry', () {
    test('reads the status again at once after a failure', () {
      scenario(() {
        var failures = 1;
        gateway.handlers['display.status'] = (_) {
          if (failures-- > 0) throw const FakeRpcError(5300, 'busy');
          return statusJson();
        };
        controller.watch();
        settle();
        expect(controller.failure, BotScreenFailure.display);

        controller.retry();
        settle();

        expect(calls('display.status'), 2);
        expect(controller.failure, isNull);
        expect(controller.status?.running, isTrue);
      });
    });

    test('asks for a frame at once instead of waiting out the back-off', () {
      scenario(() {
        var failing = true;
        gateway.handlers['display.thumbnail'] = (_) {
          if (failing) throw const FakeRpcError(5300, 'no frame');
          return {'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}'};
        };
        controller.watch();
        async.elapse(const Duration(seconds: 7));
        expect(controller.failure, BotScreenFailure.display);
        expect(controller.frame, isNull);

        failing = false;
        controller.retry();
        settle();

        expect(controller.frame, jpeg);
        expect(controller.failure, isNull);
      });
    });
  });

  group('a connection feed that fails', () {
    test('an error in the feed is not uncaught and re-reads the status', () {
      final feed = StreamController<GatewayConnectionEvent>.broadcast();
      scenario(() {
        controller.watch();
        settle();
        expect(calls('display.status'), 1);

        feed.addError(SessionTransportUnavailable(retired: false));
        settle();

        expect(calls('display.status'), 2);
      }, events: () => feed.stream);
      feed.close();
    });

    test('an error with nothing shown does nothing', () {
      final feed = StreamController<GatewayConnectionEvent>.broadcast();
      scenario(() {
        feed.addError(SessionTransportUnavailable(retired: true));
        settle();

        expect(gateway.requests, isEmpty);
      }, events: () => feed.stream);
      feed.close();
    });
  });

  group('answers older than a broadcast', () {
    test('a frame requested before a human took the lease is not shown', () {
      scenario(() {
        controller.watch();
        settle();
        gateway.silent.add('display.thumbnail');
        async.elapse(const Duration(seconds: 3));
        expect(calls('display.thumbnail'), 2);

        broadcastLease('human');
        gateway.replyTo(lastRequest('display.thumbnail'), {
          'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
        });
        settle();

        expect(controller.frame, isNull);
        expect(controller.suppressed, isTrue);
      });
    });

    test('a status read before a broadcast does not overwrite it', () {
      scenario(() {
        controller.watch();
        settle();
        gateway.silent.add('display.status');
        controller.foreground = false;
        controller.foreground = true;
        settle();
        expect(calls('display.status'), 2);

        broadcastLease('human');
        gateway.replyTo(
          lastRequest('display.status'),
          statusJson(lease: {'holder': 'agent', 'epoch': 1}),
        );
        settle();

        expect(controller.status?.lease.holder, BotScreenHolder.human);
      });
    });

    test('a frame is ignored while the status says a human holds control', () {
      scenario(() {
        holder = 'human';
        controller.watch();
        settle();

        expect(calls('display.thumbnail'), 1);
        expect(controller.frame, isNull);
      });
    });
  });

  group('failures', () {
    test('a failed first status read is retried with a growing wait', () {
      scenario(() {
        var failures = 3;
        gateway.handlers['display.status'] = (_) {
          if (failures-- > 0) throw const FakeRpcError(5300, 'busy');
          return statusJson();
        };
        controller.watch();
        settle();
        expect(calls('display.status'), 1);
        expect(controller.status, isNull);
        expect(controller.failure, BotScreenFailure.display);

        async.elapse(const Duration(seconds: 1));
        expect(calls('display.status'), 2);
        async.elapse(const Duration(seconds: 1));
        expect(calls('display.status'), 2);
        async.elapse(const Duration(seconds: 1));
        expect(calls('display.status'), 3);
        async.elapse(const Duration(seconds: 4));
        expect(calls('display.status'), 4);

        expect(controller.status?.running, isTrue);
        expect(controller.failure, isNull);
        expect(calls('display.thumbnail'), greaterThan(0));
      });
    });

    test('the retry stops when nothing asks any more', () {
      scenario(() {
        gateway.handlers['display.status'] = (_) =>
            throw const FakeRpcError(5300, 'busy');
        final handle = controller.watch();
        settle();
        handle.release();

        async.elapse(const Duration(minutes: 5));

        expect(calls('display.status'), 1);
      });
    });

    test('frame reads back off after failures and recover on success', () {
      scenario(() {
        var failing = true;
        gateway.handlers['display.thumbnail'] = (_) {
          if (failing) throw const FakeRpcError(5300, 'no frame');
          return {'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}'};
        };
        controller.watch();
        async.elapse(const Duration(seconds: 30));

        // Requests at 0, 6 and 18 s instead of every 3 s.
        expect(calls('display.thumbnail'), 3);
        expect(controller.failure, BotScreenFailure.display);

        failing = false;
        async.elapse(const Duration(seconds: 12));
        expect(controller.frame, jpeg);
        final before = calls('display.thumbnail');
        async.elapse(const Duration(seconds: 6));
        expect(calls('display.thumbnail'), before + 2);
      });
    });
  });

  group('start while the app cannot talk', () {
    test('sends nothing under App Lock or in the background', () {
      scenario(() {
        running = false;
        controller.watch();
        settle();

        controller.unlocked = false;
        controller.start();
        controller.unlocked = true;
        controller.foreground = false;
        controller.start();
        settle();

        expect(calls('display.start'), 0);
        expect(controller.starting, isFalse);
      });
    });

    test('a server without the feature stops polling after a start', () {
      scenario(() {
        gateway.handlers['display.start'] = (_) =>
            throw const FakeRpcError(-32601, 'unknown method');
        controller.watch();
        settle();
        running = true;
        expect(calls('display.thumbnail'), 1);

        controller.start();
        settle();
        async.elapse(const Duration(seconds: 12));

        expect(controller.unsupported, isTrue);
        expect(calls('display.thumbnail'), 1);
      });
    });
  });
}
