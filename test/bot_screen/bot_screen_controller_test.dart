import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

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

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  void settle() => async.flushMicrotasks();

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
  void scenario(void Function() body) {
    fakeAsync((zone) {
      async = zone;
      running = true;
      holder = 'agent';
      startFails = false;
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
        transport.connectionEvents,
        profile: 'work',
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
    void holdFrameRequest() {
      gateway.silent.add('display.thumbnail');
      controller.watch();
      settle();
    }

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
}
