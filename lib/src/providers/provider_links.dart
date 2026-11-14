import '../auth/server_address.dart';

/// The address to open for a link Hermes sent (a key signup page, a sign-in
/// verification page, docs), or null when it must not be opened: only an
/// absolute `https` URL with a host qualifies, and `http` only for a host
/// [isLocalHost] accepts. `javascript:`, `hermes://`, `file:`, relative and
/// scheme-less addresses all come back null, so their button is not drawn.
Uri? openableLink(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return null;
  return switch (uri.scheme) {
    'https' => uri,
    'http' when isLocalHost(uri.host) => uri,
    _ => null,
  };
}

bool isOpenableLink(String? value) => openableLink(value) != null;
