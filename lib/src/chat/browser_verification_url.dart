Uri? browserVerificationUrl(String? value) {
  if (value == null) return null;
  final authority = RegExp(
    r'^https://([^/?#]*)',
    caseSensitive: false,
  ).firstMatch(value)?.group(1);
  if (authority == null ||
      authority.contains('@') ||
      RegExp(r'[\s\\]').hasMatch(authority)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.authority.contains('@') ||
      uri.host.contains(RegExp(r'[\s/\\@?#]')) ||
      (uri.hasPort && (uri.port <= 0 || uri.port > 65535))) {
    return null;
  }
  return uri;
}
