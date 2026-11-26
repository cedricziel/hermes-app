import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/tool_image_loader.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:material_ui/material_ui.dart';

/// A 1 x 1 PNG, so a decoder has something real to draw.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'iZk9HQAAAABJRU5ErkJggg==',
);

final _cdn = Uri.parse('https://cdn.example/a.png');

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok([List<int>? bytes, Map<String, List<String>>? headers]) =>
    ResponseBody.fromBytes(bytes ?? _png, 200, headers: headers);

ResponseBody _redirect(String to, [int status = 302]) => ResponseBody.fromBytes(
  const [],
  status,
  headers: {
    'location': [to],
  },
);

(ToolImageLoader, _Adapter) _loader(
  FutureOr<ResponseBody> Function(RequestOptions options) respond, {
  List<String>? crumbs,
  int maxBytes = 1024,
}) {
  final adapter = _Adapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    ToolImageLoader(
      dio: dio,
      maxBytes: maxBytes,
      breadcrumbs: crumbs == null
          ? Breadcrumbs.none
          : Breadcrumbs.of(_Trail(crumbs)),
    ),
    adapter,
  );
}

class _Trail extends BreadcrumbTrail {
  _Trail(this.sink);

  final List<String> sink;

  @override
  void record(String name, [Map<String, Object> attributes = const {}]) =>
      sink.add('$name $attributes');
}

Future<ToolImageOutcome> _outcome(Future<Object?> load) async {
  try {
    await load;
    return ToolImageOutcome.ok;
  } on ToolImageException catch (e) {
    return e.outcome;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads over https with no credentials of any kind', () async {
    final (loader, adapter) = _loader((_) => _ok());

    final bytes = await loader.load(_cdn);

    expect(bytes, _png);
    final headers = adapter.requests.single.headers.keys.map(
      (k) => k.toLowerCase(),
    );
    expect(headers, isNot(contains('authorization')));
    expect(headers, isNot(contains('cookie')));
  });

  test('an http address is refused before any request', () async {
    final (loader, adapter) = _loader((_) => _ok());

    expect(
      await _outcome(loader.load(Uri.parse('http://cdn.example/a.png'))),
      ToolImageOutcome.insecure,
    );
    expect(adapter.requests, isEmpty);
  });

  test('an address with a user name or password is refused', () async {
    final (loader, adapter) = _loader((_) => _ok());

    expect(
      await _outcome(loader.load(Uri.parse('https://u:p@cdn.example/a.png'))),
      ToolImageOutcome.insecure,
    );
    expect(adapter.requests, isEmpty);
  });

  test('a redirect to http is not followed', () async {
    final (loader, adapter) = _loader(
      (o) =>
          o.uri.scheme == 'https' ? _redirect('http://evil.example/a') : _ok(),
    );

    expect(await _outcome(loader.load(_cdn)), ToolImageOutcome.insecure);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'a redirect to another https host is followed, up to three times',
    () async {
      var hops = 0;
      final (loader, adapter) = _loader(
        (o) => hops++ < 3 ? _redirect('https://h$hops.example/a') : _ok(),
      );

      expect(await loader.load(_cdn), _png);
      expect(adapter.requests, hasLength(4));

      hops = -1;
      expect(
        await _outcome(loader.load(Uri.parse('https://other.example/b'))),
        ToolImageOutcome.failed,
      );
    },
  );

  test('an image over the limit is too large, announced or streamed', () async {
    final (announced, _) = _loader(
      (_) => _ok(_png, {
        'content-length': ['999999'],
      }),
    );
    expect(await _outcome(announced.load(_cdn)), ToolImageOutcome.tooLarge);

    final (streamed, _) = _loader(
      (_) => ResponseBody(
        Stream.fromIterable([for (var i = 0; i < 4; i++) Uint8List(400)]),
        200,
      ),
    );
    expect(await _outcome(streamed.load(_cdn)), ToolImageOutcome.tooLarge);
  });

  test('a response that has not finished after 15 s fails', () {
    fakeAsync((async) {
      final (loader, _) = _loader((_) => Completer<ResponseBody>().future);
      ToolImageOutcome? outcome;
      unawaited(_outcome(loader.load(_cdn)).then((o) => outcome = o));

      async.elapse(const Duration(seconds: 14));
      expect(outcome, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(outcome, ToolImageOutcome.failed);
    });
  });

  test('a status that is not 200 fails', () async {
    final (loader, _) = _loader((_) => ResponseBody.fromBytes(const [], 404));

    expect(await _outcome(loader.load(_cdn)), ToolImageOutcome.failed);
  });

  test('the outcome reaches a breadcrumb that holds no address', () async {
    final crumbs = <String>[];
    final (loader, _) = _loader(
      (o) => o.uri.path == '/a.png'
          ? _ok()
          : ResponseBody.fromBytes(const [], 500),
      crumbs: crumbs,
    );

    await loader.load(_cdn);
    await _outcome(loader.load(Uri.parse('https://secret-host.example/b')));
    await _outcome(loader.load(Uri.parse('http://secret-host.example/c')));

    expect(crumbs, [
      'chat.tool_image.loaded {outcome: ok}',
      'chat.tool_image.loaded {outcome: failed}',
      'chat.tool_image.loaded {outcome: insecure}',
    ]);
  });

  test('a loaded image is not requested again, and loads at once', () async {
    final (loader, adapter) = _loader((_) => _ok());

    await Future.wait([loader.load(_cdn), loader.load(_cdn)]);
    await loader.load(_cdn);

    expect(adapter.requests, hasLength(1));
    expect(loader.bytesOf(_cdn), _png);
  });

  test(
    'a failed load is asked again by the next call, not by itself',
    () async {
      var fail = true;
      final (loader, adapter) = _loader(
        (_) => fail ? ResponseBody.fromBytes(const [], 500) : _ok(),
      );

      expect(await _outcome(loader.load(_cdn)), ToolImageOutcome.failed);
      expect(adapter.requests, hasLength(1));
      fail = false;
      expect(await loader.load(_cdn), _png);
    },
  );

  test('a load in flight when the loader clears keeps nothing', () async {
    final gate = Completer<void>();
    final (loader, _) = _loader((_) async {
      await gate.future;
      return _ok();
    });

    final pending = _outcome(loader.load(_cdn));
    await loader.clear();
    gate.complete();
    await pending;

    expect(loader.bytesOf(_cdn), isNull);
  });

  test('past its memory budget the oldest image goes', () async {
    final adapter = _Adapter((_) => _ok());
    final loader = ToolImageLoader(
      dio: Dio()..httpClientAdapter = adapter,
      memoryBudget: _png.length + 10,
    );
    final second = Uri.parse('https://cdn.example/b.png');

    await loader.load(_cdn);
    await loader.load(second);

    expect(loader.bytesOf(_cdn), isNull);
    expect(loader.bytesOf(second), _png);
  });

  test('clear and eviction tell the listeners, and a cleared image has no provider', () async {
    final (loader, _) = _loader((_) => _ok());
    var told = 0;
    loader.changes.addListener(() => told++);
    await loader.load(_cdn);

    await loader.clear();

    expect(told, 1);
    expect(loader.imageFor(_cdn), isNull);
  });

  test('writes nothing to disk', () async {
    final (loader, _) = _loader((_) => _ok());

    await IOOverrides.runZoned(
      () => loader.load(_cdn),
      createFile: (path) => fail('wrote $path'),
      createDirectory: (path) => fail('made $path'),
    );
  });

  testWidgets('clear drops the bytes and the decoded frames', (tester) async {
    final (loader, _) = _loader((_) => _ok());
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    await tester.runAsync(() async {
      await loader.load(_cdn);
      await precacheImage(loader.imageFor(_cdn, width: 64)!, context);
      await precacheImage(loader.imageFor(_cdn)!, context);
    });
    expect(cache.currentSize, 2);

    await tester.runAsync(loader.clear);

    expect(cache.currentSize, 0);
    expect(loader.bytesOf(_cdn), isNull);
  });

  test('another image\'s frames stay when the loader clears', () async {
    final (loader, _) = _loader((_) => _ok());
    final cache = PaintingBinding.instance.imageCache..clear();
    final other = MemoryImage(Uint8List.fromList(_png));
    final stream = other.resolve(ImageConfiguration.empty);
    final done = Completer<void>();
    stream.addListener(ImageStreamListener((_, _) => done.complete()));
    await done.future;
    expect(cache.currentSize, 1);

    await loader.clear();

    expect(cache.currentSize, 1);
  });

  test('sign-out clears the loader', () async {
    final (loader, _) = _loader((_) => _ok());
    final signedOut = StreamController<void>.broadcast(sync: true);
    addTearDown(signedOut.close);
    loader.clearOnSignOut(signedOut.stream);
    await loader.load(_cdn);

    signedOut.add(null);

    expect(loader.bytesOf(_cdn), isNull);
  });

  test(
    'App Lock covering the app clears the loader, uncovering does not',
    () async {
      final (loader, _) = _loader((_) => _ok());
      final lock = ValueNotifier(false);
      addTearDown(lock.dispose);
      loader.clearWhenLocked(lock, () => lock.value);
      await loader.load(_cdn);

      lock.value = true;
      expect(loader.bytesOf(_cdn), isNull);

      await loader.load(_cdn);
      lock.value = false;
      expect(loader.bytesOf(_cdn), _png);
    },
  );
}
