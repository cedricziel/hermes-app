import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real Roboto, JetBrains Mono and the icon fonts, as the workflow
/// screenshots do (`test/support/screenshot_recorder.dart` keeps its loader
/// private). Widget tests otherwise draw every glyph in the Ahem test font,
/// whose layout costs far less than shaped text and would flatter the numbers.
Future<void> loadBenchmarkFonts() async {
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

  final mono = await _packageAsset(
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
}

Future<ByteData> _packageAsset(String name, String path) async {
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
