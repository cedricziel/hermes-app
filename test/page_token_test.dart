import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/auth/page_token.dart';

class _Page extends HermesApiClient {
  _Page(this.fetch) : super(Dio());

  final Future<String?> Function() fetch;

  @override
  Future<String?> fetchSessionToken() => fetch();
}

void main() {
  test('a failed request reads as no token and is asked again', () async {
    var calls = 0;
    final token = PageToken(
      _Page(() async {
        calls++;
        throw DioException(requestOptions: RequestOptions());
      }),
    );

    expect(await token.get(), isNull);
    expect(await token.get(), isNull);
    expect(calls, 2);
  });

  test('a programming error is not hidden as a missing token', () async {
    final token = PageToken(_Page(() async => throw StateError('bug')));

    await expectLater(token.get(), throwsStateError);
    await expectLater(token.get(), throwsStateError);
  });
}
