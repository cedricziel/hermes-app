import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:widgetbook/widgetbook.dart';

import '../widgetbook/directories.dart';
import '../widgetbook/environment.dart';
import '../widgetbook/main.dart';

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

/// The link that opens [useCase] in the catalog with [theme] and [viewport]
/// picked in the addons panel and the side panels hidden.
String _link(WidgetbookUseCase useCase, String theme, ViewportData viewport) {
  return Uri(
    path: '/',
    queryParameters: {
      'path': useCase.path,
      'theme': FieldCodec.encodeQueryGroup({'name': theme}),
      'viewport': FieldCodec.encodeQueryGroup({'name': viewport.name}),
      'preview': 'true',
    },
  ).toString();
}

/// Every use case of the component catalog (`widgetbook/`) must build in each
/// theme and viewport it offers, without an exception or an
/// overflow. The catalog is not part of the app, so nothing else would notice
/// a use case that broke.
///
/// Each use case is opened in the catalog itself (`HermesWidgetbook`), so it
/// sits under the app builder and the addons a person browsing the catalog
/// gets. A test that wraps the use case in an app of its own passes while
/// the catalog shows an error for it (#1354).
void main() {
  // Gives every node its parent, which a use case's link is built from.
  WidgetbookRoot(children: directories);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final (label, useCase) in _useCases(directories)) {
    for (final mode in themes.keys) {
      for (final viewport in [phone, desktop]) {
        testWidgets('$label builds: $mode, ${viewport.name}', (tester) async {
          tester.view
            ..physicalSize = viewport.size * viewport.pixelRatio
            ..devicePixelRatio = viewport.pixelRatio;
          addTearDown(tester.view.reset);
          debugDefaultTargetPlatformOverride = viewport.platform;
          try {
            await tester.pumpWidget(
              HermesWidgetbook(initialRoute: _link(useCase, mode, viewport)),
            );
            // The first frame builds what a `Hosted` value was waiting for and
            // the screen then starts its own load, so give it a second frame.
            await tester.pump(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));

            expect(tester.takeException(), isNull);
            // A link that names no use case shows the home page, not an error.
            expect(find.text(catalogHomeText), findsNothing);

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

  test('every use case has a link of its own', () {
    final paths = [
      for (final (_, useCase) in _useCases(directories)) useCase.path,
    ];
    expect(paths.toSet(), hasLength(paths.length));
  });
}
