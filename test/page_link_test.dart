import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/page_link.dart';

void main() {
  group('which addresses open', () {
    test('http and https open', () {
      for (final address in ['http://example.com/', 'https://example.com/a']) {
        final link = PageLink.parse(address);
        expect(link.kind, PageLinkKind.web, reason: address);
        expect(link.opens, isTrue, reason: address);
        expect(link.uri, Uri.parse(address), reason: address);
      }
    });

    test('any other scheme does not', () {
      for (final address in [
        'ftp://files.example.com/a.txt',
        'file:///etc/hosts',
        'javascript:alert(1)',
        'mailto:someone@example.com',
        'data:text/html,hi',
        'example.com/page',
        '',
        'https:///no-host',
      ]) {
        final link = PageLink.parse(address);
        expect(link.opens, isFalse, reason: address);
        expect(link.uri, isNull, reason: address);
        expect(link.copyText, isNull, reason: address);
      }
    });

    test('a scheme in capitals is still a web address', () {
      expect(PageLink.parse('HTTPS://Example.com/A').opens, isTrue);
    });
  });

  group('credentials', () {
    test('make an address not open and never show', () {
      final link = PageLink.parse('https://user:secret@example.com/private');
      expect(link.kind, PageLinkKind.withCredentials);
      expect(link.opens, isFalse);
      expect(link.uri, isNull);
      expect(link.host, 'example.com');
      expect(link.path, isEmpty);
      for (final shown in [link.host, link.path, link.copyText]) {
        expect(shown, isNot(contains('secret')));
        expect(shown, isNot(contains('user')));
      }
    });

    test('copy without them', () {
      expect(
        PageLink.parse('https://user:secret@example.com/').copyText,
        'https://example.com/',
      );
      expect(
        PageLink.parse('http://token@example.com:8080/a?b=1').copyText,
        'http://example.com:8080/a?b=1',
      );
    });

    test('an empty user name still counts', () {
      expect(PageLink.parse('https://@example.com/').opens, isFalse);
      expect(PageLink.parse('https://:pw@example.com/').opens, isFalse);
    });

    test('another scheme with them shows the host only and has no link', () {
      final link = PageLink.parse('ftp://me:secret@files.example.com/a.txt');
      expect(link.opens, isFalse);
      expect(link.host, 'files.example.com');
      expect(link.path, isEmpty);
      expect(link.copyText, isNull);
    });

    test('text with an @ and no host is not shown', () {
      expect(PageLink.parse('me:secret@example.com/x').path, isEmpty);
    });
  });

  group('host and path', () {
    test('split an address', () {
      final link = PageLink.parse('https://example.com/docs/page?x=1#top');
      expect(link.host, 'example.com');
      expect(link.path, '/docs/page?x=1');
    });

    test('the root has no path', () {
      expect(PageLink.parse('https://example.com/').path, isEmpty);
      expect(PageLink.parse('https://example.com').path, isEmpty);
    });

    test('a port stays with the host', () {
      expect(PageLink.parse('http://localhost:8080/a').host, 'localhost:8080');
    });

    test('an IPv6 host keeps its brackets', () {
      expect(PageLink.parse('http://[::1]:9000/').host, '[::1]:9000');
    });

    test('an address with no host is shown as text, capped', () {
      expect(PageLink.parse('javascript:alert(1)').path, 'javascript:alert(1)');
      final long = PageLink.parse('data:text/plain,${'a' * 5000}').path;
      expect(long.length, lessThan(250));
      expect(long, endsWith('…'));
    });

    test('an IDN host is kept as written', () {
      final link = PageLink.parse('https://münchen.de/straße');
      expect(link.opens, isTrue);
      expect(link.host, 'münchen.de');
      expect(link.path, contains('stra'));
      expect(link.monogram, 'M');
      expect(
        PageLink.parse('https://xn--mnchen-3ya.de/').host,
        'xn--mnchen-3ya.de',
      );
    });
  });

  group('the monogram', () {
    test('is the first letter of the host in capitals', () {
      expect(PageLink.parse('https://example.com/').monogram, 'E');
    });

    test('skips www.', () {
      expect(PageLink.parse('https://www.docs.example.com/').monogram, 'D');
    });

    test('is a question mark with no host', () {
      expect(PageLink.parse('javascript:1').monogram, '?');
    });
  });
}
