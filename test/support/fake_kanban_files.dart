import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_app/src/kanban/kanban_files.dart';

/// Stands in for the device's file dialogs.
class FakeKanbanFiles implements KanbanFiles {
  FakeKanbanFiles({this.next, this.saves = true});

  /// The file the user "picks"; null means they cancel.
  KanbanPickedFile? next;

  /// Whether the user confirms a save.
  bool saves;

  /// Thrown by [pick], like a picker that fails.
  Object? pickError;

  /// When set, [pick] waits for it, like a dialog the user has not closed yet.
  Completer<void>? pickGate;

  var pickCalls = 0;

  final saved = <({String name, Uint8List bytes})>[];

  @override
  Future<KanbanPickedFile?> pick() async {
    pickCalls++;
    await pickGate?.future;
    if (pickError != null) throw pickError!; // ignore: only_throw_errors
    return next;
  }

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    if (!saves) return false;
    saved.add((name: name, bytes: bytes));
    return true;
  }
}
