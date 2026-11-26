import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/tool_image_loader.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_image_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fake_media_actions.dart';
import 'support/image_tool_fixtures.dart';
import 'support/pump_on_platform.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'iZk9HQAAAABJRU5ErkJggg==',
);

class _Source implements MediaSource {
  final paths = <String>[];
  var refuse = false;

  /// A path whose answer waits for its gate, and the bytes it then returns.
  final gates = <String, Completer<void>>{};
  final bytes = <String, Uint8List>{};

  @override
  Future<Uint8List> image(String path) async {
    paths.add(path);
    if (refuse) throw const MediaFetchException(MediaFailure.refused);
    await gates[path]?.future;
    return bytes[path] ?? Uint8List.fromList(_png);
  }

  @override
  Future<Uint8List> file(String path) => throw UnimplementedError();
}

class _Adapter implements HttpClientAdapter {
  final requests = <Uri>[];
  var status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromBytes(status == 200 ? _png : const [], status);
  }

  @override
  void close({bool force = false}) {}
}

/// A loader that never keeps what it loads, as one cleared just after a load.
class _ForgetfulLoader extends ToolImageLoader {
  @override
  Future<Uint8List> load(Uri uri) async => Uint8List.fromList(_png);
}

class _Setup {
  final source = _Source();
  final actions = FakeMediaActions();
  final adapter = _Adapter();
  late final loader = ToolImageLoader(dio: Dio()..httpClientAdapter = adapter);
  late final store = MediaStore(
    source: source,
    actions: actions,
    // Nothing of a tool image is a file: a staged one would ask for this.
    cacheDirectory: () => throw StateError('an image was staged on disk'),
  );
}

Future<_Setup> _pump(WidgetTester tester, ToolCall call) async {
  final setup = _Setup();
  await pumpOnPlatform(
    tester,
    MultiProvider(
      providers: [
        Provider<MediaStore?>.value(value: setup.store),
        Provider<ToolImageLoader?>.value(value: setup.loader),
      ],
      child: SingleChildScrollView(
        child: ToolCallCard(call: call, initiallyOpen: true),
      ),
    ),
    platform: TargetPlatform.android,
  );
  await _settle(tester);
  return setup;
}

/// Lets the loads that a tap or a build started finish: they run on the
/// test's fake clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 10));
  }
}

List<ToolImageState> _states(WidgetTester tester) => [
  for (final t in tester.widgetList<ToolImageTile>(find.byType(ToolImageTile)))
    t.state,
];

List<Map<String, Object?>> _nine() => [
  for (var i = 1; i <= 9; i++)
    pageImage('https://cdn.shop.example/$i.png', alt: 'Photo $i'),
];

void main() {
  group('browser_get_images', () {
    testWidgets('leaves out images under 32 px, keeps size 0, and says so', (
      tester,
    ) async {
      final setup = await _pump(
        tester,
        imagesCall(
          imagesAnswer([
            ..._nine(),
            pageImage('https://cdn.shop.example/dot.gif', width: 1, height: 1),
            pageImage('https://cdn.shop.example/i.png', width: 31, height: 80),
            pageImage('https://cdn.shop.example/j.png', width: 80, height: 31),
            pageImage('https://cdn.shop.example/k.png', width: 24, height: 24),
            pageImage('https://cdn.shop.example/l.png', width: 12, height: 12),
            // Not loaded yet: its size says nothing, so it stays.
            pageImage('https://cdn.shop.example/lazy.png', width: 0, height: 0),
          ]),
        ),
      );

      expect(find.text('10 images · 5 small ones hidden'), findsOne);
      expect(setup.adapter.requests, isEmpty);
    });

    testWidgets('shows six tiles, then all of them on Show all', (
      tester,
    ) async {
      await _pump(tester, imagesCall(imagesAnswer(_nine())));

      expect(find.byType(ToolImageTile), findsNWidgets(6));
      await tester.tap(find.text('Show all 9'));
      await tester.pump();
      expect(find.byType(ToolImageTile), findsNWidgets(9));
      expect(find.text('Show all 9'), findsNothing);
    });

    testWidgets('makes no request until a tap, and then one', (tester) async {
      final setup = await _pump(
        tester,
        imagesCall(imagesAnswer(_nine().take(2).toList())),
      );
      expect(setup.adapter.requests, isEmpty);
      expect(setup.source.paths, isEmpty);
      expect(find.text('Tap to load · cdn.shop.example'), findsNWidgets(2));
      expect(find.text('800 × 600 · cdn.shop.example'), findsNWidgets(2));

      await tester.tap(find.byType(ToolImageTile).first);
      await _settle(tester);

      expect(setup.adapter.requests, hasLength(1));
      expect(_states(tester), [ToolImageState.loaded, ToolImageState.idle]);
    });

    testWidgets('an http address is never loaded', (tester) async {
      final setup = await _pump(
        tester,
        imagesCall(imagesAnswer([pageImage('http://cdn.shop.example/a.png')])),
      );

      expect(find.text('Not secure. Open in browser'), findsOne);
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(setup.adapter.requests, isEmpty);
      expect(_states(tester), [ToolImageState.insecure]);
    });

    testWidgets('a failed load says so and a tap asks again, once', (
      tester,
    ) async {
      final setup = await _pump(
        tester,
        imagesCall(imagesAnswer([pageImage('https://cdn.shop.example/a.png')])),
      );
      setup.adapter.status = 500;
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(find.text("Couldn't load"), findsOne);
      expect(find.text('Tap to try again'), findsOne);
      expect(setup.adapter.requests, hasLength(1));

      setup.adapter.status = 200;
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(setup.adapter.requests, hasLength(2));
      expect(_states(tester), [ToolImageState.loaded]);
    });

    testWidgets('Load all loads every tile that shows, not the rest', (
      tester,
    ) async {
      final setup = await _pump(tester, imagesCall(imagesAnswer(_nine())));

      await tester.tap(find.text('Load all'));
      await _settle(tester);

      expect(setup.adapter.requests, hasLength(6));
    });

    testWidgets('an image without alt text is named by its place', (
      tester,
    ) async {
      await _pump(
        tester,
        imagesCall(
          imagesAnswer([
            pageImage('https://cdn.shop.example/a.png'),
            pageImage('https://cdn.shop.example/b.png'),
          ]),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('^image 2 of 2')), findsOne);
    });

    testWidgets('a loaded remote image opens in the in-memory viewer', (
      tester,
    ) async {
      final setup = await _pump(
        tester,
        imagesCall(imagesAnswer([pageImage('https://cdn.shop.example/a.png')])),
      );
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      await tester.tap(find.byType(ToolImageTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      // Never saved or staged: it exists in memory only.
      expect(viewer.onSave, isNull);
      expect(setup.adapter.requests, hasLength(1));
    });

    testWidgets('an image over the limit offers the browser instead', (
      tester,
    ) async {
      final setup = _Setup();
      final big = ToolImageLoader(
        dio: Dio()..httpClientAdapter = setup.adapter,
        maxBytes: 4,
      );
      await pumpOnPlatform(
        tester,
        Provider<ToolImageLoader?>.value(
          value: big,
          child: ToolCallCard(
            call: imagesCall(
              imagesAnswer([pageImage('https://cdn.shop.example/a.png')]),
            ),
            initiallyOpen: true,
          ),
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(find.text('Too large to load here. Open in browser'), findsOne);
      expect(_states(tester), [ToolImageState.tooLarge]);
    });

    testWidgets('a result that is not a list of images falls back', (
      tester,
    ) async {
      await _pump(tester, imagesCall({'success': true, 'images': 'none'}));
      expect(find.byType(ToolImageTile), findsNothing);

      await _pump(
        tester,
        imagesCall(imagesAnswer([pageImage('data:image/png;base64,AAAA')])),
      );
      expect(find.byType(ToolImageTile), findsNothing);
    });

    testWidgets('a page with no images says so', (tester) async {
      await _pump(tester, imagesCall(imagesAnswer(const [])));
      expect(find.text('No images'), findsOne);
    });
  });

  group('image_generate', () {
    testWidgets('while it runs, a skeleton and no request', (tester) async {
      final setup = await _pump(
        tester,
        generateCall(null, status: ToolCallStatus.running),
      );

      expect(find.text('Generating image…'), findsOne);
      expect(_states(tester), [ToolImageState.generating]);
      expect(setup.adapter.requests, isEmpty);
    });

    testWidgets('an address loads only on a tap', (tester) async {
      final setup = await _pump(
        tester,
        generateCall(generated('https://img.service.example/out/1.png')),
      );
      expect(setup.adapter.requests, isEmpty);
      expect(setup.source.paths, isEmpty);

      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(setup.adapter.requests, hasLength(1));
      expect(setup.source.paths, isEmpty);
    });

    testWidgets('an absolute path loads at once through the media store', (
      tester,
    ) async {
      final setup = await _pump(
        tester,
        generateCall(generated('/home/hermes/.hermes/images/out.png')),
      );

      expect(setup.source.paths, ['/home/hermes/.hermes/images/out.png']);
      expect(setup.adapter.requests, isEmpty);
      expect(_states(tester), [ToolImageState.loaded]);
    });

    testWidgets('a path the server refuses is "Couldn\'t load"', (
      tester,
    ) async {
      final setup = _Setup()..source.refuse = true;
      await pumpOnPlatform(
        tester,
        MultiProvider(
          providers: [
            Provider<MediaStore?>.value(value: setup.store),
            Provider<ToolImageLoader?>.value(value: setup.loader),
          ],
          child: ToolCallCard(
            call: generateCall(generated('/etc/other/out.png')),
            initiallyOpen: true,
          ),
        ),
        platform: TargetPlatform.android,
      );
      await _settle(tester);

      expect(find.text("Couldn't load"), findsOne);
      expect(find.text('Tap to try again'), findsOne);
    });

    testWidgets('a failure says No image made and keeps the server\'s words', (
      tester,
    ) async {
      await _pump(
        tester,
        generateCall({
          'success': false,
          'image': null,
          'error': 'The image service is busy.',
          'error_type': 'api_error',
        }),
      );

      expect(find.text('No image made.'), findsOne);
      expect(find.text('The image service is busy.'), findsOne);
    });
  });

  group('when things change under a tile', () {
    testWidgets('a running image_generate card that finishes shows its image', (
      tester,
    ) async {
      final setup = _Setup();
      Future<void> show(ToolCall call) => pumpOnPlatform(
        tester,
        MultiProvider(
          providers: [
            Provider<MediaStore?>.value(value: setup.store),
            Provider<ToolImageLoader?>.value(value: setup.loader),
          ],
          child: ToolCallCard(call: call, initiallyOpen: true),
        ),
        platform: TargetPlatform.android,
      );
      await show(generateCall(null, status: ToolCallStatus.running));
      expect(_states(tester), [ToolImageState.generating]);

      await show(generateCall(generated('https://img.service.example/1.png')));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(_states(tester), [ToolImageState.idle]);
    });

    testWidgets('a load that ends after a clear leaves a tile that waits', (
      tester,
    ) async {
      await pumpOnPlatform(
        tester,
        Provider<ToolImageLoader?>.value(
          value: _ForgetfulLoader(),
          child: ToolCallCard(
            call: imagesCall(
              imagesAnswer([pageImage('https://cdn.shop.example/a.png')]),
            ),
            initiallyOpen: true,
          ),
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);

      expect(_states(tester), [ToolImageState.idle]);
    });

    testWidgets('a fetch for the old items does not fill the new ones', (
      tester,
    ) async {
      final setup = _Setup();
      final old = '/srv/a/old.png';
      final fresh = '/srv/a/new.png';
      setup.source
        ..gates[old] = Completer<void>()
        ..bytes[old] = Uint8List.fromList([..._png, 0, 0, 0])
        ..bytes[fresh] = Uint8List.fromList(_png);
      Future<void> show(String path) => pumpOnPlatform(
        tester,
        MultiProvider(
          providers: [
            Provider<MediaStore?>.value(value: setup.store),
            Provider<ToolImageLoader?>.value(value: setup.loader),
          ],
          child: ToolCallCard(
            call: visionCall(visionAnswer(path: path)),
            initiallyOpen: true,
          ),
        ),
        platform: TargetPlatform.android,
      );
      await show(old);
      await show(fresh);
      await _settle(tester);

      setup.source.gates[old]!.complete();
      await _settle(tester);
      await tester.tap(find.byType(ToolImageTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      await viewer.onSave!();

      expect(setup.actions.saved.single.bytes, setup.source.bytes[fresh]);
    });

    testWidgets(
      'an open viewer of a remote image closes when the loader clears',
      (tester) async {
        final setup = await _pump(
          tester,
          imagesCall(
            imagesAnswer([pageImage('https://cdn.shop.example/a.png')]),
          ),
        );
        await tester.tap(find.byType(ToolImageTile));
        await _settle(tester);
        await tester.tap(find.byType(ToolImageTile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ImageViewerPage), findsOneWidget);

        await tester.runAsync(setup.loader.clear);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ImageViewerPage), findsNothing);
      },
    );

    testWidgets('a loaded tile waits for a tap again once the loader clears', (
      tester,
    ) async {
      final setup = await _pump(
        tester,
        imagesCall(imagesAnswer([pageImage('https://cdn.shop.example/a.png')])),
      );
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);
      expect(_states(tester), [ToolImageState.loaded]);

      await tester.runAsync(setup.loader.clear);
      await tester.pump();

      expect(_states(tester), [ToolImageState.idle]);
      await tester.tap(find.byType(ToolImageTile));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(_states(tester), [ToolImageState.loaded]);
      expect(setup.adapter.requests, hasLength(2));
    });
  });

  group('browser_vision', () {
    testWidgets(
      'shows the screenshot through the media store and the analysis',
      (tester) async {
        final setup = await _pump(tester, visionCall(visionAnswer()));

        expect(setup.source.paths, [
          '/home/hermes/.hermes/screenshots/page.png',
        ]);
        expect(setup.adapter.requests, isEmpty);
        expect(find.text('What Hermes saw'), findsOne);
        expect(
          find.textContaining('A shop page', findRichText: true),
          findsOne,
        );
      },
    );

    testWidgets('a screenshot opens with Save, named after its file', (
      tester,
    ) async {
      final setup = await _pump(tester, visionCall(visionAnswer()));
      await tester.tap(find.byType(ToolImageTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final viewer = tester.widget<ImageViewerPage>(
        find.byType(ImageViewerPage),
      );
      await viewer.onSave!();

      expect(setup.actions.saved.single.name, 'page.png');
    });

    testWidgets('a relative path is not the shape it expects', (tester) async {
      await _pump(tester, visionCall(visionAnswer(path: 'page.png')));
      expect(find.byType(ToolImageTile), findsNothing);
    });
  });

  testWidgets('rendering a gallery makes no HTTP client of its own', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await _pump(tester, imagesCall(imagesAnswer(_nine())));
    }, createHttpClient: (_) => throw StateError('no request before a tap'));
    expect(tester.takeException(), isNull);
  });
}
