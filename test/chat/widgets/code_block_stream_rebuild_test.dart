import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

import '../../support/rebuild_probe.dart';

/// The s2b benchmark's shape: a reply of empty fences between short lines,
/// growing by a few characters per delta. `AppMarkdownTheme` hands the markdown
/// package new theme data on every build, so every block is created again each
/// delta; a block whose config is unchanged must not rebuild its subtree.
String _reply(int fences) =>
    [for (var i = 0; i < fences; i++) 'Block number $i.\n\n```\n```\n\n']
        .join();

void main() {
  testWidgets('a streamed delta rebuilds no code block whose config is equal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 100000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const fences = 150;
    var text = _reply(fences);
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        builder: (_, child) => AppThemeScopes(child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return SingleChildScrollView(
                child: AppMarkdownTheme(child: BoundedMarkdown(text)),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(HermesCodeBlock), findsNWidgets(fences));

    // The first frames settle the copy buttons' focus widgets once.
    set(() => text += ' Next');
    await tester.pump();
    await tester.pump();

    // Words of the next sentence arrive; nothing in the blocks changes.
    final counts = <int>[];
    final roots = <int>[];
    for (final delta in ['Next', ' sentence', ' of', ' prose']) {
      final c = await countRebuildsBelow<HermesCodeBlock>(() async {
        set(() => text += delta);
        await tester.pump();
      });
      counts.add(c.inside);
      roots.add(c.roots);
    }
    // The blocks are still created and visited (the cost the memo leaves),
    // but their subtrees are not rebuilt.
    expect(roots.every((r) => r >= fences), isTrue, reason: '$roots');
    expect(counts, everyElement(0), reason: 'subtree rebuilds per delta');
  });
}
