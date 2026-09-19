import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart';

import 'package:hermes_app/src/api/hermes_api_client.dart';

void main() {
  test(
    'exposes the generated client for endpoints beyond the hand-parsed three',
    () {
      final client = HermesApiClient(Dio());

      expect(client.raw, isA<DefaultApi>());
    },
  );
}
