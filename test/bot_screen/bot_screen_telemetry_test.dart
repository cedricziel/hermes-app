import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recording_tracer.dart';

void main() {
  late RecordingTracer tracer;
  late List<String> events;
  late Future<Map<String, Object?>> Function() answer;
  late BotScreenRepository repository;

  setUp(() {
    tracer = RecordingTracer();
    events = [];
    answer = () async => {'data_url': null};
    repository = BotScreenRepository(
      (method, params, {required timeout}) => answer(),
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
        serverAttributes: const {'hermes.version': '0.22.0'},
      ),
    );
  });

  String jpegOf(int bytes) =>
      'data:image/jpeg;base64,${base64Encode(Uint8List(bytes))}';

  group('bot_screen.thumbnail span', () {
    test('a frame records its outcome and a size bucket only', () async {
      answer = () async => {'data_url': jpegOf(40 * 1024)};

      await repository.thumbnail('work');

      final span = tracer.spans.single;
      expect(span.name, 'bot_screen.thumbnail');
      expect(span.ended, isTrue);
      expect(span.attributes, {
        'hermes.version': '0.22.0',
        'outcome': 'frame',
        'bytes_kib': '16-64',
      });
    });

    test('the size buckets', () async {
      for (final (kib, bucket) in [
        (1, '<16'),
        (16, '16-64'),
        (64, '64-256'),
        (300, '>=256'),
      ]) {
        answer = () async => {'data_url': jpegOf(kib * 1024)};
        await repository.thumbnail(null);
        expect(tracer.spans.last.attributes['bytes_kib'], bucket);
      }
    });

    test('suppressed, stopped, timeout and error are outcomes', () async {
      final answers = <Future<Map<String, Object?>> Function()>[
        () async => {'data_url': null, 'suppressed': 'human_has_control'},
        () async => {'data_url': null},
        () async => throw const GatewayRequestTimeout(),
        () async => throw const GatewayRpcException(5300, 'no'),
      ];
      for (final next in answers) {
        answer = next;
        await repository.thumbnail('work');
      }

      expect(tracer.spans.map((s) => s.attributes['outcome']), [
        'suppressed',
        'stopped',
        'timeout',
        'error',
      ]);
      expect(
        tracer.spans.every((s) => !s.attributes.containsKey('bytes_kib')),
        isTrue,
      );
    });

    test('no attribute holds the picture, a path or the profile', () async {
      answer = () async => {'data_url': jpegOf(2048)};

      await repository.thumbnail('secret-profile');

      final all = tracer.spans.single.attributes.values.join(' ');
      expect(all, isNot(contains('data:')));
      expect(all, isNot(contains('secret-profile')));
    });
  });

  group('log events', () {
    test('method-not-found logs bot_screen.unsupported once', () async {
      answer = () async =>
          throw const GatewayRpcException(kGatewayMethodNotFound, 'unknown');

      await repository.status('work');
      await repository.status('work');

      expect(events, ['bot_screen.unsupported {}']);
    });

    test(
      'a failed call logs bot_screen.read_failed with method and type',
      () async {
        Future<void> succeed() async {
          answer = () async => {'supported': true};
          await repository.status('work');
        }

        answer = () async => throw const GatewayRequestTimeout();
        await repository.thumbnail('work');
        await succeed();
        answer = () async =>
            throw const GatewayRpcException(5300, 'secret text');
        await repository.start('work');
        await succeed();
        answer = () async => throw const GatewayConnectionClosed();
        await repository.status('work');

        expect(events, [
          'bot_screen.read_failed {method: display.thumbnail, error_type: timeout}',
          'bot_screen.read_failed {method: display.start, error_type: display_error}',
          'bot_screen.read_failed {method: display.status, error_type: closed}',
        ]);
      },
    );

    test('a streak of failures is logged once', () async {
      answer = () async => throw const GatewayRequestTimeout();

      await repository.thumbnail('work');
      await repository.thumbnail('work');
      await repository.status('work');

      expect(events, hasLength(1));
    });

    test('a call that is not a read failure leaves the logger alone', () async {
      answer = () async => throw StateError('programming error');

      await expectLater(repository.status('work'), throwsStateError);

      expect(events, isEmpty);
    });

    test('a status read logs nothing when it works', () async {
      answer = () async => {'supported': true, 'profile_key': '/home/u/work'};

      await repository.status('work');

      expect(events, isEmpty);
    });
  });

  test('a telemetry that throws never breaks a call', () async {
    final broken = BotScreenRepository(
      (method, params, {required timeout}) async =>
          throw const GatewayRequestTimeout(),
      telemetry: ConnectionTelemetry(
        tracer: ThrowingTracer(),
        events: (name, [attributes = const {}]) => throw StateError('logger'),
      ),
    );

    expect(
      await broken.thumbnail('work'),
      isA<BotScreenFailed<BotScreenFrame>>(),
    );
  });
}
