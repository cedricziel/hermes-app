import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Tells one account on one server from another without keeping either: a
/// hash of the server address and user id. State kept on the device for an
/// account (a baseline, say) carries it and is ignored under any other.
String accountKeyFor(String baseUrl, String? userId) =>
    sha256.convert(utf8.encode('$baseUrl\n${userId ?? ''}')).toString();
