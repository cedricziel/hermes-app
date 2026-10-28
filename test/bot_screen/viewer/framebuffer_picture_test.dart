import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_client.dart';
import 'package:hermes_app/src/bot_screen/viewer/bot_screen_viewer.dart';

import '../../../widgetbook/bot_screen_fixture.dart';

/// Records each request for an image and holds its answer until the test
/// gives one, as the engine answers a little later.
class _Decoder {
  final requests = <void Function(ui.Image)>[];
  final sizes = <(int, int)>[];

  void call(
    Uint8List pixels,
    int width,
    int height,
    ui.PixelFormat format,
    ui.ImageDecoderCallback callback,
  ) {
    sizes.add((width, height));
    requests.add(callback);
  }
}

void main() {
  late _Decoder decoder;
  late Framebuffer framebuffer;
  var revision = 0;
  late StateSetter bump;

  setUp(() {
    decoder = _Decoder();
    framebuffer = Framebuffer(8, 4);
    revision = 0;
  });

  Future<ui.Image> image(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(botScreenFixturePng());
        return (await codec.getNextFrame()).image;
      }))!;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          bump = setState;
          return FramebufferPicture(
            framebuffer: framebuffer,
            revision: revision,
            decode: decoder.call,
          );
        },
      ),
    ),
  );

  testWidgets('asks for one image after the first frame', (tester) async {
    await pump(tester);
    expect(decoder.requests, isEmpty);

    await tester.pump();

    expect(decoder.requests, hasLength(1));
    expect(decoder.sizes.single, (8, 4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('turns many updates within a frame into one image', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    decoder.requests.single(await image(tester));
    await tester.pump();
    expect(decoder.requests, hasLength(1));

    for (var i = 0; i < 10; i++) {
      bump(() => revision++);
    }
    await tester.pump();
    await tester.pump();

    expect(decoder.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an update that arrives while an image is made is made next', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    expect(decoder.requests, hasLength(1));

    bump(() => revision++);
    await tester.pump();
    await tester.pump();
    expect(decoder.requests, hasLength(1), reason: 'one at a time');

    decoder.requests[0](await image(tester));
    await tester.pump();
    await tester.pump();

    expect(decoder.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposes the previous image once the next is ready', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    final first = await image(tester);
    decoder.requests[0](first);
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    expect(first.debugDisposed, isFalse);

    bump(() => revision++);
    await tester.pump();
    await tester.pump();
    final second = await image(tester);
    decoder.requests[1](second);
    await tester.pump();

    expect(first.debugDisposed, isTrue);
    expect(second.debugDisposed, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draws the picture whole inside its box', (tester) async {
    await pump(tester);
    await tester.pump();
    decoder.requests[0](await image(tester));
    await tester.pump();

    expect(tester.widget<RawImage>(find.byType(RawImage)).fit, BoxFit.contain);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposes its image when it leaves the screen', (tester) async {
    await pump(tester);
    await tester.pump();
    final shown = await image(tester);
    decoder.requests[0](shown);
    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(shown.debugDisposed, isTrue);
  });

  testWidgets('disposes an image that arrives after it left the screen', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    final late = await image(tester);

    decoder.requests[0](late);

    expect(late.debugDisposed, isTrue);
  });
}
