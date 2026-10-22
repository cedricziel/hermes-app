import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/network/user_certificates.dart';

import '../support/local_authority.dart';

Future<int> _get(SecurityContext context, Uri url) async {
  final client = HttpClient(context: context);
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

void main() {
  late LocalAuthority authority;

  setUp(() async => authority = await LocalAuthority.start());
  tearDown(() => authority.close());

  test('a server with a user-installed authority can be reached', () async {
    final context = SecurityContext(withTrustedRoots: false);
    await expectLater(
      _get(context, authority.url),
      throwsA(isA<HandshakeException>()),
    );

    await UserCertificates(
      read: () async => {'CN=Hermes Test Local Authority': authority.rootDer},
      context: context,
    ).load();

    expect(await _get(context, authority.url), 200);
  });

  test('a store that cannot be read or holds junk changes nothing', () async {
    final context = SecurityContext(withTrustedRoots: false);

    await UserCertificates(
      read: () async => throw Exception('no store'),
      context: context,
    ).load();
    await UserCertificates(
      read: () async => {
        'junk': Uint8List.fromList([1, 2, 3]),
      },
      context: context,
    ).load();

    await expectLater(
      _get(context, authority.url),
      throwsA(isA<HandshakeException>()),
    );
  });
}
