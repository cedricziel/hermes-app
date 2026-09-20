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

  group('Telemetry.isExportableEndpoint', () {
    bool exportable(String url) =>
        Telemetry.isExportableEndpoint(Uri.parse(url));

    test('accepts https', () {
      expect(exportable('https://collector.example.com:4318'), isTrue);
      expect(exportable('HTTPS://collector.example.com'), isTrue);
    });

    test('accepts http only for loopback hosts', () {
      expect(exportable('http://localhost:4318'), isTrue);
      expect(exportable('http://127.0.0.1:4318'), isTrue);
      expect(exportable('http://[::1]:4318'), isTrue);
      expect(exportable('http://collector.example.com'), isFalse);
      expect(exportable('http://localhost.example.com'), isFalse);
      expect(exportable('http://127.0.0.1.example.com'), isFalse);
    });

    test('rejects other schemes and missing hosts', () {
      expect(exportable('ftp://localhost'), isFalse);
      expect(exportable('https://'), isFalse);
      expect(exportable('collector.example.com:4318'), isFalse);
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

    for (final endpoint in [
      'http://collector.example.com:4318',
      'http://192.168.1.20:4318',
      'ftp://collector.example.com',
    ]) {
      test('is disabled for the non-https endpoint $endpoint', () async {
        final telemetry = await Telemetry.initialize(config(endpoint));

        expect(telemetry.enabled, isFalse);
        expect(telemetry.dioInterceptor(), isNull);
      });
    }
  });
}
