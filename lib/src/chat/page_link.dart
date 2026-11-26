import 'package:characters/characters.dart';

/// What the app may do with an address a tool result named.
enum PageLinkKind {
  /// An `http` or `https` address with a host and no credentials: it opens.
  web,

  /// A web address with a user name or password in it: it never opens and its
  /// credentials are never shown or copied.
  withCredentials,

  /// Any other scheme, or no address the app can read: it never opens.
  other,
}

/// An address from a tool result, read once so every place that shows or
/// opens it follows the same rules: only `http` and `https` open, and an
/// address with credentials never opens and never shows them.
class PageLink {
  const PageLink._({
    required this.kind,
    this.host = '',
    this.path = '',
    this.copyText,
    this.uri,
  });

  /// Reads [address]; never throws.
  factory PageLink.parse(String address) {
    final text = address.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return PageLink._(kind: PageLinkKind.other, path: _cap(text));
    }
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final host = _hostLabel(uri);
    final path = _pathLabel(uri);
    if (_authority(text).contains('@')) {
      return PageLink._(
        kind: isWeb ? PageLinkKind.withCredentials : PageLinkKind.other,
        host: host,
        copyText: isWeb ? uri.replace(userInfo: '').toString() : null,
      );
    }
    return isWeb
        ? PageLink._(
            kind: PageLinkKind.web,
            host: host,
            path: path,
            copyText: text,
            uri: uri,
          )
        : PageLink._(kind: PageLinkKind.other, host: host, path: path);
  }

  final PageLinkKind kind;

  /// The host as the address wrote it, with its port when it has one. Empty
  /// when the address has none.
  final String host;

  /// The path and query, which is empty for the root and for an address with
  /// credentials, and the capped address itself when it has no host.
  final String path;

  /// What Copy link copies: the address, without credentials. Null where there
  /// is no link to copy (another scheme).
  final String? copyText;

  /// The address to open; set only for [PageLinkKind.web].
  final Uri? uri;

  bool get opens => kind == PageLinkKind.web;

  /// The letter on the page's tile: the first of the host, without `www.`.
  String get monogram {
    final name = host.startsWith('www.') ? host.substring(4) : host;
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }
}

/// What sits between `://` and the first `/`, `?` or `#`, as written:
/// [Uri.authority] leaves out an empty user name.
String _authority(String text) =>
    RegExp(r'^[^:/?#]+://([^/?#]*)').firstMatch(text)?.group(1) ?? '';

/// [Uri] percent-encodes a host or path with non-ASCII letters: shown as the
/// letters, unless the encoding is not valid.
String _readable(String encoded) {
  try {
    return Uri.decodeFull(encoded);
  } on FormatException {
    return encoded;
  }
}

String _hostLabel(Uri uri) {
  final decoded = _readable(uri.host);
  final host = decoded.contains(':') ? '[$decoded]' : decoded;
  return uri.hasPort ? '$host:${uri.port}' : host;
}

String _pathLabel(Uri uri) {
  final path = uri.path == '/' ? '' : uri.path;
  return _readable(uri.hasQuery ? '$path?${uri.query}' : path);
}

/// An address that has no host is shown as text: capped, because a data
/// address can be very long, and not at all when it holds an `@`, which could
/// be credentials.
String _cap(String text) => text.contains('@')
    ? ''
    : text.characters.length <= 200
    ? text
    : '${text.characters.take(200)}…';
