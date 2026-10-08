import 'dart:ui' show ErrorCallback;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';

class _RecordingExporter implements LogRecordExporter {
  final records = <LogRecord>[];
  OTelResource? resource;

  @override
  Future<ExportResult> export(
    List<LogRecord> records,
    OTelResource resource,
  ) async {
    this.records.addAll(records);
    this.resource = resource;
    return const ExportResult.success();
  }

  @override
  Future<void> shutdown() async {}
}

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

  group('Telemetry.logUncaughtErrors', () {
    TelemetryConfig config() => TelemetryConfig(
      otlpEndpoint: 'https://collector.example.com',
      otlpHeaders: const {},
      serviceName: 'hermes-app',
      serviceVersion: '',
      deploymentEnvironment: 'test',
    );

    late FlutterExceptionHandler? previousFlutterHandler;
    late ErrorCallback? previousPlatformHandler;

    setUp(() {
      previousFlutterHandler = FlutterError.onError;
      previousPlatformHandler = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    });

    test('puts the app in the hermes-app service namespace', () async {
      final exporter = _RecordingExporter();
      final telemetry = await Telemetry.initialize(
        config(),
        logExporter: exporter,
      );
      telemetry.events()('auth.signed_in');
      await telemetry.flush();

      expect(exporter.resource?.attributes['service.namespace'], 'hermes-app');
    });

    test(
      'attaches breadcrumbs recorded through events() to a crash record',
      () async {
        final exporter = _RecordingExporter();
        final telemetry = await Telemetry.initialize(
          config(),
          logExporter: exporter,
        );
        telemetry.logUncaughtErrors();
        telemetry.events()('auth.signed_in');
        telemetry.events()('session.created', {'profile': 'work'});

        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('boom')),
        );
        await telemetry.flush();

        final crash = exporter.records.singleWhere(
          (r) => r.body == 'Uncaught Flutter error',
        );
        expect(crash.attributes['exception.type'], 'StateError');
        expect(crash.attributes['breadcrumbs'], [
          contains('auth.signed_in'),
          contains('session.created'),
        ]);
      },
    );

    test('attaches breadcrumbs from breadcrumbs() to a crash without exporting them', () async {
      final exporter = _RecordingExporter();
      final telemetry = await Telemetry.initialize(
        config(),
        logExporter: exporter,
      );
      telemetry.logUncaughtErrors();
      telemetry.breadcrumbs()('nav.destination', {'destination': 'kanban'});
      telemetry.events()('auth.signed_in');

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
      await telemetry.flush();

      final crash = exporter.records.singleWhere(
        (r) => r.body == 'Uncaught Flutter error',
      );
      expect(crash.attributes['breadcrumbs'], [
        allOf(contains('nav.destination'), contains('kanban')),
        contains('auth.signed_in'),
      ]);
      expect(
        exporter.records.map((r) => r.body),
        isNot(contains('nav.destination')),
      );
    });

    test(
      'exports an error that repeats every frame once, then its count',
      () async {
        final exporter = _RecordingExporter();
        final telemetry = await Telemetry.initialize(
          config(),
          logExporter: exporter,
        );
        telemetry.logUncaughtErrors();
        final details = FlutterErrorDetails(
          exception: StateError('null check'),
          stack: StackTrace.current,
        );

        fakeAsync((async) {
          for (var i = 0; i < 50; i++) {
            FlutterError.onError!(details);
          }
          async.elapse(const Duration(minutes: 1));
        });
        await telemetry.flush();

        expect(
          [
            for (final r in exporter.records)
              if (r.body == 'Uncaught Flutter error')
                r.attributes['exception.repeat_count'],
          ],
          [null, 49],
        );
      },
    );

    test('records no breadcrumb while telemetry is off', () async {
      final telemetry = await Telemetry.initialize(
        TelemetryConfig(
          otlpEndpoint: '',
          otlpHeaders: const {},
          serviceName: 'hermes-app',
          serviceVersion: '',
          deploymentEnvironment: 'test',
        ),
      );

      expect(() => telemetry.breadcrumbs()('nav.destination'), returnsNormally);
    });

    test('exports the message, stack trace and breadcrumbs of an uncaught async error', () async {
      final exporter = _RecordingExporter();
      final telemetry = await Telemetry.initialize(
        config(),
        logExporter: exporter,
      );
      telemetry.logUncaughtErrors();
      telemetry.events()('auth.signed_in');
      final stackTrace = StackTrace.current;

      PlatformDispatcher.instance.onError!(
        ArgumentError('bad input'),
        stackTrace,
      );
      await telemetry.flush();

      final crash = exporter.records.singleWhere(
        (r) => r.body == 'Uncaught async error',
      );
      expect(crash.attributes['exception.type'], 'ArgumentError');
      expect(crash.attributes['exception.message'], contains('bad input'));
      expect(crash.attributes['exception.stacktrace'], stackTrace.toString());
      expect(crash.attributes['breadcrumbs'], [contains('auth.signed_in')]);
    });
  });

  group('Telemetry.forConnection', () {
    TelemetryConfig config(String endpoint) => TelemetryConfig(
      otlpEndpoint: endpoint,
      otlpHeaders: const {},
      serviceName: 'hermes-app',
      serviceVersion: '',
      deploymentEnvironment: 'test',
    );

    late FlutterExceptionHandler? previousFlutterHandler;
    late ErrorCallback? previousPlatformHandler;

    setUp(() {
      previousFlutterHandler = FlutterError.onError;
      previousPlatformHandler = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    });

    test('is nothing when disabled', () async {
      final telemetry = await Telemetry.initialize(config(''));
      final connection = telemetry.forConnection(const {
        'hermes.version': '0.14.2',
      });

      expect(connection.interceptor, isNull);
      expect(connection.events, same(noopAppEventLogger));
    });

    test('logs events with the server attributes, under their own, and keeps '
        'breadcrumbs without them', () async {
      final exporter = _RecordingExporter();
      final telemetry = await Telemetry.initialize(
        config('https://collector.example.com'),
        logExporter: exporter,
      );
      telemetry.logUncaughtErrors();
      final connection = telemetry.forConnection(const {
        'hermes.version': '0.14.2',
        'hermes.install_id': 'inst_42',
        'state': 'shadowed',
      });

      connection.events('auth.state', {'state': 'ready'});
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
      await telemetry.flush();

      final event = exporter.records.singleWhere((r) => r.body == 'auth.state');
      expect(event.attributes['hermes.install_id'], 'inst_42');
      expect(event.attributes['state'], 'ready');
      final crash = exporter.records.singleWhere(
        (r) => r.body == 'Uncaught Flutter error',
      );
      final breadcrumbs = crash.attributes['breadcrumbs']! as List;
      expect(breadcrumbs.single, contains('auth.state'));
      expect(breadcrumbs.single, isNot(contains('inst_42')));
    });

    test('adds an interceptor that describes requests', () async {
      final telemetry = await Telemetry.initialize(
        config('https://collector.example.com'),
        logExporter: _RecordingExporter(),
      );

      expect(telemetry.forConnection(const {}).interceptor, isNotNull);
    });
  });
}
