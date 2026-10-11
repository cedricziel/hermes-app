import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/hermes_session.dart';

/// Tells one account on one server from another without keeping either: a
/// hash of the server address and the session's user id (none for a server
/// without sign-in). State kept on the device for an account (a baseline,
/// say) carries it and is ignored under any other.
///
/// The app in front and a background run both ask here, with the address they
/// connected to and the session they hold, so their keys cannot differ.
String accountKeyFor(String baseUrl, HermesSession? session) => sha256
    .convert(utf8.encode('$baseUrl\n${session?.userId ?? ''}'))
    .toString();
