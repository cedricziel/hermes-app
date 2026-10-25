import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
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

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: gateway.connect);
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
    });

    test('a connection that closes mid-call is a closed failure', () async {
      gateway.silent.add('display.thumbnail');
      final result = repository.thumbnail('work');
      await pumpEventQueue();

      gateway.drop();

      expect(((await result) as BotScreenFailed).kind, BotScreenFailure.closed);
    });
  });
}
