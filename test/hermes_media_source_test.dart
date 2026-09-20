import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/media/media_source.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesMediaSource source;

  setUp(() {
    server = FakeHermesServer();
    source = HermesMediaSource(() => server.client());
  });

  String dataUrl(List<int> bytes, {String type = 'image/png'}) =>
      'data:$type;base64,${base64Encode(bytes)}';

  Future<MediaFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on MediaFetchException catch (e) {
      return e.reason;
    }
    fail('expected a MediaFetchException');
  }

  group('image', () {
    test('asks /api/media for the path and decodes the data URL', () async {
      server.on(
        'GET',
        '/api/media',
        {'data_url': dataUrl(kTinyPng)},
        query: {'path': '/home/u/.hermes/images/a.png'},
      );

      final bytes = await source.image('/home/u/.hermes/images/a.png');

      expect(bytes, kTinyPng);
      expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
    });

    test('falls back to the download route when the server refuses the '
        'path for /api/media', () async {
      server.on('GET', '/api/media', {
        'detail': 'Path outside media roots',
      }, status: 403);
      server.on(
        'GET',
        '/api/files/download',
        Uint8List.fromList(kTinyPng),
        query: {'path': '/work/chart.png'},
      );

      expect(await source.image('/work/chart.png'), kTinyPng);
    });

    test('falls back to the download route for an extension it does not '
        'serve', () async {
      server.on('GET', '/api/media', {
        'detail': 'Unsupported media type',
      }, status: 415);
      server.on('GET', '/api/files/download', Uint8List.fromList(kTinyPng));

      expect(await source.image('/work/photo.heic'), kTinyPng);
    });

    test('the download route refusing it too is a refusal', () async {
      server.on('GET', '/api/media', {'detail': 'no'}, status: 403);
      server.on('GET', '/api/files/download', {'detail': 'no'}, status: 403);

      expect(
        await failureOf(source.image('/work/.env.png')),
        MediaFailure.refused,
      );
    });

    test('a missing file is not looked for again', () async {
      server.on('GET', '/api/media', {'detail': 'gone'}, status: 404);

      expect(await failureOf(source.image('/a.png')), MediaFailure.missing);
      expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
    });

    test('a file over the limit is too large', () async {
      server.on('GET', '/api/media', {'detail': 'big'}, status: 413);

      expect(await failureOf(source.image('/a.png')), MediaFailure.tooLarge);
    });

    test('a body without a data URL is a failure', () async {
      server.on('GET', '/api/media', {'data_url': 'nope'});

      expect(await failureOf(source.image('/a.png')), MediaFailure.failed);
    });

    test('a server error is a failure', () async {
      server.on('GET', '/api/media', {'detail': 'boom'}, status: 500);

      expect(await failureOf(source.image('/a.png')), MediaFailure.failed);
    });
  });

  group('file', () {
    test('reads the bytes of the download route unchanged', () async {
      final everyByte = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);
      server.on(
        'GET',
        '/api/files/download',
        everyByte,
        query: {'path': '/srv/report.pdf'},
      );

      expect(await source.file('/srv/report.pdf'), everyByte);
    });

    test('never puts the token in the URL', () async {
      server.on('GET', '/api/files/download', Uint8List.fromList([1]));

      await source.file('/srv/report.pdf');

      final request = server.requestsTo('GET', '/api/files/download').single;
      expect(request.queryParameters.keys, ['path']);
    });

    test('says why the server would not send it', () async {
      final cases = {
        404: MediaFailure.missing,
        403: MediaFailure.refused,
        413: MediaFailure.tooLarge,
        400: MediaFailure.failed,
        500: MediaFailure.failed,
      };
      for (final MapEntry(key: status, value: reason) in cases.entries) {
        server.on('GET', '/api/files/download', {
          'detail': 'x',
        }, status: status);
        expect(
          await failureOf(source.file('/srv/a.pdf')),
          reason,
          reason: '$status',
        );
      }
    });

    test('a dropped connection is a failure', () async {
      server.onRequest('GET', '/api/files/download', (request) {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        );
      });

      expect(await failureOf(source.file('/srv/a.pdf')), MediaFailure.failed);
    });

    test('without a connection to a server it fails', () async {
      final offline = HermesMediaSource(() => null);

      expect(await failureOf(offline.file('/srv/a.pdf')), MediaFailure.failed);
      expect(await failureOf(offline.image('/a.png')), MediaFailure.failed);
    });
  });
}
