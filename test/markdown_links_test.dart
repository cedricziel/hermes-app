import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/widgets/markdown_links.dart';

void main() {
  Future<List<Uri>> tap(String url) async {
    final opened = <Uri>[];
    markdownLinkHandler(
      open: (uri) async {
        opened.add(uri);
        return true;
      },
    )(url, 'label');
    await Future<void>.delayed(Duration.zero);
    return opened;
  }

  test('opens web and mail links', () async {
    expect(await tap('https://example.com'), [
      Uri.parse('https://example.com'),
    ]);
    expect(await tap(' http://example.com/x '), [
      Uri.parse('http://example.com/x'),
    ]);
    expect(await tap('mailto:a@example.com'), [
      Uri.parse('mailto:a@example.com'),
    ]);
  });

  test('ignores relative links and other schemes', () async {
    expect(await tap('/docs/readme.md'), isEmpty);
    expect(await tap('javascript:alert(1)'), isEmpty);
    expect(await tap('file:///etc/passwd'), isEmpty);
    expect(await tap('hermes://open'), isEmpty);
  });

  test('a link that fails to open does not throw', () async {
    final handler = markdownLinkHandler(open: (_) => throw Exception('nope'));
    handler('https://example.com', 'label');
    await Future<void>.delayed(Duration.zero);
  });
}
