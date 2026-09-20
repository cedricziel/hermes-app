import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/hermes_api_client.dart';

/// Why a file could not be fetched.
enum MediaFailure { missing, refused, tooLarge, failed }

class MediaFetchException implements Exception {
  const MediaFetchException(this.reason);

  final MediaFailure reason;

  @override
  String toString() => 'MediaFetchException($reason)';
}

/// Where the bytes of a file on the server come from.
abstract interface class MediaSource {
  /// An image, small enough to show. Throws [MediaFetchException].
  Future<Uint8List> image(String path);

  /// Any file, in full. Throws [MediaFetchException].
  Future<Uint8List> file(String path);
}

/// Fetches from a Hermes dashboard through the signed-in client, so the
/// session's token and its refresh are handled where they always are.
class HermesMediaSource implements MediaSource {
  HermesMediaSource(this._api);

  /// The client of the moment; null while not connected.
  final HermesApiClient? Function() _api;

  /// `GET /api/media` answers only for images under Hermes' own media
  /// folders, as a data URL. Any other image, or one it will not serve by its
  /// extension, comes from the download route instead.
  @override
  Future<Uint8List> image(String path) => _guard((api) async {
    try {
      final response = await api.raw.getMediaApiMediaGet(path: path);
      return _decodeDataUrl((response.data as Map?)?['data_url']);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 403 && status != 415) rethrow;
      return api.fetchManagedFile(path);
    }
  });

  @override
  Future<Uint8List> file(String path) =>
      _guard((api) => api.fetchManagedFile(path));

  Future<Uint8List> _guard(
    Future<Uint8List> Function(HermesApiClient api) fetch,
  ) async {
    final api = _api();
    if (api == null) throw const MediaFetchException(MediaFailure.failed);
    try {
      return await fetch(api);
    } on MediaFetchException {
      rethrow;
    } on DioException catch (e) {
      throw MediaFetchException(switch (e.response?.statusCode) {
        404 => MediaFailure.missing,
        403 => MediaFailure.refused,
        413 => MediaFailure.tooLarge,
        _ => MediaFailure.failed,
      });
    } on Object {
      throw const MediaFetchException(MediaFailure.failed);
    }
  }
}

Uint8List _decodeDataUrl(Object? url) {
  if (url is! String) throw const FormatException('no data URL');
  final comma = url.indexOf(',');
  if (!url.startsWith('data:') || comma < 0) {
    throw const FormatException('not a data URL');
  }
  return base64Decode(url.substring(comma + 1));
}
