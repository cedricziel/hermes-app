import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../theme/platform_chrome.dart';

/// A shell command in a surface-high box, in monospace and selectable, with a
/// Copy button. Copying announces "Command copied" to screen readers and, for
/// a moment, says "Copied" on the button.
class CommandRow extends StatefulWidget {
  const CommandRow({
    super.key,
    required this.command,
    this.onCopied,
    this.copyBelowAtLargeText = false,
  });

  final String command;
  final VoidCallback? onCopied;

  /// At a large text size the Copy button sits under the command, instead of
  /// beside it where it would leave the command a sliver to wrap in.
  final bool copyBelowAtLargeText;

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
    final l10n = context.l10n;
    final minTarget = platformChromeOf(context) == PlatformChrome.material
        ? 48.0
        : kAppleMinTapTarget;
    final stacked =
        widget.copyBelowAtLargeText &&
        MediaQuery.textScalerOf(context).scale(14) > 21;
    final commandText = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SelectableText(
        widget.command,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: scheme.onSurface,
        ),
      ),
    );
    // The label turns into the announcement: a live region speaks
    // when it changes.
    final copy = Semantics(
      button: true,
      liveRegion: _copied,
      label: _copied
          ? l10n.serverCareCommandCopied
          : l10n.serverCareCommandCopy,
      onTap: _copy,
      excludeSemantics: true,
      child: TextButton(
        onPressed: _copy,
        style: TextButton.styleFrom(minimumSize: Size(minTarget, minTarget)),
        child: Text(
          _copied
              ? l10n.serverCareCommandCopiedButton
              : l10n.serverCareCommandCopy,
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  commandText,
                  Align(alignment: AlignmentDirectional.centerEnd, child: copy),
                ],
              )
            : Row(
                children: [
                  Expanded(child: commandText),
                  copy,
                ],
              ),
      ),
    );
  }
}
