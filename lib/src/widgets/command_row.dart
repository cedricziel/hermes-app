import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/platform_chrome.dart';

/// A shell command in a surface-high box, in monospace and selectable, with a
/// Copy button. Copying announces "Command copied" to screen readers and, for
/// a moment, says "Copied" on the button.
class CommandRow extends StatefulWidget {
  const CommandRow({super.key, required this.command, this.onCopied});

  final String command;
  final VoidCallback? onCopied;

  @override
  State<CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<CommandRow> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minTarget = platformChromeOf(context) == PlatformChrome.material
        ? 48.0
        : kAppleMinTapTarget;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SelectableText(
                  widget.command,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            // The label turns into the announcement: a live region speaks
            // when it changes.
            Semantics(
              button: true,
              liveRegion: _copied,
              label: _copied ? 'Command copied' : 'Copy',
              onTap: _copy,
              excludeSemantics: true,
              child: TextButton(
                onPressed: _copy,
                style: TextButton.styleFrom(
                  minimumSize: Size(minTarget, minTarget),
                ),
                child: Text(_copied ? 'Copied' : 'Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
