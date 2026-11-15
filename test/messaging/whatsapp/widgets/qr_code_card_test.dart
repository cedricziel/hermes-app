import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/widgets/qr_code_card.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import 'whatsapp_widget_host.dart';

/// The tile's pixels at one pixel per point.
class _Pixels {
  _Pixels(this.width, this.height, this._bytes);

  final int width;
  final int height;
  final ByteData _bytes;

  (int, int, int) at(int x, int y) {
    final i = (y * width + x) * 4;
    return (_bytes.getUint8(i), _bytes.getUint8(i + 1), _bytes.getUint8(i + 2));
  }
}

Future<_Pixels> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = _Pixels(image.width, image.height, bytes!);
    image.dispose();
    return result;
  }))!;
}

Widget _tile(GlobalKey key, String payload, {double size = kQrTileSize}) =>
    Center(
      child: RepaintBoundary(
        key: key,
        child: QrCodeTile(
          visibility: QrCodeVisibility.shown,
          payload: payload,
          size: size,
        ),
      ),
    );

void main() {
  for (final dark in [false, true]) {
    for (final payload in [
      waPayload,
      'DEMO-NOT-A-REAL-QR-${'0123456789' * 20}',
    ]) {
      testWidgets('draws black on white with a quiet zone of 4 modules, '
          '${dark ? 'dark' : 'light'}, ${payload.length} characters', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(400, 400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await pumpWa(tester, _tile(key, payload), dark: dark, scroll: false);
        expect(
          tester.getSize(find.byType(QrCodeTile)),
          const Size(kQrTileSize, kQrTileSize),
        );
        final matrix = QrMatrix.encode(payload)!;
        final module = kQrTileSize / (matrix.count + 2 * kQrQuietModules);
        final pixels = await _pixels(tester, key);
        expect(pixels.width, kQrTileSize.round());
        // The quiet zone is white all around, past the 1 pt outline. The
        // zone is 4 modules wide: the band up to just before the first
        // module column of the code.
        final band = (kQrQuietModules * module).floor() - 1;
        for (var i = 2; i < band; i++) {
          for (final j in [60, 120, 180]) {
            expect(pixels.at(i, j), (255, 255, 255), reason: 'left $i,$j');
            expect(pixels.at(j, i), (255, 255, 255), reason: 'top $j,$i');
            final far = pixels.width - 1 - i;
            expect(pixels.at(far, j), (255, 255, 255), reason: 'right');
            expect(pixels.at(j, far), (255, 255, 255), reason: 'bottom');
          }
        }
        // The finder pattern's corner module is black.
        final inside = (kQrQuietModules * module + module / 2).round();
        expect(pixels.at(inside, inside), (0, 0, 0));
        // And the code has both colours: it is not a blank square.
        var black = 0;
        for (var y = 0; y < pixels.height; y++) {
          for (var x = 0; x < pixels.width; x++) {
            if (pixels.at(x, y) == (0, 0, 0)) black++;
          }
        }
        expect(black, greaterThan(500));
      });
    }
  }

  testWidgets('the tile has a 1 pt outline in the theme\'s divider colour, in '
      'both themes', (tester) async {
    for (final dark in [false, true]) {
      await pumpWa(
        tester,
        QrCodeTile(visibility: QrCodeVisibility.shown, payload: waPayload),
        dark: dark,
      );
      final outlined = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.foregroundDecoration is BoxDecoration)
          .map((c) => c.foregroundDecoration! as BoxDecoration)
          .single;
      final scheme = Theme.of(tester.element(find.byType(QrCodeTile)))
          .colorScheme;
      expect(outlined.border, Border.all(color: scheme.outline));
    }
  });

  testWidgets('a rotated payload repaints the code at once', (tester) async {
    await pumpWa(
      tester,
      QrCodeTile(visibility: QrCodeVisibility.shown, payload: waPayload),
    );
    CustomPainter painter() => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(QrCodePattern),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    final before = painter();
    await pumpWa(
      tester,
      QrCodeTile(
        visibility: QrCodeVisibility.shown,
        payload: '$waPayload-rotated',
      ),
    );
    expect(painter().shouldRepaint(before), isTrue);
    // The same payload again is not redrawn.
    final rotated = painter();
    await pumpWa(
      tester,
      QrCodeTile(
        visibility: QrCodeVisibility.shown,
        payload: '$waPayload-rotated',
      ),
    );
    expect(
      identical(painter(), rotated) || !painter().shouldRepaint(rotated),
      isTrue,
    );
  });

  group('the payload is a credential', () {
    testWidgets('it is in no label, tooltip, key, description or toString', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final tile = QrCodeTile(
        visibility: QrCodeVisibility.shown,
        payload: waPayload,
      );
      final card = QrCodeCard(
        visibility: QrCodeVisibility.shown,
        payload: waPayload,
        timeLeft: const Duration(minutes: 8, seconds: 42),
      );
      await pumpWa(tester, card);
      final everything = [
        tile.toString(),
        tile.toStringDeep(),
        card.toString(),
        card.toStringDeep(),
        tester.element(find.byType(QrCodeCard)).toStringDeep(),
        WidgetsBinding.instance.rootElement!.toStringDeep(),
        WidgetsBinding.instance.rootElement!.renderObject!.toStringDeep(),
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!
            .toStringDeep(),
        QrMatrix.encode(waPayload).toString(),
      ].join('\n');
      expect(everything, isNot(contains('DEMO-NOT-A-REAL-QR')));
      expect(everything, isNot(contains('invented-segment')));
      expect(find.byType(Tooltip), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key.toString().contains('DEMO') ||
              w.key.toString().contains('invented'),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.byType(QrCodeTile)).label,
        'QR code to scan with WhatsApp',
      );
      handle.dispose();
    });

    testWidgets('there is no Copy, Share or selectable text', (tester) async {
      await pumpWa(
        tester,
        QrCodeCard(visibility: QrCodeVisibility.shown, payload: waPayload),
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.textContaining('Copy'), findsNothing);
      expect(find.textContaining('Share'), findsNothing);
    });

    for (final visibility in [
      QrCodeVisibility.hidden,
      QrCodeVisibility.needsTap,
    ]) {
      testWidgets('$visibility draws no code and does not even hold the '
          'payload', (tester) async {
        final handle = tester.ensureSemantics();
        var shown = 0;
        final tile = QrCodeTile(
          visibility: visibility,
          payload: waPayload,
          onShow: () => shown++,
        );
        expect(tile.payload, isNull);
        await pumpWa(tester, tile);
        expect(find.byType(QrCodePattern), findsNothing);
        expect(
          find
              .byType(CustomPaint)
              .evaluate()
              .where(
                (e) =>
                    (e.widget as CustomPaint).painter.runtimeType.toString() ==
                    '_QrPainter',
              ),
          isEmpty,
        );
        expect(find.text('Hidden'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Hidden')).label,
          contains('QR code hidden'),
        );
        if (visibility == QrCodeVisibility.needsTap) {
          expect(
            find.text('Shows again when the app is unlocked and in front.'),
            findsNothing,
          );
          await tester.tap(find.text('Show QR code'));
          expect(shown, 1);
        } else {
          expect(
            find.text('Shows again when the app is unlocked and in front.'),
            findsOneWidget,
          );
          expect(find.text('Show QR code'), findsNothing);
        }
        handle.dispose();
      });
    }

    testWidgets('the hidden tile keeps the shown tile\'s footprint', (
      tester,
    ) async {
      await pumpWa(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: QrCodeTile(visibility: QrCodeVisibility.hidden),
        ),
        scroll: false,
      );
      expect(tester.getSize(find.byType(QrCodeTile)), const Size(240, 240));
    });
  });

  testWidgets('a payload too long for any code says so instead of drawing', (
    tester,
  ) async {
    await pumpWa(
      tester,
      QrCodeTile(
        visibility: QrCodeVisibility.shown,
        payload: 'DEMO-NOT-A-REAL-QR-' * 400,
      ),
    );
    expect(find.byType(QrCodePattern), findsNothing);
    expect(find.text("Couldn't draw the code."), findsOneWidget);
  });

  group('the status lines', () {
    testWidgets('waiting and the countdown', (tester) async {
      await pumpWa(
        tester,
        const QrScanStatus(timeLeft: Duration(minutes: 8, seconds: 42)),
      );
      expect(find.text('Waiting for a scan'), findsOneWidget);
      expect(find.text('Setup closes in 8:42'), findsOneWidget);
      expect(find.byType(AppBanner), findsNothing);
    });

    testWidgets('the last minute is a warning with the time in its title', (
      tester,
    ) async {
      await pumpWa(tester, const QrScanStatus(timeLeft: Duration(seconds: 42)));
      final banner = tester.widget<AppBanner>(find.byType(AppBanner));
      expect(banner.tone, AppBannerTone.warning);
      expect(banner.title, 'Setup closes in 0:42.');
      expect(banner.detail, 'Scan now, or start again after it closes.');
      // The countdown is not shown twice.
      expect(find.text('Setup closes in 0:42'), findsNothing);
    });

    testWidgets('no countdown while the deadline is unknown', (tester) async {
      await pumpWa(tester, const QrScanStatus());
      expect(find.textContaining('Setup closes'), findsNothing);
    });

    testWidgets('a screen reader hears 60, 30 and 10 seconds, never every '
        'second', (tester) async {
      final heard = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final data = (message as Map)['data'] as Map?;
            if (data != null) heard.add(data['message'] as String);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      for (var seconds = 75; seconds >= 0; seconds--) {
        await pumpWa(
          tester,
          QrScanStatus(timeLeft: Duration(seconds: seconds)),
        );
      }
      expect(heard, [
        'Setup closes in 60 seconds.',
        'Setup closes in 30 seconds.',
        'Setup closes in 10 seconds.',
      ]);
    });
  });
}
