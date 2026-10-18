import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';

/// Stops the current reply without reserving a separate status bar above the
/// draft. Sending a follow-up remains a separate action in the controls row.
class ComposerStopButton extends StatefulWidget {
  const ComposerStopButton({super.key, required this.onStop});
  final Future<void> Function() onStop;

  @override
  State<ComposerStopButton> createState() => _ComposerStopButtonState();
}

class _ComposerStopButtonState extends State<ComposerStopButton> {
  var _busy = false;

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onStop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => NamedIconButton(
    label: 'Stop response',
    tooltip: 'Stop',
    icon: AppIcons.stop,
    onPressed: _busy ? null : _stop,
  );
}
