import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_editor.dart';

import 'soul_widget_host.dart';

SoulEditor _editor(
  SoulTextController controller, {
  bool readOnly = false,
  bool fileExists = true,
  ValueChanged<String>? onChanged,
}) => SoulEditor(
  controller: controller,
  profile: 'work',
  readOnly: readOnly,
  fileExists: fileExists,
  onChanged: onChanged,
);

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('hardened input', () {
    testWidgets('autocorrect, suggestions, smart punctuation, autofill, '
        'keyboard learning, spell check and restoration are off', (
      tester,
    ) async {
      final controller = SoulTextController(text: 'x');
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      final field = _field(tester);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.smartDashesType, SmartDashesType.disabled);
      expect(field.smartQuotesType, SmartQuotesType.disabled);
      expect(field.autofillHints, isNull);
      expect(field.spellCheckConfiguration?.spellCheckEnabled, isFalse);
      expect(field.restorationId, isNull);
      expect(field.keyboardType, TextInputType.multiline);
    });

    testWidgets('has no length limit', (tester) async {
      final controller = SoulTextController(text: 'x');
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      expect(_field(tester).maxLength, isNull);
      expect(_field(tester).inputFormatters, isNull);
    });
  });

  group('read-only', () {
    testWidgets('the field is read-only and transparent; editable is filled', (
      tester,
    ) async {
      final controller = SoulTextController(text: 'x');
      addTearDown(controller.dispose);
      Color? fill() {
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color;
      }

      await pumpSoul(tester, _editor(controller));
      expect(_field(tester).readOnly, isFalse);
      final scheme = Theme.of(tester.element(find.byType(TextField)))
          .colorScheme;
      expect(fill(), scheme.surfaceContainerHighest);

      await pumpSoul(tester, _editor(controller, readOnly: true));
      expect(_field(tester).readOnly, isTrue);
      expect(fill(), Colors.transparent);
    });

    testWidgets('typing is ignored while read-only', (tester) async {
      final controller = SoulTextController(text: 'x');
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpSoul(
        tester,
        _editor(controller, readOnly: true, onChanged: changes.add),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      // A read-only field opens no keyboard, so nothing can change the text.
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(controller.text, 'x');
      expect(changes, isEmpty);

      await pumpSoul(tester, _editor(controller, onChanged: changes.add));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);
    });
  });

  group('count and note', () {
    Future<void> showText(WidgetTester tester, int length) async {
      final controller = SoulTextController(text: 'a' * length);
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
    }

    testWidgets('counts with the locale grouping', (tester) async {
      await showText(tester, 1240);
      expect(find.text('1,240 characters'), findsOneWidget);
    });

    testWidgets('German groups with a dot', (tester) async {
      final controller = SoulTextController(text: 'a' * 1240);
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller), locale: const Locale('de'));
      expect(find.text('1.240 Zeichen'), findsOneWidget);
    });

    testWidgets('1 character and 0 characters', (tester) async {
      await showText(tester, 1);
      expect(find.text('1 character'), findsOneWidget);
      await showText(tester, 0);
      expect(find.text('0 characters'), findsOneWidget);
    });

    testWidgets('the note appears at 20,000 characters and not before', (
      tester,
    ) async {
      const note =
          "Hermes may shorten text this long when it builds a chat. The limit depends on your server's settings.";
      await showText(tester, kSoulLongNoteLength - 1);
      expect(find.text(note), findsNothing);
      await showText(tester, kSoulLongNoteLength);
      expect(find.text(note), findsOneWidget);
      await showText(tester, kSoulLongNoteLength + 5000);
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('never blocks: beyond 20,000 it stays editable', (
      tester,
    ) async {
      final controller = SoulTextController(text: 'a' * 30000);
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpSoul(tester, _editor(controller, onChanged: changes.add));
      expect(_field(tester).readOnly, isFalse);
      expect(_field(tester).enabled, isNot(false));
      await tester.enterText(find.byType(TextField), '${controller.text}b');
      await tester.pump();
      expect(changes.single.length, 30001);
    });

    testWidgets('an empty file and a missing file say different things', (
      tester,
    ) async {
      final controller = SoulTextController();
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      expect(
        find.text('Hermes uses its default personality while this is empty.'),
        findsOneWidget,
      );
      expect(find.text('No personality set yet.'), findsNothing);

      await pumpSoul(tester, _editor(controller, fileExists: false));
      expect(find.text('No personality set yet.'), findsOneWidget);
      expect(
        find.text('Hermes uses its default personality while this is empty.'),
        findsNothing,
      );
    });

    testWidgets(
      'clearing the text shows the default-personality line at once',
      (tester) async {
        final controller = SoulTextController(text: 'hello');
        addTearDown(controller.dispose);
        await pumpSoul(tester, _editor(controller));
        expect(
          find.text('Hermes uses its default personality while this is empty.'),
          findsNothing,
        );
        controller.text = '';
        await tester.pump();
        expect(
          find.text('Hermes uses its default personality while this is empty.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the count is announced after typing pauses, not per key', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = SoulTextController();
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      expect(find.bySemanticsLabel('0 characters'), findsOneWidget);

      controller.text = 'abc';
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3 characters'), findsOneWidget);
      expect(find.bySemanticsLabel('0 characters'), findsOneWidget);
      expect(find.bySemanticsLabel('3 characters'), findsNothing);

      controller.text = 'abcd';
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('4 characters'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the field has a label naming the profile', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = SoulTextController(text: 'x');
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      expect(
        find.bySemanticsLabel(RegExp('Personality text for work')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('character count', () {
    test('counts code points and recounts only when the text changed', () {
      final counter = SoulCharacterCount();
      const text = 'a\u{1F600}b';
      expect(counter.of(text), 3);
      expect(counter.of(text), 3);
      expect(counter.of(String.fromCharCodes(text.codeUnits)), 3);
      expect(counter.computed, 1);
      expect(counter.of('abcd'), 4);
      expect(counter.computed, 2);
    });

    testWidgets('a caret move does not recount; typing does', (tester) async {
      final controller = SoulTextController(text: 'hello');
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      final state = tester.state<State<SoulEditor>>(find.byType(SoulEditor));
      int computed() => (state as SoulEditorCountProbe).debugCountComputed;
      final before = computed();
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      expect(computed(), before);
      controller.text = 'hello!';
      await tester.pump();
      expect(find.text('6 characters'), findsOneWidget);
      expect(computed(), before + 1);
    });
  });

  group('control and bidi characters', () {
    const text = 'a\u202Eb\u200Bc\u0007d\ne\tf';

    testWidgets(
      'are drawn as marks of the same length; the text is untouched',
      (tester) async {
        final controller = SoulTextController(text: text);
        addTearDown(controller.dispose);
        late BuildContext context;
        await pumpSoul(
          tester,
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        );
        final span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );
        final shown = span.toPlainText(includeSemanticsLabels: false);
        expect(shown.length, text.length);
        expect(shown.contains('\u202E'), isFalse);
        expect(shown.contains('\u200B'), isFalse);
        expect(shown.contains('\u0007'), isFalse);
        expect(shown, 'a�b�c␇d\ne\tf');
        // A line break and a tab are drawn as they are.
        expect(shown.contains('\n'), isTrue);
        expect(shown.contains('\t'), isTrue);
        expect(controller.text, text);
      },
    );

    testWidgets('plain text is left to the default rendering', (tester) async {
      final controller = SoulTextController(text: 'plain\ntext');
      addTearDown(controller.dispose);
      late BuildContext context;
      await pumpSoul(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      expect(span.toPlainText(), 'plain\ntext');
      expect(SoulTextController.hasHidden('plain\ntext'), isFalse);
    });

    testWidgets(
      'a tag character is two marks, one per unit, and offsets hold',
      (tester) async {
        // U+E0041 is the pair U+DB40 U+DC41: two units, drawn as two marks.
        const hiddenTag = 'a\u{E0041}b';
        expect(hiddenTag.length, 4);
        final controller = SoulTextController(text: hiddenTag);
        addTearDown(controller.dispose);
        expect(SoulTextController.hasHidden(hiddenTag), isTrue);
        expect(SoulTextController.hiddenUnits(hiddenTag), [
          false,
          true,
          true,
          false,
        ]);
        late BuildContext context;
        await pumpSoul(
          tester,
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        );
        final span = controller.buildTextSpan(
          context: context,
          style: const TextStyle(),
          withComposing: false,
        );
        final shown = span.toPlainText(includeSemanticsLabels: false);
        expect(shown, 'a��b');
        expect(shown.length, hiddenTag.length);
        expect(controller.text, hiddenTag);
      },
    );

    test('an ordinary emoji is not marked; a lone surrogate is', () {
      expect(SoulTextController.hasHidden('a\u{1F600}b'), isFalse);
      expect(SoulTextController.hasHidden('a\uD800b'), isTrue);
      expect(SoulTextController.hasHidden('a\uD800'), isTrue);
      expect(SoulTextController.hasHidden('a\uDC00b'), isTrue);
      expect(SoulTextController.hasHidden('a\u00ADb'), isTrue);
      expect(SoulTextController.hiddenUnits('a\uD800b\uDC00'), [
        false,
        true,
        false,
        true,
      ]);
    });

    testWidgets('runs split at the composing range and keep their text', (
      tester,
    ) async {
      const mixed = 'ab\u202Ecd\u0007\u0007ef';
      final controller = SoulTextController(text: mixed);
      addTearDown(controller.dispose);
      controller.value = controller.value.copyWith(
        composing: const TextRange(start: 1, end: 4),
      );
      late BuildContext context;
      await pumpSoul(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );
      final runs = [for (final c in span.children!) (c as TextSpan).text];
      expect(runs, ['a', 'b', '�', 'c', 'd', '␇␇', 'ef']);
    });
  });

  group('the caret and a hidden pair', () {
    const tag = 'a\u{E0041}b';

    List<int> units(String t) => t.codeUnits;

    bool hasLoneSurrogate(String t) {
      final u = t.codeUnits;
      for (var i = 0; i < u.length; i++) {
        final high = u[i] >= 0xD800 && u[i] <= 0xDBFF;
        final low = u[i] >= 0xDC00 && u[i] <= 0xDFFF;
        if (high &&
            !(i + 1 < u.length && u[i + 1] >= 0xDC00 && u[i + 1] <= 0xDFFF)) {
          return true;
        }
        if (low && !(i > 0 && u[i - 1] >= 0xD800 && u[i - 1] <= 0xDBFF)) {
          return true;
        }
        if (high) i++;
      }
      return false;
    }

    test('a caret set between the halves goes to the end of the pair', () {
      final controller = SoulTextController(text: tag);
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 2);
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
      controller.selection = const TextSelection.collapsed(offset: 1);
      expect(controller.selection.baseOffset, 1);
      controller.selection = const TextSelection.collapsed(offset: 3);
      expect(controller.selection.baseOffset, 3);
      expect(controller.text, tag);
    });

    test('a range grows to cover the pair and keeps its direction', () {
      final controller = SoulTextController(text: tag);
      addTearDown(controller.dispose);
      // 'a' + pair + 'b': units 0..4.
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 4,
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      // Backwards: the base is the upper end.
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 0,
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 3, extentOffset: 0),
      );
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 2,
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 1),
      );
      // Both ends in the same pair: it ends up selecting the pair.
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 2,
      );
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });

    test('the composing range is moved out of a pair, text untouched', () {
      final controller = SoulTextController(text: tag);
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: tag,
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange(start: 2, end: 4),
      );
      expect(controller.value.composing, const TextRange(start: 1, end: 4));
      expect(controller.text, tag);
    });

    testWidgets('a tap between the two marks never stops mid-pair, and a '
        'paste there keeps the pair whole', (tester) async {
      final controller = SoulTextController(text: tag);
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final rect = editable.getLocalRectForCaret(const TextPosition(offset: 2));
      await tester.tapAt(editable.localToGlobal(rect.center));
      await tester.pump(const Duration(milliseconds: 400));
      final caret = controller.selection;
      expect(caret.isCollapsed, isTrue);
      expect(caret.baseOffset, anyOf(1, 3), reason: 'never offset 2');

      final at = caret.baseOffset;
      final pasted = controller.text.replaceRange(at, at, 'Z');
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: pasted,
          selection: TextSelection.collapsed(offset: at + 1),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(units(controller.text), contains(0xDB40));
      final i = units(controller.text).indexOf(0xDB40);
      expect(units(controller.text)[i + 1], 0xDC41);
      expect(hasLoneSurrogate(controller.text), isFalse);
      expect(controller.text.replaceAll('Z', ''), tag);
    });

    testWidgets('text that already holds lone surrogates lays out', (
      tester,
    ) async {
      const lone = 'a\uD800b\uDC00c\uD800';
      final controller = SoulTextController(text: lone);
      addTearDown(controller.dispose);
      await pumpSoul(tester, _editor(controller));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.text, lone);
      late BuildContext context;
      await pumpSoul(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      final shown = span.toPlainText(includeSemanticsLabels: false);
      expect(shown, 'a�b�c�');
      expect(hasLoneSurrogate(shown), isFalse);
    });

    testWidgets(
      'arrows, Backspace and Delete treat the pair as one (a line break keeps)',
      (tester) async {
        final controller = SoulTextController(text: 'a\n\u{E0041}b');
        addTearDown(controller.dispose);
        await pumpSoul(tester, _editor(controller));
        await tester.showKeyboard(find.byType(EditableText));
        controller.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.selection.baseOffset, 4);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selection.baseOffset, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pump();
        expect(controller.text, 'a\nb');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
