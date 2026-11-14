import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import '../files/files_failure.dart';
import '../files/files_models.dart' show FsDownload;
import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';
import 'request_timeout.dart';

/// Thin typed wrapper around the Hermes dashboard REST API
/// (`hermes_cli/web_server.py` + `hermes_cli/dashboard_auth/routes.py`).
///
/// This client only issues requests; it does not attach auth headers or
/// handle 401/refresh itself — [AuthController] owns the [Dio] instance and
/// its interceptors so token refresh and sign-out can update app state.
///
/// [fetchStatus], [fetchAuthProviders] and [fetchMe] are hand-parsed because
/// the backend's OpenAPI spec doesn't declare response schemas for those
/// three routes (see `openapi/hermes-agent.openapi.json`), so codegen has
/// nothing to build a typed model from. [fetchSessionToken] reads a page, not
/// an API route, and needs the same [Dio]. Every other endpoint has a
/// generated, typed method on [raw] — see
/// `scripts/generate_hermes_api_client.sh` to regenerate it from a newer
/// spec, and prefer adding to [raw]'s call sites over hand-rolling another
/// `_dio.get`/`.post` for new features.
class HermesApiClient {
  HermesApiClient(this._dio) : raw = DefaultApi(_dio);

  final Dio _dio;

  /// The generated client, covering every endpoint the spec declares a
  /// response or request schema for.
  final DefaultApi raw;

  /// `GET /api/status` — public, unauthenticated. Used to discover whether
  /// the auth gate is engaged and which flows are supported before any
  /// sign-in attempt.
  Future<HermesStatus> fetchStatus() async => (await probeStatus()).status;

  /// [fetchStatus], plus the base URL the server answered from when it
  /// redirected there, as a proxy does from `http://` to `https://`. Later
  /// POSTs must go there directly: Dio does not follow their redirects.
  Future<({HermesStatus status, String? redirectedTo})> probeStatus() async {
    final response = await _dio.get<dynamic>('/api/status');
    final status = _parseObject(response.data, HermesStatus.fromJson, 'status');
    final asked = response.requestOptions.uri;
    final real = asked.resolveUri(response.realUri);
    if (real == asked || !real.path.endsWith('/api/status')) {
      return (status: status, redirectedTo: null);
    }
    final base = Uri(
      scheme: real.scheme,
      userInfo: real.userInfo,
      host: real.host,
      port: real.port,
      path: real.path.substring(0, real.path.length - '/api/status'.length),
    );
    return (status: status, redirectedTo: base.toString());
  }

  /// `GET /api/auth/providers` — public. Lists the registered sign-in
  /// options for the login screen.
  Future<List<AuthProviderInfo>> fetchAuthProviders() async {
    final response = await _dio.get<dynamic>('/api/auth/providers');
    final data = response.data;
    if (data == null) return const [];
    if (data is! Map) throw const FormatException('malformed providers body');
    final raw = data['providers'];
    if (raw == null) return const [];
    if (raw is! List || raw.any((e) => e is! Map<String, dynamic>)) {
      throw const FormatException('malformed providers list');
    }
    return raw
        .map((e) => AuthProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /` — the dashboard page embeds the session token that opens
  /// `/api/ws` on a server without the auth gate (there is no REST route
  /// for it). Null when the page carries none.
  Future<String?> fetchSessionToken() async {
    final response = await _dio.get<String>(
      '/',
      options: Options(responseType: ResponseType.plain),
    );
    return RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(response.data ?? '')
        ?.group(1);
  }

  /// `GET /api/plugins/kanban/attachments/{id}` — a task attachment's bytes.
  /// The generated method cannot return them: it decodes the body as JSON, which
  /// would corrupt a binary file, and takes no way to ask for raw bytes.
  Future<Uint8List> fetchKanbanAttachment(int id, {String? board}) =>
      _getBytes('/api/plugins/kanban/attachments/$id', {'board': ?board});

  /// `GET /api/files/download?path=` — the bytes of a file on the server, by
  /// its absolute path. The generated method decodes the body as JSON, which
  /// would corrupt a binary file, so this asks for raw bytes like
  /// [fetchKanbanAttachment]. The session goes in the header, never in the URL.
  Future<Uint8List> fetchManagedFile(String path) =>
      _getBytes('/api/files/download', {'path': path});

  /// `GET /api/fs/download?path=&profile=` — streams a file on the server into
  /// [sink], never holding it whole. The generated method decodes the body as
  /// JSON, which would corrupt a binary file and read it all into memory, so
  /// this asks for the stream like [fetchKanbanAttachment] asks for bytes.
  ///
  /// The headers arrive before the body: [onHeaders] gets the announced
  /// `Content-Length` (null when the server sends none, as an SSH workspace
  /// does) and returns false to stop there, with nothing written
  /// ([FsDownload.declined]). It is synchronous on purpose: the Dio adapter
  /// starts reading the body as soon as the headers are in, so a caller that
  /// awaited something here would leave the body buffering in memory. The
  /// body is read one chunk at a time, paused until the sink has taken it, so
  /// a slow disk holds the connection back instead of filling memory.
  /// [onProgress] gets the bytes written so far and that length. A gap of [idleTimeout] between two chunks fails the
  /// download; the request has no total deadline, since a large file may take
  /// long. [cancelToken] ends it at once. The caller closes [sink] and
  /// deletes a partial file on a throw.
  ///
  /// Every failure is an [FsDownloadException] holding only a kind: a
  /// [DioException] carries the request's URI and so the file's path, and
  /// never leaves this method. A body shorter or longer than its
  /// `Content-Length` is [FilesFailure.unreadable].
  Future<FsDownload> downloadFsFile(
    String path, {
    String? profile,
    required IOSink sink,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
    bool Function(int? contentLength)? onHeaders,
    Duration idleTimeout = const Duration(seconds: 30),
  }) async {
    final request = CancelToken();
    unawaited(
      cancelToken?.whenCancel.then((_) {
        if (!request.isCancelled) request.cancel();
      }),
    );
    FsDownloadException failed(FilesFailure kind) => FsDownloadException(
      cancelToken?.isCancelled ?? false ? FilesFailure.cancelled : kind,
    );
    try {
      final response = await _dio.get<ResponseBody>(
        '/api/fs/download',
        queryParameters: {'path': path, 'profile': ?profile},
        cancelToken: request,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: idleTimeout,
          // The default validateStatus: a 401 must be a DioException so the
          // auth interceptors refresh the session and retry.
          // Hermes may compress; a body must match its Content-Length.
          headers: {HttpHeaders.acceptEncodingHeader: 'identity'},
          // Only a backstop: the idle timeout ends a stalled download.
          extra: requestDeadlineExtra(const Duration(hours: 12)),
        ),
      );
      final body = response.data!;
      final announced = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      final length = announced != null && announced >= 0 ? announced : null;
      if (onHeaders != null && !onHeaders(length)) {
        request.cancel();
        return FsDownload(bytes: 0, contentLength: length, declined: true);
      }
      var received = 0;
      onProgress?.call(0, length);
      final done = Completer<void>();
      void end([Object? error]) {
        if (done.isCompleted) return;
        error == null ? done.complete() : done.completeError(error);
      }

      late final StreamSubscription<List<int>> subscription;
      subscription = body.stream
          .timeout(idleTimeout)
          .listen(
            (chunk) {
              try {
                sink.add(chunk);
                received += chunk.length;
                onProgress?.call(received, length);
              } on Object catch (error) {
                end(error);
                return;
              }
              // Take no more until the sink has written this one.
              subscription.pause();
              sink.flush().then((_) {
                if (!done.isCompleted) subscription.resume();
              }, onError: end);
            },
            onError: end,
            onDone: end,
            cancelOnError: true,
          );
      unawaited(request.whenCancel.then(end));
      try {
        await done.future;
      } finally {
        await subscription.cancel();
      }
      await sink.flush();
      if (length != null && received != length) {
        throw failed(FilesFailure.unreadable);
      }
      return FsDownload(bytes: received, contentLength: length);
    } on FsDownloadException {
      rethrow;
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.type == DioExceptionType.badResponse && data is ResponseBody) {
        final detail = await _errorDetail(data, idleTimeout);
        throw failed(
          filesFailureForStatus(
            error.response?.statusCode,
            detail,
            fileRoute: true,
          ),
        );
      }
      throw failed(filesFailureForDio(error, fileRoute: true));
    } on TimeoutException {
      throw failed(FilesFailure.unreachable);
    } on SocketException {
      throw failed(FilesFailure.unreachable);
    } on HttpException {
      throw failed(FilesFailure.unreachable);
    } on Object {
      throw failed(FilesFailure.unreadable);
    }
  }

  /// The `detail` of an error body that was asked for as a stream, reading no
  /// more than a few KB of it.
  static Future<String?> _errorDetail(
    ResponseBody body,
    Duration timeout,
  ) async {
    try {
      final bytes = <int>[];
      await for (final chunk in body.stream.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) break;
      }
      return errorDetail(jsonDecode(utf8.decode(bytes, allowMalformed: true)));
    } on Object {
      return null;
    }
  }

  Future<Uint8List> _getBytes(String route, Map<String, dynamic> query) async {
    final response = await _dio.get<List<int>>(
      route,
      queryParameters: query,
      options: Options(
        responseType: ResponseType.bytes,
        extra: requestDeadlineExtra(const Duration(minutes: 5)),
      ),
    );
    final data = response.data;
    return data is Uint8List ? data : Uint8List.fromList(data ?? const []);
  }

  /// `GET /api/auth/me` — auth-required. The verified session for the
  /// signed-in user. With [accessToken] the request carries that token
  /// explicitly, to check one that is not the stored session yet.
  Future<HermesIdentity> fetchMe({String? accessToken}) async {
    final response = await _dio.get<dynamic>(
      '/api/auth/me',
      options: accessToken == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _parseObject(response.data, HermesIdentity.fromJson, 'identity');
  }

  /// Throws [FormatException] for a body that is not an object; [parse]
  /// rejects wrongly typed fields the same way.
  static T _parseObject<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parse,
    String what,
  ) {
    if (data == null) return parse(const {});
    if (data is! Map<String, dynamic>) {
      throw FormatException('malformed $what body');
    }
    return parse(data);
  }
}
