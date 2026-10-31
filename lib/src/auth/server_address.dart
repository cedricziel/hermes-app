import 'dart:io';

/// Whether [host] is an address that stays on this device, the local network
/// or a tailnet: loopback, RFC 1918 and link-local IPv4, CGNAT (Tailscale's
/// 100.64.0.0/10), IPv6 loopback, link-local and unique local addresses
/// (Tailscale's `fd7a:115c:a1e0::/48` among them), `localhost`, `.local`,
/// `.lan`, `.home.arpa`, `.internal`, `.ts.net` and single-label names that
/// only a local resolver can answer.
///
/// Cleartext to such a host does not cross the internet, which is the rule
/// iOS and macOS apply with `NSAllowsLocalNetworking`.
bool isLocalHost(String host) {
  var name = host.toLowerCase().trim();
  if (name.startsWith('[') && name.endsWith(']')) {
    name = name.substring(1, name.length - 1);
  }
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name.isEmpty) return false;

  final address = InternetAddress.tryParse(name.split('%').first);
  if (address != null) return _isLocalAddress(address);

  // `134744072` or `0x08080808`: the resolver reads a bare number as an
  // IPv4 address (8.8.8.8 here), which [InternetAddress.tryParse] does not.
  if (RegExp(r'^(0x[0-9a-f]+|[0-9]+)$').hasMatch(name)) return false;

  if (name == 'localhost' || name.endsWith('.localhost')) return true;
  // A `.ts.net` name served publicly (Tailscale Funnel) answers only over
  // TLS, so http:// to one stays inside the tailnet.
  const suffixes = ['.local', '.lan', '.home.arpa', '.internal', '.ts.net'];
  if (suffixes.any(name.endsWith)) return true;
  // `hermes` or `nas`: a name without a dot resolves through the local
  // network's own DNS or mDNS, never the public one.
  return !name.contains('.');
}

bool _isLocalAddress(InternetAddress address) {
  final b = address.rawAddress;
  // 0.0.0.0 and :: (what `--host 0.0.0.0` prints) reach this device.
  if (b.every((x) => x == 0)) return true;
  if (address.type == InternetAddressType.IPv4) {
    return b[0] == 127 ||
        b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 169 && b[1] == 254) ||
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }
  if (address.isLoopback) return true;
  // fe80::/10 link-local, fc00::/7 unique local.
  if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;
  if ((b[0] & 0xfe) == 0xfc) return true;
  // An IPv4-mapped address (::ffff:a.b.c.d) is as local as its IPv4 part.
  final mapped =
      b.sublist(0, 10).every((x) => x == 0) && b[10] == 0xff && b[11] == 0xff;
  if (mapped) {
    return _isLocalAddress(InternetAddress.fromRawAddress(b.sublist(12, 16)));
  }
  return false;
}

/// Whether [url] sends traffic, the password sign-in and tokens included,
/// unencrypted across the internet: `http://` to a host that is not
/// [isLocalHost]. The app asks before connecting to one.
bool isCleartextToPublicHost(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'http' || uri.host.isEmpty) return false;
  return !isLocalHost(uri.host);
}

/// Whether a server answering [from] with a redirect to [to] moves the app
/// to cleartext across the internet the user did not accept: to a public
/// `http://` address when [from] was encrypted or local, or to another host
/// than the public `http://` one the user accepted.
bool redirectsToUnacceptedCleartext(String from, String to) {
  if (!isCleartextToPublicHost(to)) return false;
  if (!isCleartextToPublicHost(from)) return true;
  final a = Uri.parse(from), b = Uri.parse(to);
  return a.host.toLowerCase() != b.host.toLowerCase() || a.port != b.port;
}
