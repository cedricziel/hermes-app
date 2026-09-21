import 'package:dart_otel_instrumentation_dio/dart_otel_instrumentation_dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';

import 'support/fake_hermes_server.dart';
import 'support/recording_tracer.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

/// What the MCP calls that carry a secret export: the install request has the
/// credential, the sign-in answer has the authorization URL.
void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late _RecordingLogger logger;
  late HermesMcpRepository repository;

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    logger = _RecordingLogger();
    final dio = server.dio()
      ..interceptors.add(DioOTelInterceptor.privacy(logger, tracer: tracer));
    repository = HermesMcpRepository(HermesApiClient(dio).raw);
  });

  String exported() => [
    for (final s in tracer.spans) ...[s.name, ...s.attributes.values],
    for (final r in logger.records) ...[r.body, ...r.attributes.values],
  ].join(' ');

  test(
    'an install exports neither the credential name nor its value',
    () async {
      server.on('POST', '/api/mcp/catalog/install', mcpInstallBody(name: 'x'));

      await repository.installEntry(
        const HermesMcpCatalogEntry(
          name: 'airtable',
          transport: McpTransport.remote,
          requiredEnv: [
            HermesMcpCredential(name: 'AIRTABLE_API_KEY', prompt: 'Token'),
          ],
        ),
        env: {'AIRTABLE_API_KEY': 'pat-super-secret'},
      );

      expect(tracer.spans, isNotEmpty);
      expect(exported(), isNot(contains('AIRTABLE_API_KEY')));
      expect(exported(), isNot(contains('pat-super-secret')));
    },
  );

  test('a sign-in exports no authorization URL', () async {
    server.on(
      'POST',
      '/api/mcp/servers/asana/auth',
      mcpFlowBody(
        authorizationUrl: 'https://auth.example/authorize?state=s3cr3t',
      ),
    );

    server.on('DELETE', '/api/mcp/oauth/flows/flow-1', {'ok': true});

    await repository.startSignIn('asana');
    await repository.cancelFlow('flow-1');

    expect(tracer.spans, isNotEmpty);
    expect(exported(), isNot(contains('auth.example')));
    expect(exported(), isNot(contains('s3cr3t')));
    expect(exported(), isNot(contains('flow-1')));
  });

  test('adding a server exports no token, environment value or body', () async {
    server.on('POST', '/api/mcp/servers', mcpServerRow(name: 'x'));

    await repository.addServer(
      const McpNewRemoteServer(
        name: 'linear',
        url: 'https://mcp.linear.app/mcp',
        auth: McpRemoteAuth.bearerToken,
        bearerToken: 'lin_api_super_secret',
      ),
    );
    await repository.addServer(
      const McpNewCommandServer(
        name: 'notes',
        command: 'npx',
        args: ['-y', 'some-package'],
        env: {'NOTES_TOKEN': 'env-super-secret'},
      ),
    );

    expect(tracer.spans, isNotEmpty);
    for (final secret in [
      'lin_api_super_secret',
      'env-super-secret',
      'NOTES_TOKEN',
      'some-package',
      'bearer_token',
    ]) {
      expect(exported(), isNot(contains(secret)));
    }
  });

  test('replacing the servers exports no part of the map', () async {
    server.on('PUT', '/api/mcp/servers', {'ok': true});

    await repository.replaceServers({
      'notes': {
        'command': 'npx',
        'env': {'NOTES_TOKEN': 'env-super-secret'},
        'headers': {'Authorization': 'Bearer header-super-secret'},
      },
    });

    expect(tracer.spans, isNotEmpty);
    for (final secret in [
      'env-super-secret',
      'header-super-secret',
      'NOTES_TOKEN',
      'Authorization',
    ]) {
      expect(exported(), isNot(contains(secret)));
    }
  });

  test('loading the configuration exports none of its content', () async {
    server.on('GET', '/api/config', {
      'mcp_servers': {
        'notes': {
          'env': {'NOTES_TOKEN': 'env-super-secret'},
        },
      },
    });

    await repository.loadRawServers();

    expect(tracer.spans, isNotEmpty);
    expect(exported(), isNot(contains('env-super-secret')));
    expect(exported(), isNot(contains('NOTES_TOKEN')));
  });
}
