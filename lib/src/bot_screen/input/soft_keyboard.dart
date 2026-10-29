import 'package:flutter/services.dart';

/// The text the field holds between two keystrokes: a zero-width space with
/// the caret after it, so that a backspace has something to delete.
const _rest = '​';

const _restValue = TextEditingValue(
  text: _rest,
  selection: TextSelection.collapsed(offset: 1),
);

/// The system keyboard as a source of key presses for the screen.
///
/// It is not a text field: it attaches a text input connection of its own,
/// with no widget, and turns what the keyboard reports into three callbacks,
/// [onText] for committed text, [onBackspace] and [onReturn]. Text still being
/// composed (an IME's marked text) is held and sent only when it is committed,
/// so a half-typed word never reaches the screen. After each keystroke the
/// field is reset to a single zero-width space, so no typed text accumulates in
/// it, and the keyboard has nothing to learn from.
///
/// The connection asks for a password keyboard with autocorrect, suggestions,
/// keyboard learning, smart quotes and smart dashes off, no capitalization and
/// no autofill, so the system keyboard neither learns nor suggests what is
/// typed into the screen. Nothing typed is kept or logged here.
class SoftKeyboard with TextInputClient, DeltaTextInputClient {
  SoftKeyboard({
    required this.onText,
    required this.onBackspace,
    required this.onReturn,
    this.onClosed,
  });

  final void Function(String text) onText;
  final void Function() onBackspace;
  final void Function() onReturn;

  /// Told when the system closes the connection (not when [hide] does).
  final void Function()? onClosed;

  TextInputConnection? _connection;
  var _value = _restValue;

  /// Whether the keyboard is attached.
  bool get visible => _connection?.attached ?? false;

  /// Attaches and shows the keyboard.
  void show() {
    var connection = _connection;
    if (connection == null || !connection.attached) {
      _value = _restValue;
      connection = _connection = TextInput.attach(
        this,
        const TextInputConfiguration(
          inputType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          textCapitalization: TextCapitalization.none,
          inputAction: TextInputAction.done,
          enableDeltaModel: true,
          autofillConfiguration: AutofillConfiguration.disabled,
        ),
      );
      connection.setEditingState(_value);
    }
    connection.show();
  }

  /// Takes the keyboard away.
  void hide() {
    _connection?.close();
    _detach();
  }

  void _detach() {
    _connection = null;
    _value = _restValue;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    final connection = _connection;
    if (connection == null || !connection.attached) return;
    for (final delta in deltas) {
      _value = delta.apply(_value);
    }
    final composing = _value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    final text = _value.text;
    if (text.length < _rest.length) {
      onBackspace();
    } else {
      final typed = text.startsWith(_rest)
          ? text.substring(_rest.length)
          : text;
      _type(typed);
    }
    _value = _restValue;
    connection.setEditingState(_value);
  }

  /// Sends [typed], a line break being Return.
  void _type(String typed) {
    final lines = typed.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) onReturn();
      if (lines[i].isNotEmpty) onText(lines[i]);
    }
  }

  @override
  void performAction(TextInputAction action) => onReturn();

  @override
  void connectionClosed() {
    _detach();
    onClosed?.call();
  }

  /// A keyboard that reports the whole value instead of deltas (the model is
  /// asked for, but not every platform's keyboard gives it): what changed is
  /// found by comparing with what the field held.
  @override
  void updateEditingValue(TextEditingValue value) {
    final old = _value;
    final before = old.text, after = value.text;
    var start = 0;
    while (start < before.length &&
        start < after.length &&
        before[start] == after[start]) {
      start++;
    }
    var oldEnd = before.length, newEnd = after.length;
    while (oldEnd > start &&
        newEnd > start &&
        before[oldEnd - 1] == after[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    final added = after.substring(start, newEnd);
    final range = TextRange(start: start, end: oldEnd);
    updateEditingValueWithDeltas([
      if (before == after)
        TextEditingDeltaNonTextUpdate(
          oldText: before,
          selection: value.selection,
          composing: value.composing,
        )
      else if (range.isCollapsed)
        TextEditingDeltaInsertion(
          oldText: before,
          textInserted: added,
          insertionOffset: start,
          selection: value.selection,
          composing: value.composing,
        )
      else if (added.isEmpty)
        TextEditingDeltaDeletion(
          oldText: before,
          deletedRange: range,
          selection: value.selection,
          composing: value.composing,
        )
      else
        TextEditingDeltaReplacement(
          oldText: before,
          replacementText: added,
          replacedRange: range,
          selection: value.selection,
          composing: value.composing,
        ),
    ]);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void showToolbar() {}
}
