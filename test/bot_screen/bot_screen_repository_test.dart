import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// A status as Hermes answers it for a running screen.
Map<String, Object?> statusJson({
  bool running = true,
  Map<String, Object?>? lease,
  Map<String, Object?> extra = const {},
}) => {
  'profile': 'work',
  'supported': true,
  'installed': true,
  'missing': <String>[],
  'running': running,
  'geometry': '1280x800',
  'placement': 'gateway',
  'lease': lease ?? {'holder': 'agent', 'since': 1.0, 'epoch': 3, 'reason': ''},
  'profile_key': '/home/u/.hermes/profiles/work',
  ...extra,
};

final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

String dataUrl(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenRepository repository;
  late int connects;

  setUp(() {
    gateway = FakeGateway();
    connects = 0;
    transport = HermesGatewayTransport(
      connect: () {
        connects++;
        return gateway.connect();
      },
    );
    repository = BotScreenRepository(
      transport.requestKeepingConnection,
      timeout: const Duration(milliseconds: 50),
    );
    gateway.handlers['display.status'] = (_) => statusJson();
    gateway.handlers['display.start'] = (_) => statusJson();
    gateway.handlers['display.thumbnail'] = (_) => {'data_url': dataUrl(jpeg)};
  });

  tearDown(() => transport.close());

  Future<T> ok<T>(Future<BotScreenResult<T>> call) async =>
      switch (await call) {
        BotScreenOk(:final value) => value,
        final other => fail('expected ok, got $other'),
      };

  group('profile', () {
    test('every call names the profile', () async {
      await repository.status('work');
      await repository.start('work');
      await repository.thumbnail('work');

      for (final method in [
        'display.status',
        'display.start',
        'display.thumbnail',
      ]) {
        expect(gateway.requestOf(method)['params'], {'profile': 'work'});
      }
    });

    test('the default profile is named default, never left out', () async {
      await repository.status(null);
      await repository.thumbnail(null);

      expect(gateway.requestOf('display.status')['params'], {
        'profile': 'default',
      });
      expect(gateway.requestOf('display.thumbnail')['params'], {
        'profile': 'default',
      });
    });
  });

  group('display.status', () {
    test('reads every field the app relies on', () async {
      gateway.handlers['display.status'] = (_) => statusJson(
        running: false,
        lease: {
          'holder': 'human',
          'viewer_hash': 'abcdef012345',
          'since': 9.5,
          'epoch': 7,
          'reason': 'takeover',
        },
        extra: {
          'installed': false,
          'missing': ['Xvnc', 'xfce4-session'],
          'install_command': 'sudo apt-get install -y tigervnc',
          'blocker': 'Not enough memory',
          'memory_available_mb': 512,
          'placement': 'sandbox',
        },
      );

      final status = await ok(repository.status('work'));

      expect(status.supported, isTrue);
      expect(status.installed, isFalse);
      expect(status.missing, ['Xvnc', 'xfce4-session']);
      expect(status.running, isFalse);
      expect(status.geometry, '1280x800');
      expect(status.placement, 'sandbox');
      expect(status.installCommand, 'sudo apt-get install -y tigervnc');
      expect(status.blocker, 'Not enough memory');
      expect(status.memoryAvailableMb, 512);
      expect(status.profileKey, '/home/u/.hermes/profiles/work');
      expect(status.lease.holder, BotScreenHolder.human);
      expect(status.lease.viewerHash, 'abcdef012345');
      expect(status.lease.reason, 'takeover');
      expect(status.lease.epoch, 7);
    });

    test('a missing optional field is unknown, not an error', () async {
      gateway.handlers['display.status'] = (_) => {
        'supported': true,
        'running': true,
        'profile_key': 'k',
        'lease': {'holder': 'agent'},
      };

      final status = await ok(repository.status('work'));

      expect(status.running, isTrue);
      expect(status.installed, isFalse);
      expect(status.missing, isEmpty);
      expect(status.geometry, isNull);
      expect(status.placement, 'gateway');
      expect(status.installCommand, isNull);
      expect(status.blocker, isNull);
      expect(status.memoryAvailableMb, isNull);
      expect(status.lease.holder, BotScreenHolder.agent);
      expect(status.lease.viewerHash, isNull);
    });

    test(
      'a missing or unreadable lease counts as a person in control',
      () async {
        for (final lease in [null, 'garbage', <String, Object?>{}]) {
          gateway.handlers['display.status'] = (_) => {
            'supported': true,
            'running': true,
            'lease': ?lease,
          };

          final status = await ok(repository.status('work'));

          expect(status.lease.holder, BotScreenHolder.human, reason: '$lease');
        }
      },
    );

    test('method-not-found means the server has no screen feature', () async {
      gateway.handlers['display.status'] = (_) =>
          throw const FakeRpcError(kGatewayMethodNotFound, 'unknown method');

      expect(await repository.status('work'), isA<BotScreenUnsupported>());
    });
  });

  group('display.thumbnail', () {
    test('decodes the JPEG data URL', () async {
      final frame = await ok(repository.thumbnail('work'));

      expect(frame, isA<BotScreenJpeg>());
      expect((frame as BotScreenJpeg).bytes, jpeg);
    });

    test('a null picture with a reason is suppressed', () async {
      gateway.handlers['display.thumbnail'] = (_) => {
        'data_url': null,
        'suppressed': 'human_has_control',
      };

      final frame = await ok(repository.thumbnail('work'));

      expect(frame, isA<BotScreenSuppressed>());
      expect((frame as BotScreenSuppressed).reason, 'human_has_control');
    });

    test('a null picture without a reason means the screen stopped', () async {
      gateway.handlers['display.thumbnail'] = (_) => {'data_url': null};

      expect(await ok(repository.thumbnail('work')), isA<BotScreenStopped>());
    });

    test('a picture that is not a base64 data URL is a failure', () async {
      gateway.handlers['display.thumbnail'] = (_) => {'data_url': 'nonsense'};

      final result = await repository.thumbnail('work');

      expect(result, isA<BotScreenFailed>());
      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });
  });

  group('display.start', () {
    test('returns the new status', () async {
      gateway.handlers['display.start'] = (_) => statusJson(running: true);

      expect((await ok(repository.start('work'))).running, isTrue);
    });

    test('returns the failure when Hermes refuses', () async {
      gateway.handlers['display.start'] = (_) =>
          throw const FakeRpcError(5300, 'Xvnc not installed');

      final result = await repository.start('work');

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });
  });

  group('display.install', () {
    test('names the profile and reads what started', () async {
      gateway.handlers['display.install'] = (_) => {
        'started': true,
        'command': 'sudo apt-get install -y x',
        'profile_key': '/home/u/.hermes/profiles/work',
      };

      final started = await ok(repository.install('work'));

      expect(gateway.requestOf('display.install')['params'], {
        'profile': 'work',
      });
      expect(started.command, 'sudo apt-get install -y x');
      expect(started.profileKey, '/home/u/.hermes/profiles/work');
    });

    test('says which connection carried the call when it can', () async {
      gateway.handlers['display.install'] = (_) => {
        'started': true,
        'profile_key': 'k',
      };
      final withClient = BotScreenRepository(
        transport.requestKeepingConnection,
        connectionRpc: transport.requestKeepingConnectionOnClient,
      );

      final started = await ok(withClient.install('work'));
      final without = await ok(repository.install('work'));

      expect(
        identical(started.connection, transport.gatewayConnection),
        isTrue,
      );
      expect(without.connection, isNull);
    });

    test(
      'a refusal keeps the server message and logs no read failure',
      () async {
        final logged = <String>[];
        final logging = BotScreenRepository(
          transport.requestKeepingConnection,
          telemetry: ConnectionTelemetry(
            events: (name, [attributes = const {}]) => logged.add(name),
          ),
        );
        gateway.handlers['display.install'] = (_) =>
            throw const FakeRpcError(5300, 'an install is already running');

        final result = await logging.install('work');

        final failed = result as BotScreenFailed;
        expect(failed.kind, BotScreenFailure.display);
        expect(failed.message, 'an install is already running');
        expect(logged, isEmpty);
      },
    );

    test('an answer without a profile key is unreadable', () async {
      gateway.handlers['display.install'] = (_) => {'started': true};

      final result = await repository.install('work');

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });
  });

  group('failures', () {
    test('error 5300 is a display error', () async {
      gateway.handlers['display.thumbnail'] = (_) =>
          throw const FakeRpcError(5300, 'no frame');

      final result = await repository.thumbnail('work');

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });

    test('no answer in time is a timeout and keeps the connection', () async {
      gateway.silent.add('display.thumbnail');

      final result = await repository.thumbnail('work');
      await ok(repository.status('work'));

      expect((result as BotScreenFailed).kind, BotScreenFailure.timeout);
      expect(gateway.methods.where((m) => m == 'display.status'), hasLength(1));
      expect(connects, 1);
    });

    test('a connection that closes mid-call is a closed failure', () async {
      gateway.silent.add('display.thumbnail');
      final result = repository.thumbnail('work');
      await pumpEventQueue();

      gateway.drop();

      expect(((await result) as BotScreenFailed).kind, BotScreenFailure.closed);
    });
  });
  group('display.observe', () {
    setUp(() {
      gateway.handlers['display.observe'] = (_) => {
        'ticket': 'ticket-secret',
        'path': '/api/display/ws',
        'viewer_id': 'viewer-1',
        ...statusJson(),
      };
    });

    test(
      'names the profile and reads the ticket, path, id and status',
      () async {
        final observation = await ok(repository.observe('work'));

        expect(gateway.requestOf('display.observe')['params'], {
          'profile': 'work',
        });
        expect(observation.ticket, 'ticket-secret');
        expect(observation.path, '/api/display/ws');
        expect(observation.viewerId, 'viewer-1');
        expect(observation.status.running, isTrue);
        expect(observation.status.lease.holder, BotScreenHolder.agent);
      },
    );

    test('says which connection answered when it can', () async {
      final withClient = BotScreenRepository(
        transport.requestKeepingConnection,
        connectionRpc: transport.requestKeepingConnectionOnClient,
      );

      final observation = await ok(withClient.observe('work'));
      final without = await ok(repository.observe('work'));

      expect(
        identical(observation.connection, transport.gatewayConnection),
        isTrue,
      );
      expect(without.connection, isNull);
    });

    test('names the default profile and passes a viewer id along', () async {
      await repository.observe(null, viewerId: 'viewer-1');

      expect(gateway.requestOf('display.observe')['params'], {
        'profile': 'default',
        'viewer_id': 'viewer-1',
      });
    });

    test('a printed observation holds neither ticket nor id', () async {
      final observation = await ok(repository.observe('work'));

      expect('$observation', isNot(contains('ticket-secret')));
      expect('$observation', isNot(contains('viewer-1')));
    });

    test('an error answer is a display failure', () async {
      gateway.handlers['display.observe'] = (_) =>
          throw const FakeRpcError(5300, 'not running');

      final result = await repository.observe('work');

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });

    test('method-not-found is unsupported', () async {
      gateway.handlers['display.observe'] = (_) =>
          throw const FakeRpcError(-32601, 'unknown method');

      expect(await repository.observe('work'), isA<BotScreenUnsupported>());
    });

    test('an answer without a ticket or path cannot be used', () async {
      for (final broken in [
        {'path': '/api/display/ws', 'viewer_id': 'v'},
        {'ticket': 't', 'viewer_id': 'v'},
        {'ticket': 't', 'path': '/api/display/ws'},
        {'ticket': '', 'path': '/api/display/ws', 'viewer_id': 'v'},
      ]) {
        gateway.handlers['display.observe'] = (_) => broken;

        final result = await repository.observe('work');

        expect((result as BotScreenFailed).kind, BotScreenFailure.display);
      }
    });
  });

  group('the control lease', () {
    late BotScreenRepository pinned;

    Map<String, Object?> leaseOf(
      String holder, {
      String? hash,
      int epoch = 5,
    }) => {
      'lease': {
        'holder': holder,
        'viewer_id': null,
        'viewer_hash': hash,
        'since': 2.0,
        'reason': '',
        'epoch': epoch,
      },
    };

    setUp(() {
      pinned = BotScreenRepository(
        transport.requestKeepingConnection,
        connectionRpc: transport.requestKeepingConnectionOnClient,
        pinnedRpc: transport.requestOn,
        timeout: const Duration(milliseconds: 50),
      );
      gateway.handlers['display.observe'] = (_) => {
        'ticket': 't',
        'path': '/api/display/ws',
        'viewer_id': 'viewer-1',
        ...statusJson(),
      };
    });

    Future<Object> observedConnection() async =>
        (await ok(pinned.observe('work'))).connection!;

    test(
      'acquire names the profile and the viewer id and reads the lease',
      () async {
        gateway.handlers['display.lease.acquire'] = (_) =>
            leaseOf('human', hash: 'abcdef012345');
        final connection = await observedConnection();

        final lease = await ok(
          pinned.acquire('work', viewerId: 'viewer-1', connection: connection),
        );

        expect(gateway.requestOf('display.lease.acquire')['params'], {
          'profile': 'work',
          'viewer_id': 'viewer-1',
        });
        expect(lease.holder, BotScreenHolder.human);
        expect(lease.viewerHash, 'abcdef012345');
        expect(lease.epoch, 5);
      },
    );

    test('release names the profile and the viewer id', () async {
      gateway.handlers['display.lease.release'] = (_) => leaseOf('agent');
      final connection = await observedConnection();

      final lease = await ok(
        pinned.release('work', viewerId: 'viewer-1', connection: connection),
      );

      expect(gateway.requestOf('display.lease.release')['params'], {
        'profile': 'work',
        'viewer_id': 'viewer-1',
      });
      expect(lease.holder, BotScreenHolder.agent);
    });

    test('a connection that is gone fails closed and opens no other', () async {
      final connection = await observedConnection();
      gateway.drop();
      await pumpEventQueue();

      final result = await pinned.acquire(
        'work',
        viewerId: 'viewer-1',
        connection: connection,
      );

      expect((result as BotScreenFailed).kind, BotScreenFailure.closed);
      expect(gateway.methods, isNot(contains('display.lease.acquire')));
      expect(connects, 1);
    });

    test('viewer_mismatch is its own failure', () async {
      gateway.handlers['display.lease.acquire'] = (_) =>
          throw const FakeRpcError(5300, 'not minted for this connection', {
            'code': 'viewer_mismatch',
          });
      final connection = await observedConnection();

      final result = await pinned.acquire(
        'work',
        viewerId: 'viewer-1',
        connection: connection,
      );

      expect((result as BotScreenFailed).kind, BotScreenFailure.mismatch);
    });

    test('other refusals are display failures', () async {
      gateway.handlers['display.lease.release'] = (_) =>
          throw const FakeRpcError(5300, 'broken');
      final connection = await observedConnection();

      final result = await pinned.release(
        'work',
        viewerId: 'viewer-1',
        connection: connection,
      );

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });

    test('an answer without a lease cannot be used', () async {
      gateway.handlers['display.lease.acquire'] = (_) => <String, Object?>{};
      final connection = await observedConnection();

      final result = await pinned.acquire(
        'work',
        viewerId: 'viewer-1',
        connection: connection,
      );

      expect((result as BotScreenFailed).kind, BotScreenFailure.display);
    });

    test('without a pinned request nothing is sent', () async {
      final connection = await observedConnection();

      final result = await repository.acquire(
        'work',
        viewerId: 'viewer-1',
        connection: connection,
      );

      expect((result as BotScreenFailed).kind, BotScreenFailure.closed);
      expect(gateway.methods, isNot(contains('display.lease.acquire')));
    });

    test('a forced release sends force and no viewer id', () async {
      gateway.handlers['display.lease.release'] = (_) => leaseOf('agent');

      final lease = await ok(pinned.forceRelease('work'));

      expect(gateway.requestOf('display.lease.release')['params'], {
        'profile': 'work',
        'force': true,
      });
      expect(lease.holder, BotScreenHolder.agent);
    });

    test('failures of lease calls are not logged as read failures', () async {
      final logged = <String>[];
      final logging = BotScreenRepository(
        transport.requestKeepingConnection,
        pinnedRpc: transport.requestOn,
        telemetry: ConnectionTelemetry(
          events: (name, [attributes = const {}]) => logged.add(name),
        ),
      );
      gateway.handlers['display.lease.release'] = (_) =>
          throw const FakeRpcError(5300, 'broken');

      await logging.forceRelease('work');

      expect(logged, isEmpty);
    });
  });
}
