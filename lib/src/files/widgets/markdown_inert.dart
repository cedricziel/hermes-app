/// The thing a Markdown link names, for the question "Open example.com?": the
/// host of a web link, the whole address of a `mailto:` link, or null when
/// the link must do nothing: a relative link, an anchor, or any other scheme.
String? markdownLinkHost(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return uri.host.isEmpty ? null : uri.host;
  }
  if (scheme == 'mailto') {
    final address = uri.path;
    final at = address.lastIndexOf('@');
    return at <= 0 || at == address.length - 1 ? null : address;
  }
  return null;
}

final _image = RegExp(
  r'!\[([^\[\]]*)\]\(\s*[^\s()]*(?:\([^()\s]*\)[^\s()]*)*(?:\s+(?:"[^"]*"|'
  "'[^']*'"
  r'))?\s*\)',
);

/// `![alt][ref]`, whose address is a definition elsewhere in the file.
final _referenceImage = RegExp(r'!\[([^\[\]]*)\]\[[^\[\]]*\]');

/// `[text](target)` that is not an image.
final _link = RegExp(
  r'(?<!!)\[([^\[\]]*)\]\(\s*([^\s()]*(?:\([^()\s]*\)[^\s()]*)*)'
  r'(?:\s+(?:"[^"]*"|'
  "'[^']*'"
  r'))?\s*\)',
);

/// [markdown] made inert for rendering:
///
/// - every image, inline or by reference, becomes its alt text, or the
///   italic [notLoaded] notice when it has none, so nothing is fetched from
///   the network or loaded from a relative path;
/// - a link that would do nothing (a relative link, an anchor, an unknown
///   scheme) becomes its plain text, instead of a link that looks tappable.
///
/// The renderer's own image builder and `html: false` are further lines of
/// defence.
String inertMarkdown(String markdown, {required String notLoaded}) {
  String alt(Match match) {
    final text = match.group(1)!.trim();
    return text.isEmpty ? '*$notLoaded*' : text;
  }

  return markdown
      .replaceAllMapped(_image, alt)
      .replaceAllMapped(_referenceImage, alt)
      .replaceAllMapped(
        _link,
        (match) => markdownLinkHost(match.group(2)!) == null
            ? match.group(1)!
            : match.group(0)!,
      );
}
