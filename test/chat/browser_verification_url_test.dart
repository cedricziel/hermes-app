import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/browser_verification_url.dart';

void main() {
  test('verification links preserve the supplied HTTPS destination', () {
    final uri = browserVerificationUrl(
      'https://verify.example:8443/device?code=synthetic#step',
    );
    expect(uri?.host, 'verify.example');
    expect(uri?.port, 8443);
    expect(uri?.query, 'code=synthetic');
    expect(uri?.fragment, 'step');
  });
  test('unsupported schemes and embedded credentials cannot become browser actions', () {
    for (final value in <String?>[
      null,
      '',
      'http://verify.example',
      'javascript:alert(1)',
      'file:///private/tmp/test',
      'https://user:secret@verify.example',
      'https://@verify.example',
      'https://verify.example:0',
      'https://verify.example:65536',
      'https://bad host.example',
    ]) {
      expect(browserVerificationUrl(value), isNull, reason: value);
    }
  });
}
