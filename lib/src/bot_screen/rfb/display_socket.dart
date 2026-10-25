import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../auth/connect_failure.dart';
import '../../chat/gateway/gateway_connection.dart';

enum DisplaySocketErrorKind {
  /// The dashboard's Host/Origin policy refused the upgrade (HTTP 403).
  notAllowed,

  /// The certificate check failed.
  untrustedCertificate,

  /// Any other failure to reach the dashboard.
  unreachable,
}

/// Why the display socket could not be opened.
///
/// It holds the kind and nothing else: the original exception's message names
/// the stream URL, which carries the single-use display ticket, and the crash
/// reporter logs full messages.
class DisplaySocketError implements Exception {
  const DisplaySocketError(this.kind);

  final DisplaySocketErrorKind kind;

  @override
  String toString() => 'DisplaySocketError(${kind.name})';
}

/// The display socket's URL: the dashboard's origin and path prefix, then
/// [path], with the display [ticket] as the only query parameter.
Uri displaySocketUri(String baseUrl, String path, String ticket) =>
    gatewayUri(baseUrl, {'display_ticket': ticket}, path: path);

/// Opens the display socket. The channel is returned uncast so the caller can
/// read the server's close code and close with a status code of its own.
/// Throws [DisplaySocketError], never the underlying exception.
Future<WebSocketChannel> openDisplaySocket(
  String baseUrl,
  String path,
  String ticket,
) async {
  try {
    return await connectWebSocketChannel(
      displaySocketUri(baseUrl, path, ticket),
    );
  } catch (error) {
    throw displaySocketErrorFor(error);
  }
}

/// Maps a connect failure by its type and HTTP status only.
DisplaySocketError displaySocketErrorFor(Object error) {
  final cause = error is WebSocketChannelException
      ? (error.inner ?? error)
      : error;
  if (cause is WebSocketException &&
      cause.httpStatusCode == HttpStatus.forbidden) {
    return const DisplaySocketError(DisplaySocketErrorKind.notAllowed);
  }
  if (cause is TlsException && isCertificateFailure(cause)) {
    return const DisplaySocketError(
      DisplaySocketErrorKind.untrustedCertificate,
    );
  }
  return const DisplaySocketError(DisplaySocketErrorKind.unreachable);
}
