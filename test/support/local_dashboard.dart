import 'dart:convert';
import 'dart:io';

/// A dashboard on a real loopback socket, for workflows that run the whole
/// app: [AuthController] builds its own Dio, so the fake HTTP adapter the
/// other tests use cannot be slipped in. Routes are matched on path only; an
/// unknown path answers 404.
class LocalDashboard {
  LocalDashboard._(this._server);

  final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<LocalDashboard> start(Map<String, Object?> routes) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final body = routes[request.uri.path];
      request.response
        ..statusCode = body == null ? 404 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body ?? {'detail': 'Not Found'}))
        ..close();
    });
    return LocalDashboard._(server);
  }

  Future<void> close() => _server.close(force: true);
}
