import 'dart:convert';

class HandoffActivity {
  const HandoffActivity(this.serverUrl, this.profile, this.threadId);
  final String serverUrl;
  final String profile;
  final String threadId;

  Map<String, Object> get payload => {
    'version': 1,
    'serverUrl': serverUrl,
    'profile': profile,
    'threadId': threadId,
  };
  String get identity => jsonEncode(payload);

  static HandoffActivity? parse(Object? raw) {
    if (raw is! Map || raw['version'] != 1) return null;
    final url = raw['serverUrl'];
    final profile = raw['profile'];
    final id = raw['threadId'];
    if (url is! String ||
        profile is! String ||
        id is! String ||
        profile.trim().isEmpty ||
        id.trim().isEmpty) {
      return null;
    }
    try {
      if (utf8.encode(jsonEncode(raw)).length >= 3000) return null;
    } on Object {
      return null;
    }
    final canonical = server(url);
    return canonical == null ? null : HandoffActivity(canonical, profile, id);
  }

  static String? server(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.isAbsolute ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri
        .replace(path: uri.path.replaceAll(RegExp(r'/+$'), ''))
        .toString();
  }
}
