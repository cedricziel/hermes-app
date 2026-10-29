import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_viewer_ids.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';
import 'bot_screen_repository_test.dart' show statusJson;

/// `viewer-1`'s hash.
const _mine = '63a9e8a8c2d8';
const _theirs = '66db64465437';

Map<String, Object?> _leaseAnswer(
  String holder, {
  String? hash,
  int epoch = 6,
}) => {
  'lease': {
    'holder': holder,
    'viewer_id': null,
    'viewer_hash': hash,
    'epoch': epoch,
  },
};

void main() {
  late FakeAsync async;
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenController controller;
  late BotScreenViewerIds ids;
  late List<String> logged;
  late Map<String, Object?> status;

  void settle() => async.flushMicrotasks();

  /// Runs [body] with a controller that has read a status whose lease is
  /// [lease].
  void scenario(Map<String, Object?> lease, void Function() body) {
    fakeAsync((zone) {
      async = zone;
      logged = [];
      ids = BotScreenViewerIds()..add('viewer-1');
      gateway = FakeGateway();
      status = statusJson(lease: lease);
      gateway.handlers['display.status'] = (_) => status;
      transport = HermesGatewayTransport(connect: gateway.connect);
      controller = BotScreenController(
        BotScreenRepository(
          transport.requestKeepingConnection,
          connectionRpc: transport.requestKeepingConnectionOnClient,
          pinnedRpc: transport.requestOn,
        ),
        transport.connectionEvents,
        profile: 'work',
        viewerIds: ids,
        events: (name, [attributes = const {}]) =>
            logged.add('$name $attributes'),
      );
      try {
        controller.watch(frames: false);
        settle();
        body();
      } finally {
        controller.dispose();
        transport.close();
        settle();
      }
    });
  }

  group('who holds the lease', () {
    test('a person holding it under a viewer id of this app is you', () {
      scenario({'holder': 'human', 'viewer_hash': _mine, 'epoch': 5}, () {
        expect(controller.inControlHere, isTrue);
        expect(controller.someoneElseInControl, isFalse);
      });
    });

    test('a person holding it under another viewer id is someone else', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        expect(controller.inControlHere, isFalse);
        expect(controller.someoneElseInControl, isTrue);
      });
    });

    test('a lease with no hash held by a person is someone else', () {
      scenario({'holder': 'human', 'epoch': 5}, () {
        expect(controller.inControlHere, isFalse);
        expect(controller.someoneElseInControl, isTrue);
      });
    });

    test('Hermes holding it is neither', () {
      scenario({'holder': 'agent', 'epoch': 5}, () {
        expect(controller.inControlHere, isFalse);
        expect(controller.someoneElseInControl, isFalse);
      });
    });

    test('before the first status nobody is known to hold it', () {
      fakeAsync((zone) {
        final bare = BotScreenController(
          BotScreenRepository((method, params, {required timeout}) async => {}),
          const Stream.empty(),
        );

        expect(bare.inControlHere, isFalse);
        expect(bare.someoneElseInControl, isFalse);
        bare.dispose();
      });
    });
  });

  group('adopting a lease from an answer', () {
    test('takes the lease and drops the picture a person could be typing '
        'into', () {
      scenario({'holder': 'agent', 'epoch': 5}, () {
        controller.adoptLease(
          const BotScreenLease(
            holder: BotScreenHolder.human,
            viewerHash: _mine,
            epoch: 6,
          ),
        );

        expect(controller.inControlHere, isTrue);
        expect(controller.suppressed, isTrue);
        expect(controller.frame, isNull);
      });
    });

    test('an answer for the same epoch is taken: taking a lease you hold '
        'bumps nothing', () {
      scenario({'holder': 'human', 'viewer_hash': _mine, 'epoch': 5}, () {
        controller.adoptLease(
          const BotScreenLease(holder: BotScreenHolder.agent, epoch: 5),
        );

        expect(controller.status?.lease.holder, BotScreenHolder.agent);
      });
    });

    test('an older lease is ignored', () {
      scenario({'holder': 'human', 'viewer_hash': _mine, 'epoch': 5}, () {
        controller.adoptLease(
          const BotScreenLease(holder: BotScreenHolder.agent, epoch: 4),
        );

        expect(controller.inControlHere, isTrue);
      });
    });

    test('tells its listeners', () {
      scenario({'holder': 'agent', 'epoch': 5}, () {
        var told = 0;
        controller.addListener(() => told++);

        controller.adoptLease(
          const BotScreenLease(
            holder: BotScreenHolder.human,
            viewerHash: _mine,
            epoch: 6,
          ),
        );

        expect(told, 1);
      });
    });

    test('does nothing before a status was read', () {
      fakeAsync((zone) {
        final bare = BotScreenController(
          BotScreenRepository((method, params, {required timeout}) async => {}),
          const Stream.empty(),
        );

        bare.adoptLease(const BotScreenLease(holder: BotScreenHolder.human));

        expect(bare.status, isNull);
        bare.dispose();
      });
    });
  });

  group('handing back to Hermes by force', () {
    test('sends force and no viewer id, and takes the lease it answers', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.handlers['display.lease.release'] = (_) =>
            _leaseAnswer('agent');

        unawaited(controller.forceHandBack());
        settle();

        expect(gateway.requestOf('display.lease.release')['params'], {
          'profile': 'work',
          'force': true,
        });
        expect(controller.status?.lease.holder, BotScreenHolder.agent);
        expect(controller.someoneElseInControl, isFalse);
      });
    });

    test('answers true and logs the reason, nothing else', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.handlers['display.lease.release'] = (_) =>
            _leaseAnswer('agent');
        bool? result;

        controller.forceHandBack().then((value) => result = value);
        settle();

        expect(result, isTrue);
        expect(logged, ['bot_screen.handback {reason: force}']);
      });
    });

    test('a refusal leaves the lease, answers false and logs an error', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.handlers['display.lease.release'] = (_) =>
            throw const FakeRpcError(5300, 'broken');
        bool? result;

        controller.forceHandBack().then((value) => result = value);
        settle();

        expect(result, isFalse);
        expect(controller.someoneElseInControl, isTrue);
        expect(logged, ['bot_screen.handback {reason: error}']);
      });
    });

    test('an answer that still names a person is not a hand back', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.handlers['display.lease.release'] = (_) =>
            _leaseAnswer('human', hash: _theirs, epoch: 5);
        bool? result;

        controller.forceHandBack().then((value) => result = value);
        settle();

        expect(result, isFalse);
        expect(logged, ['bot_screen.handback {reason: error}']);
      });
    });

    test('a second press while one is on its way sends nothing more', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.silent.add('display.lease.release');

        unawaited(controller.forceHandBack());
        unawaited(controller.forceHandBack());
        settle();

        expect(
          gateway.methods.where((m) => m == 'display.lease.release'),
          hasLength(1),
        );
        expect(controller.handingBack, isTrue);
      });
    });

    test('a controller that is gone logs nothing and applies nothing', () {
      scenario({'holder': 'human', 'viewer_hash': _theirs, 'epoch': 5}, () {
        gateway.handlers['display.lease.release'] = (_) =>
            _leaseAnswer('agent');

        unawaited(controller.forceHandBack());
        controller.dispose();
        settle();

        expect(controller.status?.lease.holder, BotScreenHolder.human);
        expect(logged.where((e) => e.startsWith('bot_screen.handback')), [
          'bot_screen.handback {reason: force}',
        ]);
      });
    });
  });
}
