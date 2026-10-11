import 'package:markdown/markdown.dart' as md;

/// Plain notification text with Markdown paragraphs, lists and labels retained.
String notificationPreview(String markdown) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  return document
      .parseLines(markdown.replaceAll('\r\n', '\n').split('\n'))
      .map(_render)
      .where((text) => text.isNotEmpty)
      .join('\n\n')
      .trim();
}

String _render(md.Node node) {
  if (node is md.Text) return node.text;
  final element = node as md.Element;
  final children = element.children ?? const <md.Node>[];
  switch (element.tag) {
    case 'ul':
    case 'ol':
      var number = int.tryParse(element.attributes['start'] ?? '') ?? 1;
      return children
          .map((child) {
            final marker = element.tag == 'ol' ? '${number++}.' : '•';
            return '$marker ${_render(child).trim().replaceAll('\n', '\n  ')}';
          })
          .join('\n');
    case 'p':
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      return children.map(_render).join().trim();
    case 'li':
    case 'blockquote':
      return children.map(_render).join('\n').trimRight();
    case 'br':
      return '\n';
    case 'hr':
      return '';
    case 'img':
      return element.attributes['alt'] ?? '';
    case 'pre':
      return element.textContent.trimRight();
    default:
      return children.map(_render).join();
  }
}
