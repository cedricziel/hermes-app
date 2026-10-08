import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where workflow tests write their screenshots. Override with
/// `WORKFLOW_SHOTS_DIR` to collect them somewhere else (CI uploads this).
final _shotsRoot =
    Platform.environment['WORKFLOW_SHOTS_DIR'] ?? 'build/workflow_screenshots';

/// Phone and desktop sizes the workflows run at, in logical pixels.
const phoneSize = Size(390, 844);
const desktopSize = Size(1280, 800);

Future<void>? _fontsLoaded;

/// Widget tests draw text in the Ahem test font (solid boxes) and icons as
/// empty squares. Load the real Roboto and Material Icons from the Flutter
/// SDK so a screenshot shows what a user would see.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? '$root/bin/cache'
      : File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final fonts = Directory('$cache/artifacts/material_fonts');
  Future<ByteData> read(String name) async {
    final bytes = await File('${fonts.path}/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final roboto = [
    for (final name in const [
      'Roboto-Light.ttf',
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Italic.ttf',
    ])
      read(name),
  ];
  // Roboto also stands in for the system fonts of the Apple platforms, which
  // text outside the app's own theme asks for.
  for (final family in const [
    'Roboto',
    '.AppleSystemUIFont',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    final loader = FontLoader(family);
    roboto.forEach(loader.addFont);
    await loader.load();
  }

  // The SDK ships no monospace font; the one gpt_markdown bundles for code
  // blocks stands in for the app's own `monospace` as well.
  final mono = await _readPackageAsset(
    'gpt_markdown',
    'lib/fonts/JetBrainsMono-Regular.ttf',
  );
  for (final family in const [
    'monospace',
    'packages/gpt_markdown/JetBrainsMono',
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(mono));
    await loader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();

  final cupertino = FontLoader(
    'packages/cupertino_icons/CupertinoIcons',
  )..addFont(_readPackageAsset('cupertino_icons', 'assets/CupertinoIcons.ttf'));
  await cupertino.load();
}

Future<ByteData> _readPackageAsset(String name, String path) async {
  final config = jsonDecode(
    await File('.dart_tool/package_config.json').readAsString(),
  ) as Map<String, dynamic>;
  final package = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == name);
  final rootUri = package['rootUri'] as String;
  final root = Uri.parse(rootUri.endsWith('/') ? rootUri : '$rootUri/');
  final bytes = await File.fromUri(
    Directory.current.uri
        .resolve('.dart_tool/package_config.json')
        .resolveUri(root)
        .resolve(path),
  ).readAsBytes();
  return ByteData.sublistView(bytes);
}

/// [theme] with Roboto set on the text the theme leaves without a family
/// (the AppBar title), which the test renderer would draw as solid boxes, and
/// on the text styles of an Apple platform, whose system font is not loaded.
ThemeData withScreenshotFont(ThemeData theme) {
  final title = theme.appBarTheme.titleTextStyle;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: title?.copyWith(fontFamily: 'Roboto'),
    ),
  );
}

/// Takes numbered PNGs of one workflow, `<flow>/01-name.png`, so a reader can
/// page through the run in order.
///
/// Mount the app under [frame] so there is a boundary to capture, then call
/// [capture] at each step of the flow.
class ScreenshotRecorder {
  ScreenshotRecorder(this.flow);

  final String flow;
  final _boundary = GlobalKey();
  var _count = 0;

  /// Loads the fonts (once per run) and sets the window to [size] logical
  /// pixels at [pixelRatio] for the rest of the test. Call it first in the
  /// test: fonts loaded in a `setUpAll` are ignored by the test renderer.
  Future<void> start(
    WidgetTester tester,
    Size size, {
    double pixelRatio = 1.0,
  }) async {
    // A tap that misses would otherwise leave the same screen in every image.
    WidgetController.hitTestWarningShouldBeFatal = true;
    await tester.runAsync(() => _fontsLoaded ??= _loadFonts());
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);
  }

  Widget frame(Widget child) => RepaintBoundary(key: _boundary, child: child);

  /// The PNG of what is on screen now, [pixelRatio] times its logical size.
  Future<Uint8List> render(
    WidgetTester tester, {
    required double pixelRatio,
  }) async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // Tests draw every elevation shadow as a hard black outline. Repaint the
    // whole tree once with real ones, then put the flag back for the test.
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    try {
      await tester.pump();
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return png!.buffer.asUint8List();
      }))!;
    } finally {
      debugDisableShadows = true;
    }
  }

  /// Writes what is on screen now to `<flow>/<step>-<name>.png`. A phone is
  /// saved at twice its logical size, a desktop window at its own.
  Future<void> capture(WidgetTester tester, String name) async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixelRatio = boundary.size.width > phoneSize.width * 2 ? 1.0 : 2.0;
    final png = await render(tester, pixelRatio: pixelRatio);
    _count++;
    final step = _count.toString().padLeft(2, '0');
    final file = File('$_shotsRoot/$flow/$step-$name.png');
    await tester.runAsync(() async {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png);
    });
  }
}
