import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/soft_keyboard.dart';

/// The field's text after a reset: one zero-width space the caret sits after,
/// which gives a backspace something to delete.
const _rest = '​';

void main() {
  late SoftKeyboard keyboard;
  late List<String> sent;
  late int closed;

  setUp(() {
    sent = [];
    closed = 0;
    keyboard = SoftKeyboard(
      onText: (text) => sent.add('text $text'),
      onBackspace: () => sent.add('backspace'),
      onReturn: () => sent.add('return'),
      onClosed: () => closed++,
    );
  });

  tearDown(() => keyboard.hide());

  TextEditingDeltaInsertion insert(
    String text, {
    String before = _rest,
    TextRange composing = TextRange.empty,
  }) => TextEditingDeltaInsertion(
    oldText: before,
    textInserted: text,
    insertionOffset: before.length,
    selection: TextSelection.collapsed(offset: before.length + text.length),
    composing: composing,
  );

  group('the field', () {
    testWidgets('turns autocorrect, suggestions, learning and smart '
        'punctuation off and is a password keyboard', (tester) async {
      keyboard.show();

      final args = tester.testTextInput.setClientArgs!;
      expect(args['autocorrect'], isFalse);
      expect(args['enableSuggestions'], isFalse);
      expect(args['enableIMEPersonalizedLearning'], isFalse);
      expect(args['smartDashesType'], '${SmartDashesType.disabled.index}');
      expect(args['smartQuotesType'], '${SmartQuotesType.disabled.index}');
      expect(args['enableDeltaModel'], isTrue);
      expect(
        (args['inputType'] as Map)['name'],
        'TextInputType.visiblePassword',
      );
      expect(args['textCapitalization'], 'TextCapitalization.none');
      expect(args['obscureText'], isFalse);
      expect(args.containsKey('autofill'), isFalse);
    });

    testWidgets('shows the keyboard, and hide takes it away', (tester) async {
      keyboard.show();
      expect(keyboard.visible, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      keyboard.hide();

      expect(keyboard.visible, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('showing again brings back a keyboard the system dismissed', (
      tester,
    ) async {
      keyboard.show();
      tester.testTextInput.hide();
      expect(tester.testTextInput.isVisible, isFalse);

      keyboard.show();

      expect(tester.testTextInput.isVisible, isTrue);
      expect(keyboard.visible, isTrue);
    });

    testWidgets('a connection the system closes is reported once, and the '
        'keyboard is not visible', (tester) async {
      keyboard.show();

      tester.testTextInput.closeConnection();

      expect(closed, 1);
      expect(keyboard.visible, isFalse);
    });

    testWidgets('hiding forgets text that was still being composed', (
      tester,
    ) async {
      keyboard.show();
      keyboard.updateEditingValueWithDeltas([
        insert('ab', composing: const TextRange(start: 1, end: 3)),
      ]);
      expect(keyboard.currentTextEditingValue!.composing.isCollapsed, isFalse);

      keyboard.hide();

      expect(keyboard.currentTextEditingValue!.text, _rest);
      expect(keyboard.currentTextEditingValue!.composing.isCollapsed, isTrue);
      expect(closed, 0);
    });

    testWidgets('showing twice keeps one connection', (tester) async {
      keyboard.show();
      keyboard.show();

      expect(keyboard.visible, isTrue);
    });

    testWidgets('starts with the one character to delete', (tester) async {
      keyboard.show();

      expect(tester.testTextInput.editingState!['text'], _rest);
      expect(tester.testTextInput.editingState!['selectionBase'], 1);
    });
  });

  group('typing', () {
    testWidgets('committed text is sent and the field is reset', (
      tester,
    ) async {
      keyboard.show();

      keyboard.updateEditingValueWithDeltas([insert('a')]);

      expect(sent, ['text a']);
      expect(keyboard.currentTextEditingValue!.text, _rest);
      expect(tester.testTextInput.editingState!['text'], _rest);
    });

    testWidgets('no typed text accumulates in the field', (tester) async {
      keyboard.show();

      for (final character in ['p', 'a', 's', 's']) {
        keyboard.updateEditingValueWithDeltas([insert(character)]);
      }

      expect(sent, ['text p', 'text a', 'text s', 'text s']);
      expect(keyboard.currentTextEditingValue!.text, _rest);
    });

    testWidgets('a pasted run is sent as one piece', (tester) async {
      keyboard.show();

      keyboard.updateEditingValueWithDeltas([insert('481 516')]);

      expect(sent, ['text 481 516']);
    });

    testWidgets('a newline is Return, between the text around it', (
      tester,
    ) async {
      keyboard.show();

      keyboard.updateEditingValueWithDeltas([insert('a\nb')]);

      expect(sent, ['text a', 'return', 'text b']);
    });

    testWidgets('the keyboard\'s action key is Return', (tester) async {
      keyboard.show();

      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(sent, ['return']);
    });

    testWidgets('deleting the character is a BackSpace and the field is '
        'restored', (tester) async {
      keyboard.show();

      keyboard.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: _rest,
          deletedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
      ]);

      expect(sent, ['backspace']);
      expect(keyboard.currentTextEditingValue!.text, _rest);
    });
  });

  group('composing', () {
    testWidgets('text still being composed is held until it is committed', (
      tester,
    ) async {
      keyboard.show();

      keyboard.updateEditingValueWithDeltas([
        insert('h', composing: const TextRange(start: 1, end: 2)),
      ]);
      keyboard.updateEditingValueWithDeltas([
        insert(
          'e',
          before: '${_rest}h',
          composing: const TextRange(start: 1, end: 3),
        ),
      ]);
      expect(sent, isEmpty);

      keyboard.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: '${_rest}he',
          replacementText: 'hello',
          replacedRange: TextRange(start: 1, end: 3),
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        ),
      ]);

      expect(sent, ['text hello']);
      expect(keyboard.currentTextEditingValue!.text, _rest);
    });

    testWidgets('a composition that ends as it began sends what it holds', (
      tester,
    ) async {
      keyboard.show();
      keyboard.updateEditingValueWithDeltas([
        insert('ok', composing: const TextRange(start: 1, end: 3)),
      ]);

      keyboard.updateEditingValueWithDeltas([
        const TextEditingDeltaNonTextUpdate(
          oldText: '${_rest}ok',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        ),
      ]);

      expect(sent, ['text ok']);
    });

    testWidgets('deleting inside a composition is not a BackSpace and a '
        'composition deleted whole sends nothing', (tester) async {
      keyboard.show();
      keyboard.updateEditingValueWithDeltas([
        insert('h', composing: const TextRange(start: 1, end: 2)),
      ]);

      keyboard.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: '${_rest}h',
          deletedRange: TextRange(start: 1, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      ]);

      expect(sent, isEmpty);
    });
  });

  group('a keyboard that reports whole values, not deltas', () {
    testWidgets('typed text is found by comparing with what the field held', (
      tester,
    ) async {
      keyboard.show();

      tester.testTextInput.enterText('${_rest}481');

      expect(sent, ['text 481']);
      expect(keyboard.currentTextEditingValue!.text, _rest);
    });

    testWidgets('a deleted character is a BackSpace', (tester) async {
      keyboard.show();

      tester.testTextInput.enterText('');

      expect(sent, ['backspace']);
    });

    testWidgets('composing text is held until it is committed', (tester) async {
      keyboard.show();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '${_rest}he',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 1, end: 3),
        ),
      );
      expect(sent, isEmpty);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '${_rest}hello',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );

      expect(sent, ['text hello']);
    });
  });

  group('when it is gone', () {
    testWidgets('a delta after hide sends nothing', (tester) async {
      keyboard.show();
      keyboard.hide();

      keyboard.updateEditingValueWithDeltas([insert('a')]);

      expect(sent, isEmpty);
    });

    testWidgets('the system closing the connection hides it', (tester) async {
      keyboard.show();

      tester.testTextInput.closeConnection();
      await tester.pump();

      expect(keyboard.visible, isFalse);
    });
  });
}
