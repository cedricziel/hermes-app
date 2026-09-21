import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:widgetbook/widgetbook.dart';

import '../widgetbook/directories.dart';
import '../widgetbook/environment.dart';

Iterable<(String, WidgetbookUseCase)> _useCases(
  Iterable<WidgetbookNode> nodes, [
  String prefix = '',
]) sync* {
  for (final node in nodes) {
    if (node is WidgetbookUseCase) {
      yield ('$prefix${node.name}', node);
    } else {
      yield* _useCases(node.children ?? const [], '$prefix${node.name} / ');
    }
  }
}

/// Every use case of the component catalog (`widgetbook/`) must build in each
/// theme and viewport it offers, without an exception or an
/// overflow. The catalog is not part of the app, so nothing else would notice
/// a use case that broke.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final (label, useCase) in _useCases(directories)) {
    for (final MapEntry(key: mode, value: theme) in themes.entries) {
      for (final viewport in [phone, desktop]) {
        testWidgets('$label builds: $mode, ${viewport.name}', (tester) async {
          tester.view
            ..physicalSize = viewport.size * viewport.pixelRatio
            ..devicePixelRatio = viewport.pixelRatio;
          addTearDown(tester.view.reset);
          debugDefaultTargetPlatformOverride = viewport.platform;
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(body: Builder(builder: useCase.builder)),
              ),
            );
            // The first frame builds what a `Hosted` value was waiting for and
            // the screen then starts its own load, so give it a second frame.
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));

            expect(tester.takeException(), isNull);

            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 10));
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  }

  test('the catalog lists at least one use case', () {
    expect(_useCases(directories), isNotEmpty);
  });
}
