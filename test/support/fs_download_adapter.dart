import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';

/// Answers a download with a body the test feeds by hand, so it can see what
/// happens between the headers and the last chunk: [chunks] is the body,
/// [headers] its response headers.
class FsDownloadAdapter implements HttpClientAdapter {
  FsDownloadAdapter({this.status = 200, this.length});

  final int status;

  /// Sent as `Content-Length` when set.
  final int? length;
  // Closed by the test that feeds it.
  // ignore: close_sinks
  final chunks = StreamController<Uint8List>();
  final requests = <RequestOptions>[];

  /// Whether the headers were handed to the client, before any chunk.
  var answered = false;

  Dio dio() =>
      Dio(BaseOptions(baseUrl: 'http://hermes.test'))..httpClientAdapter = this;

  HermesApiClient client() => HermesApiClient(dio());

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    answered = true;
    return ResponseBody(
      chunks.stream,
      status,
      headers: {
        if (length != null) Headers.contentLengthHeader: ['$length'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
