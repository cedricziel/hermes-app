import 'dart:async';

import 'package:flutter/material.dart';

import '../global_shortcut.dart';
import 'shortcut_recorder_row.dart';

/// [ShortcutRecorderRow] kept up to date with [shortcut]: whether one is
/// set when it opens, and each time the recorder records or clears it.
class QuickPanelShortcutRow extends StatefulWidget {
  const QuickPanelShortcutRow({
    super.key,
    required this.shortcut,
    this.recorder = const NativeShortcutRecorder(),
  });

  final GlobalShortcut shortcut;
  final Widget recorder;

  @override
  State<QuickPanelShortcutRow> createState() => _QuickPanelShortcutRowState();
}

class _QuickPanelShortcutRowState extends State<QuickPanelShortcutRow> {
  var _set = false;

  /// Whether the recorder reported a change, which is newer than the first
  /// read's answer whenever that answer arrives.
  var _changed = false;
  late final StreamSubscription<bool> _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.shortcut.changes.listen((set) {
      _changed = true;
      _update(set);
    });
    unawaited(
      widget.shortcut.isSet().then((set) {
        if (!_changed) _update(set);
      }),
    );
  }

  void _update(bool set) {
    if (mounted && set != _set) setState(() => _set = set);
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ShortcutRecorderRow(isSet: _set, recorder: widget.recorder);
}
