import 'dart:async';

import 'package:material_ui/material_ui.dart';
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
  TextEditingController? _boundController;
  UndoHistoryController? _boundUndo;
  bool _suspended = false;
  bool _rebindArmed = false;
  bool _boundReadOnly = false;
  bool _boundObscure = false;
  bool _boundSelectable = true;

  /// Turns all six items off while another window than this engine's main
  /// window is key: this engine's focus is then not what the user edits.
  set suspended(bool suspended) {
    if (_suspended == suspended) return;
    _suspended = suspended;
    _refreshSoon();
  }

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
      _unbind();
      _field = field;
      _redoable = false;
      _baseline = _lastText = field?.textEditingValue.text ?? '';
      if (field != null) {
        _bind(field);
        // The field reads the pasteboard when it is created, not when it
        // gets focus, and text may have been copied elsewhere since.
        unawaited(field.clipboardStatus.update());
      }
    }
    _refresh();
  }

  /// Re-reads the pasteboard for the focused field; the Edit menu calls it
  /// when it opens, since a copy made without a focus change (a message's
  /// Copy button, Copy Transcript) is not seen by the field.
  void refreshClipboard() {
    final field = _field;
    if (field != null && field.mounted) {
      unawaited(field.clipboardStatus.update());
    }
  }

  // A focused field can be rebuilt with other controllers and nothing says
  // so, so while one is bound each frame checks that the bound controllers
  // are still the field's. The check re-arms itself and stops with the field.
  void _armRebind() {
    if (_rebindArmed || _disposed || _field == null) return;
    _rebindArmed = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebindArmed = false;
      _rebind();
      _armRebind();
    });
  }

  void _bind(EditableTextState field) {
    _boundController = field.widget.controller;
    _boundUndo = field.widget.undoController;
    _boundReadOnly = field.widget.readOnly;
    _boundObscure = field.widget.obscureText;
    _boundSelectable = field.widget.enableInteractiveSelection;
    _fieldListenable = Listenable.merge([
      _boundController,
      _boundUndo,
      field.clipboardStatus,
    ])..addListener(_fieldChanged);
    _armRebind();
  }

  void _unbind() {
    _fieldListenable?.removeListener(_fieldChanged);
    _fieldListenable = null;
  }

  void _rebind() {
    final field = _field;
    if (_disposed || field == null || !field.mounted) return;
    final widget = field.widget;
    final controllerChanged = !identical(widget.controller, _boundController);
    final undoChanged = !identical(widget.undoController, _boundUndo);
    final flagsChanged =
        widget.readOnly != _boundReadOnly ||
        widget.obscureText != _boundObscure ||
        widget.enableInteractiveSelection != _boundSelectable;
    if (!controllerChanged && !undoChanged && !flagsChanged) return;
    if (controllerChanged) {
      // The estimated history belonged to the old controller's text.
      _redoable = false;
      _baseline = _lastText = field.textEditingValue.text;
    }
    _unbind();
    _bind(field);
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
    if (_suspended) return EditAvailability.none;
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
    _unbind();
    _field = null;
    _boundController = null;
    _boundUndo = null;
    super.dispose();
  }
}
