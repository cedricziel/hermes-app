import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

/// Settings' Quick panel row (macOS): what the shortcut does, and the
/// recorder control where the user records, changes or clears it.
class ShortcutRecorderRow extends StatelessWidget {
  const ShortcutRecorderRow({
    super.key,
    required this.isSet,
    required this.recorder,
  });

  /// Whether a shortcut is recorded.
  final bool isSet;

  /// The recorder: [NativeShortcutRecorder] in the app, a stand-in in the
  /// catalog and tests.
  final Widget recorder;

  static const recorderSize = Size(150, 24);

  @override
  Widget build(BuildContext context) => GroupedRow(
    title: 'Quick panel',
    subtitle: isSet
        ? 'Press the shortcut in any app to ask Hermes.'
        : 'Record a shortcut to ask Hermes from any app.',
    subtitleMaxLines: 2,
    trailing: SizedBox.fromSize(size: recorderSize, child: recorder),
  );
}

/// The KeyboardShortcuts recorder the Runner provides as a platform view. It
/// stores the chord itself, shows a clear button and warns about clashes
/// with system shortcuts and the menu bar.
class NativeShortcutRecorder extends StatelessWidget {
  const NativeShortcutRecorder({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppKitView(viewType: 'hermes_app/shortcut_recorder');
}
