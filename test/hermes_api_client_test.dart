import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart';

import 'package:hermes_app/src/api/hermes_api_client.dart';

import 'support/fake_hermes_server.dart';

void main() {
  test(
    'exposes the generated client for endpoints beyond the hand-parsed three',
    () {
      final client = HermesApiClient(Dio());

      expect(client.raw, isA<DefaultApi>());
    },
  );

  test('returns the decoded JSON body for routes whose spec has no response schema', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([sessionRow(id: 's1')]));

    final response = await server.client().raw.getSessionsApiSessionsGet();

    expect((response.data as Map)['total'], 1);
  });
}
