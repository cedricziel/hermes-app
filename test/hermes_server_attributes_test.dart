import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/telemetry/hermes_server_attributes.dart';

const _fullStatus = <String, dynamic>{
  'version': '0.14.2',
  'release_date': '2026-09-30',
  'config_version': 7,
  'install_id': 'inst_42',
  'auth_required': true,
  'auth_providers': ['basic'],
  'auth_flows': ['native_pkce'],
  'gateway_mode': 'multiplex',
  'profiles': ['default', 'work', 'research'],
  'gateway_state': 'running',
  'overall': 'ok',
};

void main() {
  test('maps a full status answer to the hermes.* attributes', () {
    expect(hermesServerAttributes(_fullStatus), {
      'hermes.version': '0.14.2',
      'hermes.release_date': '2026-09-30',
      'hermes.config_version': 7,
      'hermes.install_id': 'inst_42',
      'hermes.auth.required': true,
      'hermes.auth.providers': ['basic'],
      'hermes.gateway.mode': 'multiplex',
      'hermes.profile.count': 3,
      'hermes.gateway.state': 'running',
      'hermes.overall': 'ok',
    });
  });

  test('leaves out fields an older server does not send', () {
    expect(
      hermesServerAttributes({'version': '0.9.0', 'auth_required': false}),
      {'hermes.version': '0.9.0', 'hermes.auth.required': false},
    );
  });

  test('drops only the fields with an unexpected type', () {
    final attributes = hermesServerAttributes({
      ..._fullStatus,
      'config_version': 'seven',
      'profiles': 'x',
      'auth_providers': ['basic', 3],
    });

    expect(attributes.containsKey('hermes.config_version'), isFalse);
    expect(attributes.containsKey('hermes.profile.count'), isFalse);
    expect(attributes.containsKey('hermes.auth.providers'), isFalse);
    expect(attributes['hermes.version'], '0.14.2');
    expect(attributes['hermes.install_id'], 'inst_42');
  });

  test('leaves out the profile count when Hermes could not list them', () {
    final attributes = hermesServerAttributes({
      ..._fullStatus,
      'gateway_mode': 'unknown',
      'profiles': <String>[],
    });

    expect(attributes['hermes.gateway.mode'], 'unknown');
    expect(attributes.containsKey('hermes.profile.count'), isFalse);
  });

  test('records no path, address, pid or profile name of an ungated '
      'server', () {
    final attributes = hermesServerAttributes({
      ..._fullStatus,
      'hermes_home': '/home/me/.hermes',
      'config_path': '/home/me/.hermes/config.yaml',
      'env_path': '/home/me/.hermes/.env',
      'gateway_pid': 4242,
      'gateway_health_url': 'http://127.0.0.1:8642/health',
      'gateways': [
        {'profile': 'work', 'port': 8642},
      ],
    });

    final values = attributes.values.expand(
      (value) => value is List ? value : [value],
    );
    expect(attributes.keys, everyElement(startsWith('hermes.')));
    expect(attributes, hasLength(10));
    for (final leaked in [
      '/home/me/.hermes',
      4242,
      'http://127.0.0.1:8642/health',
      'work',
      'default',
    ]) {
      expect(values, isNot(contains(leaked)));
    }
  });

  test('HermesStatus keeps the attributes and still parses a bad '
      'config_version', () {
    final status = HermesStatus.fromJson({
      ..._fullStatus,
      'config_version': 'seven',
    });

    expect(status.authRequired, isTrue);
    expect(status.serverAttributes['hermes.version'], '0.14.2');
    expect(
      status.serverAttributes.containsKey('hermes.config_version'),
      isFalse,
    );
  });
}
