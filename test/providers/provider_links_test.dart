import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_links.dart';

void main() {
  group('openableLink', () {
    test('an absolute https address with a host opens', () {
      expect(
        openableLink('https://openrouter.ai/keys'),
        Uri.parse('https://openrouter.ai/keys'),
      );
      expect(
        isOpenableLink('HTTPS://Portal.Example.com/device?code=AB-12'),
        isTrue,
      );
    });

    test('http opens only for a host that stays local', () {
      expect(isOpenableLink('http://localhost:8000/docs'), isTrue);
      expect(isOpenableLink('http://192.168.1.20/keys'), isTrue);
      expect(isOpenableLink('http://hermes.local/keys'), isTrue);
      expect(isOpenableLink('http://example.com/keys'), isFalse);
      expect(isOpenableLink('http://8.8.8.8/keys'), isFalse);
    });

    test('anything else is not opened', () {
      for (final value in [
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        'hermes://chat?prompt=hi',
        'file:///etc/passwd',
        'data:text/html,<b>x</b>',
        'intent://scan/#Intent;scheme=zxing;end',
        'mailto:someone@example.com',
        'ftp://example.com/key',
        '/keys',
        'keys',
        '//example.com/keys',
        'https:///keys',
        'https:example.com',
        'https://',
        ' https://example.com',
        '',
        'not a url',
      ]) {
        expect(openableLink(value), isNull, reason: value);
      }
    });

    test('null and non-links are not opened', () {
      expect(openableLink(null), isNull);
      expect(isOpenableLink(null), isFalse);
    });
  });
}
