import 'package:flutter/foundation.dart';

/// One key combination as the keys a person presses, in order: `Ctrl`,
/// `Shift`, `F` on Windows and Linux, `⇧`, `⌘`, `F` on a Mac.
@immutable
class ShortcutChord {
  const ShortcutChord(this.keys);

  final List<String> keys;

  /// The combination as one line, such as "Ctrl+Shift+F", for a tooltip and
  /// for a screen reader.
  String get text => keys.join('+');

  @override
  bool operator ==(Object other) =>
      other is ShortcutChord && listEquals(other.keys, keys);

  @override
  int get hashCode => Object.hashAll(keys);
}

/// A command with the combinations that run it; more than one when two keys
/// do the same, such as Ctrl+R and F5.
@immutable
class ShortcutRowModel {
  const ShortcutRowModel({required this.label, required this.chords});

  final String label;
  final List<ShortcutChord> chords;
}

/// A titled group of commands, such as a menu of the app.
@immutable
class ShortcutSectionModel {
  const ShortcutSectionModel({required this.title, required this.rows});

  final String title;
  final List<ShortcutRowModel> rows;
}
