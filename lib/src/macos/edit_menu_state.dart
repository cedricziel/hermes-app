import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Which of the Edit menu's six commands apply to what has focus.
@immutable
class EditAvailability {
  const EditAvailability({
    this.undo = false,
    this.redo = false,
    this.cut = false,
    this.copy = false,
    this.paste = false,
    this.selectAll = false,
  });

  /// Nothing is editable or selected: every item is off.
  static const none = EditAvailability();

  final bool undo;
  final bool redo;
  final bool cut;
  final bool copy;
  final bool paste;
  final bool selectAll;

  @override
  bool operator ==(Object other) =>
      other is EditAvailability &&
      other.undo == undo &&
      other.redo == redo &&
      other.cut == cut &&
      other.copy == copy &&
      other.paste == paste &&
      other.selectAll == selectAll;

  @override
  int get hashCode => Object.hash(undo, redo, cut, copy, paste, selectAll);
}

/// What the Edit menu may do right now, read from the focused widget.
///
/// A text field gives Undo (while it has history), Redo (after an undo), Cut
/// and Copy (with a selection), Paste (with text on the pasteboard) and
/// Select All. Selected text in a [MenuSelectionArea] gives Copy. Everything
/// else leaves the six off. It listens to the focused field's own
/// controllers, so the value changes as the user types, selects or copies,
/// and only an actual change notifies.
class EditMenuState extends ValueNotifier<EditAvailability> {
  EditMenuState() : super(EditAvailability.none) {
    FocusManager.instance.addListener(_focusChanged);
    _focusChanged();
  }

  static const _cause = SelectionChangedCause.keyboard;

  EditableTextState? _field;
  Listenable? _fieldListenable;

  // Flutter keeps a field's undo stack private unless the field was given an
  // UndoHistoryController. Without one the history is estimated: Undo is on
  // while the text differs from what it was when the field got focus, Redo
  // from an undo made here until the next edit.
  String _baseline = '';
  String _lastText = '';
  bool _redoable = false;

  final _regionSelections = <Object>{};

  /// Records whether the selection area [owner] holds selected text.
  void reportSelection(Object owner, {required bool selected}) {
    final changed = selected
        ? _regionSelections.add(owner)
        : _regionSelections.remove(owner);
    if (changed) _refreshSoon();
  }

  /// Undo in the focused field.
  void undo() => _history(const UndoTextIntent(_cause), undoing: true);

  /// Redo in the focused field.
  void redo() => _history(const RedoTextIntent(_cause), undoing: false);

  void _history(Intent intent, {required bool undoing}) {
    final before = _field?.textEditingValue.text;
    invokeOnFocus(intent);
    if (before != _field?.textEditingValue.text) _redoable = undoing;
    _refresh();
  }

  /// Sends [intent] to the focused widget, as the focused widget's own key
  /// handling would.
  static void invokeOnFocus(Intent intent) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context != null) Actions.maybeInvoke(context, intent);
  }

  /// The text field that has focus, if any.
  static EditableTextState? focusedField() => FocusManager
      .instance
      .primaryFocus
      ?.context
      ?.findAncestorStateOfType<EditableTextState>();

  void _focusChanged() {
    final field = focusedField();
    if (!identical(field, _field)) {
      _fieldListenable?.removeListener(_fieldChanged);
      _field = field;
      _redoable = false;
      _baseline = _lastText = field?.textEditingValue.text ?? '';
      _fieldListenable = field == null
          ? null
          : Listenable.merge([
              field.widget.controller,
              field.widget.undoController,
              field.clipboardStatus,
            ]);
      _fieldListenable?.addListener(_fieldChanged);
    }
    _refresh();
  }

  void _fieldChanged() {
    final text = _field?.textEditingValue.text ?? '';
    if (text != _lastText) {
      _lastText = text;
      _redoable = false;
    }
    _refreshSoon();
  }

  // A listener may fire while the tree is being built or painted, where the
  // menu must not be told to rebuild.
  void _refreshSoon() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _refresh();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _refresh();
      });
    }
  }

  void _refresh() => value = _read();

  EditAvailability _read() {
    final field = _field;
    if (field == null) {
      final inRegion =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<SelectableRegionState>() !=
          null;
      return EditAvailability(copy: inRegion && _regionSelections.isNotEmpty);
    }
    final widget = field.widget;
    final selection = field.textEditingValue.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final undoHistory = widget.undoController?.value;
    return EditAvailability(
      undo: undoHistory?.canUndo ?? _lastText != _baseline,
      redo: undoHistory?.canRedo ?? _redoable,
      cut: hasSelection && !widget.readOnly && !widget.obscureText,
      copy: hasSelection && !widget.obscureText,
      paste:
          !widget.readOnly &&
          field.clipboardStatus.value == ClipboardStatus.pasteable,
      selectAll: widget.enableInteractiveSelection,
    );
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    FocusManager.instance.removeListener(_focusChanged);
    _fieldListenable?.removeListener(_fieldChanged);
    super.dispose();
  }
}
