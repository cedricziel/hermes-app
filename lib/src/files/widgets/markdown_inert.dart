/// The host a Markdown link names, for the question "Open example.com?", or
/// null when the link must do nothing: a relative link, an anchor, or any
/// scheme but web and mail. A `mailto:` link names the domain of its address.
String? markdownLinkHost(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return uri.host.isEmpty ? null : uri.host;
  }
  if (scheme == 'mailto') {
    final at = uri.path.lastIndexOf('@');
    if (at < 0 || at == uri.path.length - 1) return null;
    return uri.path.substring(at + 1);
  }
  return null;
}

final _image = RegExp(
  r'!\[([^\[\]]*)\]\(\s*[^\s()]*(?:\([^()\s]*\)[^\s()]*)*(?:\s+(?:"[^"]*"|'
  "'[^']*'"
  r'))?\s*\)',
);

/// [markdown] with every image replaced by its alt text, or by
/// [notLoaded] when it has none, so rendering it fetches nothing from the
/// network and loads nothing from a relative path. The renderer's own image
/// builder is the second line of defence.
String inertMarkdown(String markdown, {required String notLoaded}) =>
    markdown.replaceAllMapped(_image, (match) {
      final alt = match.group(1)!.trim();
      return alt.isEmpty ? notLoaded : alt;
    });
