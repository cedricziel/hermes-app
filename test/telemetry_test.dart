import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';

void main() {
  group('TelemetryConfig.parseHeaders', () {
    test('splits comma separated key=value pairs', () {
      expect(
        TelemetryConfig.parseHeaders(
          'authorization=Bearer abc,x-tenant-id=homelab,x-dataset-id=apps',
        ),
        {
          'authorization': 'Bearer abc',
          'x-tenant-id': 'homelab',
          'x-dataset-id': 'apps',
        },
      );
    });

    test('keeps = inside values and skips malformed entries', () {
      expect(TelemetryConfig.parseHeaders('a=b==,,novalue,=nokey, c = d '), {
        'a': 'b==',
        'c': 'd',
      });
    });
  });

  group('Telemetry.initialize', () {
    TelemetryConfig config(String endpoint) => TelemetryConfig(
      otlpEndpoint: endpoint,
      otlpHeaders: const {},
      serviceName: 'hermes-app',
      serviceVersion: '',
      deploymentEnvironment: 'test',
    );

    test('is disabled without an endpoint and adds no interceptor', () async {
      final telemetry = await Telemetry.initialize(config(''));

      expect(telemetry.enabled, isFalse);
      expect(telemetry.dioInterceptor(), isNull);
    });

    test('leaves the error handlers alone when disabled', () async {
      final flutterHandler = FlutterError.onError;
      final platformHandler = PlatformDispatcher.instance.onError;
      final telemetry = await Telemetry.initialize(config(''));

      telemetry.logUncaughtErrors();

      expect(FlutterError.onError, same(flutterHandler));
      expect(PlatformDispatcher.instance.onError, same(platformHandler));
    });

    test('is disabled for an unusable endpoint instead of throwing', () async {
      final telemetry = await Telemetry.initialize(config('not a url'));

      expect(telemetry.enabled, isFalse);
      expect(telemetry.dioInterceptor(), isNull);
    });
  });
}
