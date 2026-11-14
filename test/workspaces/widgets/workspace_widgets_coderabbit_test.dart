import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';

import '../../files/widgets/files_widget_harness.dart';

const _demo = '/home/me/code/demo';

void main() {
  group('elidePathMiddle with very short paths', () {
    for (final path in ['/', '~', '/a', 'ab']) {
      test('"$path" that does not fit is returned as it is', () {
        expect(elidePathMiddle(path, (_) => false), path);
      });
    }

    for (final scale in [1.0, 3.0]) {
      testWidgets('a two-character path in a 3 pt column at ${scale}x', (
        tester,
      ) async {
        for (final path in ['/', '~', '/a']) {
          await pumpFiles(
            tester,
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 3, child: PathCutText(path)),
            ),
            textScale: scale,
          );
          expect(tester.takeException(), isNull, reason: path);
        }
      });
    }
  });

  testWidgets('a shortened path is read in full, with its suffix', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const path = '/srv/workspaces/research-group-north/analysis-scripts';
    await pumpFiles(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 120,
          child: PathCutText(path, suffix: ' · on your server'),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.byType(Text).first).textSpan!.toPlainText(),
      contains('…'),
    );
    expect(find.bySemanticsLabel('$path · on your server'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'a selectable path on one line can be selected, without its suffix',
    (tester) async {
      await pumpFiles(
        tester,
        const ServerPathText.text(_demo, selectable: true),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.textContaining(_demo, findRichText: true), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byWidgetPredicate(
            (w) => w is SelectionContainer && w.registrar == null,
          ),
        ),
        findsWidgets,
        reason: 'the suffix sits in a disabled selection container',
      );
    },
  );

  testWidgets('the field keeps its focus and text as suggestions come and go', (
    tester,
  ) async {
    final state = ValueNotifier<List<PathEntrySuggestion>>(const []);
    // The host keeps the text the field reports.
    var typed = '';
    await pumpFiles(
      tester,
      ValueListenableBuilder(
        valueListenable: state,
        builder: (_, suggestions, _) => PathEntryView(
          text: typed,
          suggestions: suggestions,
          onChanged: (value) => typed = value,
        ),
      ),
      size: const Size(500, 1200),
    );
    await tester.enterText(
      find.byKey(const Key('path-entry-field')),
      '/home/me/co',
    );
    await tester.pump();
    EditableTextState editable() =>
        tester.state<EditableTextState>(find.byType(EditableText));
    final focus = editable().widget.focusNode;
    expect(focus.hasFocus, isTrue);
    final selection = editable().widget.controller.selection;

    state.value = const [
      PathEntrySuggestion(name: 'code', path: '/home/me/code/'),
    ];
    await tester.pump();
    expect(editable().widget.focusNode.hasFocus, isTrue);
    expect(editable().widget.controller.text, '/home/me/co');
    expect(editable().widget.controller.selection, selection);

    state.value = const [];
    await tester.pump();
    expect(editable().widget.focusNode.hasFocus, isTrue);
    expect(editable().widget.controller.text, '/home/me/co');
    expect(editable().widget.controller.selection, selection);
  });

  group('Change folder… semantics', () {
    testWidgets('a semantic tap triggers onChange', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpFiles(
        tester,
        WorkingDirectoryDetails(
          folderName: 'api',
          path: _demo,
          onChange: () => taps++,
        ),
      );
      final node = tester.getSemantics(
        find.byKey(const Key('working-directory-change')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Change folder…'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('disabled, it names its reason and offers no tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpFiles(
        tester,
        WorkingDirectoryDetails(
          folderName: 'api',
          path: _demo,
          replying: true,
          onChange: () => fail('disabled'),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(const Key('working-directory-change')))
          .getSemanticsData();
      expect(data.label, contains('Wait for the reply to finish.'));
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('without a callback there is no tap either', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFiles(
        tester,
        const WorkingDirectoryDetails(folderName: 'api', path: _demo),
      );
      final data = tester
          .getSemantics(find.byKey(const Key('working-directory-change')))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });
}
